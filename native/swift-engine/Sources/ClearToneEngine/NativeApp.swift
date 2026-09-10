import AppKit
import Darwin
import SwiftUI

@MainActor
final class ClearToneAppModel: ObservableObject {
    @Published private(set) var snapshot: EngineSnapshot
    @Published private(set) var performance = NativePerformanceMetrics()
    @Published var actionError: String?
    @Published private(set) var trayOnlyMode: Bool

    let runtime: EngineRuntime
    private var metricsTimer: Timer?
    private let sampler = NativePerformanceSampler()

    var isProcessing: Bool { snapshot.phase == "processing" || snapshot.phase == "starting" }
    var isProcessingTransitioning: Bool { snapshot.phase == "starting" || snapshot.phase == "stopping" }
    var processingActionTitle: String {
        switch snapshot.phase {
        case "starting": "Starting…"
        case "stopping": "Stopping…"
        case "processing": "Stop Processing"
        default: "Start Processing"
        }
    }
    var processingActionIcon: String {
        switch snapshot.phase {
        case "starting", "stopping": "hourglass"
        case "processing": "stop.fill"
        default: "play.fill"
        }
    }

    init() {
        let runtime = EngineRuntime()
        self.runtime = runtime
        snapshot = runtime.publisher.snapshot
        trayOnlyMode = UserDefaults.standard.bool(forKey: "trayOnlyMode")
        runtime.publisher.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.snapshot = snapshot
            }
        }
        restoreSettings()
        send(type: "listInputs")
        ClearToneAppDelegate.terminationHandler = { [weak runtime] in
            runtime?.prepareForTermination()
        }
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.samplePerformance() }
        }
        samplePerformance()
    }

    func toggleProcessing() {
        guard !isProcessingTransitioning else { return }
        actionError = nil
        send(type: isProcessing ? "stopProcessing" : "startProcessing")
    }

    func selectInput(_ id: String) {
        if id == "system" {
            send(type: "followSystemInput")
            UserDefaults.standard.removeObject(forKey: "selectedInputId")
        } else {
            send(type: "selectInput", inputId: id)
            UserDefaults.standard.set(id, forKey: "selectedInputId")
        }
    }

    func setStrength(_ value: Double) {
        let normalized = max(0, min(1, value))
        send(type: "setStrength", strength: normalized)
        UserDefaults.standard.set(normalized, forKey: "strength")
    }

    func setVoicePreset(_ preset: VoicePreset) {
        send(type: "setVoicePreset", voicePreset: preset)
        UserDefaults.standard.set(preset.rawValue, forKey: "voicePreset")
    }

    func setVirtualMicrophone(_ enabled: Bool) {
        guard snapshot.virtualMicrophone.available || !enabled else {
            actionError = "ClearTone Virtual Microphone driver is not installed."
            return
        }
        send(type: "setVirtualMicrophone", enabled: enabled)
        UserDefaults.standard.set(enabled, forKey: "virtualMicrophoneEnabled")
    }

    func installDriver() {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("driver/ClearToneVirtualMicrophone.pkg"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("apps/resources/driver/ClearToneVirtualMicrophone.pkg")
        ].compactMap { $0 }
        guard let installer = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            actionError = "The virtual microphone installer is missing from this build."
            return
        }
        NSWorkspace.shared.open(installer)
    }

    func refreshDevices() {
        send(type: "listInputs")
    }

    func dismissError() {
        actionError = nil
        runtime.publisher.snapshot.lastError = nil
        runtime.publisher.emitSnapshot()
    }

    func setTrayOnlyMode(_ enabled: Bool) {
        trayOnlyMode = enabled
        UserDefaults.standard.set(enabled, forKey: "trayOnlyMode")
        ClearToneAppDelegate.applyPresentationMode(trayOnly: enabled)
        if enabled {
            // SwiftUI may update the Scene after this state mutation. Repeat
            // close once on the next turn to catch that window as well.
            DispatchQueue.main.async {
                ClearToneAppDelegate.closeDesktopWindows()
            }
        }
    }

    func prepareForTermination() {
        runtime.prepareForTermination()
    }

    private func restoreSettings() {
        let defaults = UserDefaults.standard
        let strength = defaults.object(forKey: "strength") as? Double ?? 0.65
        let preset = VoicePreset(rawValue: defaults.string(forKey: "voicePreset") ?? "clear") ?? .clear
        send(type: "setStrength", strength: strength)
        send(type: "setVoicePreset", voicePreset: preset)
        if let selectedInput = defaults.string(forKey: "selectedInputId") {
            send(type: "selectInput", inputId: selectedInput)
        } else {
            send(type: "followSystemInput")
        }
        if defaults.bool(forKey: "virtualMicrophoneEnabled") {
            send(type: "setVirtualMicrophone", enabled: true)
        }
    }

    private func samplePerformance() {
        performance = sampler.sample()
    }

    private func send(
        type: String,
        inputId: String? = nil,
        strength: Double? = nil,
        voicePreset: VoicePreset? = nil,
        enabled: Bool? = nil
    ) {
        do {
            let command = EngineCommand(
                type: type,
                inputId: inputId,
                strength: strength,
                voicePreset: voicePreset,
                enabled: enabled,
                requestId: nil
            )
            let data = try JSONEncoder().encode(command)
            guard let line = String(data: data, encoding: .utf8) else { return }
            runtime.commandHandler.handle(line: line)
            snapshot = runtime.publisher.snapshot
            if let error = snapshot.lastError { actionError = error }
        } catch {
            actionError = error.localizedDescription
        }
    }
}

struct NativePerformanceMetrics {
    var cpuPercent = 0.0
    var memoryMB = 0.0
}

final class NativePerformanceSampler {
    private var previousCPUTime = 0.0
    private var previousWallTime = ProcessInfo.processInfo.systemUptime

    func sample() -> NativePerformanceMetrics {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpuTime = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
            + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        let wallTime = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0.001, wallTime - previousWallTime)
        let cpu = previousCPUTime == 0 ? 0 : max(0, (cpuTime - previousCPUTime) / elapsed * 100)
        previousCPUTime = cpuTime
        previousWallTime = wallTime

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let memory = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        } == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
        return NativePerformanceMetrics(cpuPercent: cpu, memoryMB: memory)
    }
}

private enum ClearToneStyle {
    static let accent = Color(red: 0.16, green: 0.55, blue: 0.98)
    static let cyan = Color(red: 0.22, green: 0.78, blue: 0.92)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.48)
    static let cornerRadius: CGFloat = 22
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    ClearToneStyle.accent.opacity(0.15),
                    Color.clear,
                    ClearToneStyle.cyan.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(ClearToneStyle.accent.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -300, y: -260)
            Circle()
                .fill(ClearToneStyle.cyan.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 330, y: 310)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct GlassCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ClearToneStyle.accent)
                    .frame(width: 32, height: 32)
                    .background(ClearToneStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
            }
            content
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ClearToneStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ClearToneStyle.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.09), radius: 20, x: 0, y: 10)
    }
}

private struct ControlPanel: View {
    @EnvironmentObject private var model: ClearToneAppModel
    let compact: Bool

    private var selectedInput: Binding<String> {
        Binding(
            get: { model.snapshot.followSystemInput ? "system" : model.snapshot.selectedInputId ?? "system" },
            set: { value in model.selectInput(value) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Input microphone", systemImage: "mic")
                    .font(.subheadline.weight(.medium))
                Picker("Input microphone", selection: selectedInput) {
                    Text("Follow macOS default").tag("system")
                    ForEach(model.snapshot.inputs, id: \.id) { input in
                        Text(input.name).tag(input.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Input microphone")
                .accessibilityHint("Select the physical microphone ClearTone processes")
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Noise reduction", systemImage: "waveform.badge.minus")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(model.snapshot.strength * 100))%")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ClearToneStyle.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(ClearToneStyle.accent.opacity(0.11), in: Capsule())
                }
                Slider(
                    value: Binding(
                        get: { model.snapshot.strength },
                        set: { value in model.setStrength(value) }
                    ),
                    in: 0...1
                )
                .tint(ClearToneStyle.accent)
                .accessibilityLabel("Noise reduction strength")
                .accessibilityValue("\(Int(model.snapshot.strength * 100)) percent")
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 9) {
                Label("Voice profile", systemImage: "person.wave.2")
                    .font(.subheadline.weight(.medium))
                Picker(
                    "Voice profile",
                    selection: Binding(
                        get: { model.snapshot.voicePreset },
                        set: { preset in model.setVoicePreset(preset) }
                    )
                ) {
                    Text("Natural").tag(VoicePreset.natural)
                    Text("Clear").tag(VoicePreset.clear)
                    Text("Broadcast").tag(VoicePreset.broadcast)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct VirtualMicrophoneCard: View {
    @EnvironmentObject private var model: ClearToneAppModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        model.snapshot.virtualMicrophone.enabled
                            ? ClearToneStyle.success.opacity(0.16)
                            : Color.secondary.opacity(0.10)
                    )
                Image(systemName: model.snapshot.virtualMicrophone.enabled ? "mic.fill" : "mic")
                    .font(.system(size: compact ? 18 : 22, weight: .medium))
                    .foregroundStyle(model.snapshot.virtualMicrophone.enabled ? ClearToneStyle.success : .secondary)
            }
            .frame(width: compact ? 44 : 52, height: compact ? 44 : 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Virtual Microphone")
                    .font(.subheadline.weight(.semibold))
                Text(virtualMicrophoneDescription)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if model.snapshot.virtualMicrophone.available {
                Toggle(
                    "Virtual Microphone",
                    isOn: Binding(
                        get: { model.snapshot.virtualMicrophone.enabled },
                        set: { enabled in model.setVirtualMicrophone(enabled) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(ClearToneStyle.success)
                .accessibilityHint("Automatically routes cleaned audio as the macOS default input")
            } else {
                Button("Install Driver") { model.installDriver() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(compact ? .small : .regular)
                    .accessibilityHint("Opens the bundled ClearTone Virtual Microphone installer")
            }
        }
        .padding(compact ? 13 : 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var virtualMicrophoneDescription: String {
        if !model.snapshot.virtualMicrophone.available {
            return "Driver required for app-wide routing"
        }
        return model.snapshot.virtualMicrophone.enabled
            ? "Cleaned audio is the default input"
            : "Off — physical input is unchanged"
    }
}

private struct AudioRoutingGrid: View {
    @EnvironmentObject private var model: ClearToneAppModel
    let compact: Bool

    private var inputDetail: String {
        let inputID = model.snapshot.followSystemInput
            ? model.snapshot.systemInputId
            : model.snapshot.selectedInputId
        return model.snapshot.inputs.first(where: { $0.id == inputID })?.name ?? "Microphone"
    }

    private var outputDetail: String {
        if !model.snapshot.virtualMicrophone.available { return "Driver needed" }
        return model.snapshot.virtualMicrophone.enabled ? "System default" : "Not routed"
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 13) {
            HStack(spacing: compact ? 6 : 9) {
                RoutingNode(
                    title: "Input",
                    detail: inputDetail,
                    systemImage: "mic",
                    tint: .secondary,
                    compact: compact
                )

                RoutingArrow(active: model.isProcessing, compact: compact)

                RoutingNode(
                    title: "Voice Engine",
                    detail: model.isProcessing ? "Processing" : "Ready",
                    systemImage: "waveform",
                    tint: model.isProcessing ? ClearToneStyle.success : ClearToneStyle.accent,
                    compact: compact,
                    emphasized: true
                )

                RoutingArrow(active: model.snapshot.virtualMicrophone.enabled, compact: compact)

                RoutingNode(
                    title: "Output",
                    detail: outputDetail,
                    systemImage: "mic.fill",
                    tint: model.snapshot.virtualMicrophone.enabled ? ClearToneStyle.success : .secondary,
                    compact: compact
                )
            }

            VirtualMicrophoneCard(compact: compact)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RoutingNode: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let compact: Bool
    var emphasized = false

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 13 : 16, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .lineLimit(1)

            Text(detail)
                .font(.system(size: compact ? 9 : 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 56 : 72)
        .padding(.horizontal, compact ? 4 : 7)
        .background(
            emphasized ? ClearToneStyle.accent.opacity(0.12) : Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: compact ? 11 : 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 11 : 14)
                .stroke(emphasized ? ClearToneStyle.accent.opacity(0.32) : Color.primary.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

private struct RoutingArrow: View {
    let active: Bool
    let compact: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: compact ? 8 : 10, weight: .bold))
            .foregroundStyle(active ? ClearToneStyle.accent : Color.secondary.opacity(0.45))
            .accessibilityHidden(true)
    }
}

private struct MetricsView: View {
    @EnvironmentObject private var model: ClearToneAppModel
    let compact: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 9), count: 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            MetricTile(title: "Input", value: rms(model.snapshot.metrics.inputRms), icon: "arrow.down.waveform")
            MetricTile(title: "Output", value: rms(model.snapshot.metrics.outputRms), icon: "arrow.up.waveform")
            MetricTile(
                title: "Reduction",
                value: "\(Int(model.snapshot.metrics.noiseReductionPercent.rounded()))%",
                icon: "waveform.badge.minus"
            )
            MetricTile(
                title: "Latency",
                value: String(format: "%.1f ms", model.snapshot.metrics.estimatedLatencyMs),
                icon: "timer"
            )
            MetricTile(
                title: "CPU",
                value: String(format: "%.1f%%", model.performance.cpuPercent),
                icon: "cpu"
            )
            MetricTile(
                title: "Memory",
                value: String(format: "%.0f MB", model.performance.memoryMB),
                icon: "memorychip"
            )
            MetricTile(title: "GPU", value: "System", icon: "display")
            MetricTile(title: "Processes", value: "1", icon: "square.stack.3d.up")
        }
        .font(compact ? .caption2 : .caption)
    }

    private func rms(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(ClearToneStyle.accent)
                    .accessibilityHidden(true)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProcessingHero: View {
    @EnvironmentObject private var model: ClearToneAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.isProcessing ? "Your voice is being cleaned" : "Ready when you are")
                    .font(.title2.bold())
                Text(
                    model.isProcessing
                        ? "ClearTone is processing locally in real time."
                        : "Start processing to reduce noise and improve clarity."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button {
                    model.toggleProcessing()
                } label: {
                    Label(
                        model.processingActionTitle,
                        systemImage: model.processingActionIcon
                    )
                    .font(.headline)
                    .frame(minWidth: 150)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(model.isProcessing ? Color.red.opacity(0.82) : ClearToneStyle.accent)
                .disabled(model.isProcessingTransitioning)
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityHint(
                    model.isProcessingTransitioning
                        ? "Wait for the microphone engine to finish changing state"
                        : (model.isProcessing ? "Stops microphone processing" : "Starts microphone processing")
                )
            }

        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: ClearToneAppModel

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardHeader

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 18
                    ) {
                        GlassCard(
                            "Voice Engine",
                            subtitle: "Local, private, and optimized for real-time speech",
                            systemImage: "waveform"
                        ) {
                            ProcessingHero()
                        }

                        GlassCard(
                            "Audio Routing",
                            subtitle: "Input, processing, and output in one place",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        ) {
                            AudioRoutingGrid(compact: false)
                        }

                        GlassCard(
                            "Audio Setup",
                            subtitle: "Choose your source and voice character",
                            systemImage: "slider.horizontal.3"
                        ) {
                            ControlPanel(compact: false)
                        }
                        .frame(maxWidth: .infinity)

                        GlassCard(
                            "System Health",
                            subtitle: "Small, low-frequency diagnostics",
                            systemImage: "gauge.with.dots.needle.33percent"
                        ) {
                            MetricsView(compact: false)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let error = model.actionError ?? model.snapshot.lastError {
                        ErrorBanner(message: error)
                    }
                }
                .padding(26)
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity)
            }
        }
        .onDisappear {
            if model.trayOnlyMode { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("ClearTone")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(model.snapshot.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.66))
                    .lineLimit(2)
            }

            Spacer()
            StatusPill(phase: model.snapshot.phase)
        }
        .padding(.horizontal, 4)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: ClearToneAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ClearToneStyle.accent.opacity(0.10), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ClearTone").font(.headline)
                        Text(model.snapshot.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    StatusPill(phase: model.snapshot.phase)
                }

                Button {
                    model.toggleProcessing()
                } label: {
                    Label(
                        model.processingActionTitle,
                        systemImage: model.processingActionIcon
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(model.isProcessing ? Color.red.opacity(0.82) : ClearToneStyle.accent)
                .disabled(model.isProcessingTransitioning)

                VStack(spacing: 12) {
                    ControlPanel(compact: true)
                    AudioRoutingGrid(compact: true)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.17), lineWidth: 1)
                }

                if let error = model.actionError ?? model.snapshot.lastError {
                    ErrorBanner(message: error)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("LIVE METRICS & PERFORMANCE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    MetricsView(compact: true)
                }

                Divider().opacity(0.6)

                HStack {
                    Toggle(
                        "Tray Only",
                        isOn: Binding(
                            get: { model.trayOnlyMode },
                            set: { enabled in
                                model.setTrayOnlyMode(enabled)
                                if !enabled {
                                    openWindow(id: "main")
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Spacer()
                    if !model.trayOnlyMode {
                        Button("Open Window") {
                            NSApp.setActivationPolicy(.regular)
                            openWindow(id: "main")
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                    Button("Quit") {
                        model.prepareForTermination()
                        NSApp.terminate(nil)
                    }
                }
                .font(.caption)
            }
            .padding(16)
        }
        .frame(width: 380)
    }
}

private struct StatusPill: View {
    let phase: String

    private var color: Color {
        if phase == "error" { return .red }
        if phase == "processing" { return ClearToneStyle.success }
        if phase == "starting" || phase == "stopping" { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(phase.capitalized)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay { Capsule().stroke(color.opacity(0.22), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Engine status: \(phase)")
    }
}

private struct ErrorBanner: View {
    @EnvironmentObject private var model: ClearToneAppModel
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Dismiss") { model.dismissError() }
        }
        .padding(13)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
