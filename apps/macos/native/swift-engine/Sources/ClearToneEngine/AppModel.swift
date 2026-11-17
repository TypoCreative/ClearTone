import AppKit
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

    var isProcessing: Bool { snapshot.phase.isProcessing }
    var isProcessingTransitioning: Bool { snapshot.phase == .stopping }
    var processingActionTitle: String {
        switch snapshot.phase {
        case .starting: "Cancel Starting"
        case .stopping: "Stopping…"
        case .processing: "Stop Processing"
        default: "Start Processing"
        }
    }
    var processingActionIcon: String {
        switch snapshot.phase {
        case .starting, .stopping: "hourglass"
        case .processing: "stop.fill"
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
        send(.refreshDevices)
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
        send(isProcessing ? .stopProcessing : .startProcessing)
    }

    func selectInput(_ id: String) {
        if id == "system" {
            send(.followSystemInput)
            UserDefaults.standard.removeObject(forKey: "selectedInputId")
        } else {
            send(.selectInput(id))
            UserDefaults.standard.set(id, forKey: "selectedInputId")
        }
    }

    func setStrength(_ value: Double) {
        send(.setStrength(value))
        UserDefaults.standard.set(snapshot.strength, forKey: "strength")
    }

    func setVoicePreset(_ preset: VoicePreset) {
        send(.setVoicePreset(preset))
        UserDefaults.standard.set(preset.rawValue, forKey: "voicePreset")
    }

    func setVirtualMicrophone(_ enabled: Bool) {
        guard snapshot.virtualMicrophone.available || !enabled else {
            actionError = "ClearTone Virtual Microphone driver is not installed."
            return
        }
        send(.setVirtualMicrophone(enabled))
        UserDefaults.standard.set(enabled, forKey: "virtualMicrophoneEnabled")
    }

    func installDriver() {
        guard let installer = Bundle.main.resourceURL?.appendingPathComponent("driver/ClearToneVirtualMicrophone.pkg"),
              FileManager.default.fileExists(atPath: installer.path) else {
            actionError = "The bundled virtual microphone installer is missing. Use a packaged ClearTone app."
            return
        }
        NSWorkspace.shared.open(installer)
    }

    func refreshDevices() {
        send(.refreshDevices)
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
        send(.setStrength(strength))
        send(.setVoicePreset(preset))
        if let selectedInput = defaults.string(forKey: "selectedInputId") {
            send(.selectInput(selectedInput))
        } else {
            send(.followSystemInput)
        }
        if defaults.bool(forKey: "virtualMicrophoneEnabled") {
            send(.setVirtualMicrophone(true))
        }
    }

    private func samplePerformance() {
        performance = sampler.sample()
    }

    private func send(_ command: EngineCommand) {
        do {
            try runtime.commandHandler.handle(command)
        } catch {
            runtime.publisher.snapshot.lastError = error.localizedDescription
            runtime.publisher.emitSnapshot()
        }
        snapshot = runtime.publisher.snapshot
        if let error = snapshot.lastError { actionError = error }
    }
}
