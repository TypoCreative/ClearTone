import AVFoundation
import CoreAudio
import Foundation

struct AudioInputDevice: Codable {
    let id: String
    let name: String
    let manufacturer: String
    let isDefault: Bool
}

struct EngineMetrics: Codable {
    var framesProcessed: Int
    var inputLevel: Double
    var estimatedLatencyMs: Double
}

struct EngineSnapshot: Codable {
    var phase: String
    var permission: String
    var selectedInputId: String?
    var systemInputId: String?
    var followSystemInput: Bool
    var inputs: [AudioInputDevice]
    var strength: Double
    var statusMessage: String
    var lastError: String?
    var metrics: EngineMetrics
}

struct EngineCommand: Codable {
    let type: String
    let inputId: String?
    let strength: Double?
}

struct SnapshotEnvelope: Codable {
    let type: String
    let snapshot: EngineSnapshot
}

final class EngineRuntime: @unchecked Sendable {
    private let encoder = JSONEncoder()
    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
    private let defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private let devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var processingTimer: DispatchSourceTimer?
    private var snapshot = EngineSnapshot(
        phase: "booting",
        permission: "unknown",
        selectedInputId: nil,
        systemInputId: nil,
        followSystemInput: true,
        inputs: [],
        strength: 0.65,
        statusMessage: "Starting native engine",
        lastError: nil,
        metrics: EngineMetrics(
            framesProcessed: 0,
            inputLevel: 0,
            estimatedLatencyMs: 0
        )
    )

    init() {
        refreshAudioEnvironment(reason: "startup", forceSystemSelection: true)
        refreshPermission()
        installAudioListeners()
        snapshot.phase = "idle"
        snapshot.statusMessage = idleStatusMessage()
        emitSnapshot()
    }

    deinit {
        var defaultInputAddress = self.defaultInputAddress
        var devicesAddress = self.devicesAddress
        AudioObjectRemovePropertyListenerBlock(
            systemObjectID,
            &defaultInputAddress,
            DispatchQueue.main,
            defaultInputListener
        )
        AudioObjectRemovePropertyListenerBlock(
            systemObjectID,
            &devicesAddress,
            DispatchQueue.main,
            devicesListener
        )
    }

    private lazy var defaultInputListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.handleAudioEnvironmentChange(reason: "System input changed")
    }

    private lazy var devicesListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.handleAudioEnvironmentChange(reason: "Audio devices updated")
    }

    func handle(line: String) {
        guard let data = line.data(using: .utf8) else {
            return
        }

        do {
            let command = try JSONDecoder().decode(EngineCommand.self, from: data)
            handle(command: command)
        } catch {
            fail(message: "Unable to decode bridge command.")
        }
    }

    private func handle(command: EngineCommand) {
        switch command.type {
        case "getStatus", "listInputs":
            refreshAudioEnvironment(reason: "Status requested")
            refreshPermission()
            emitSnapshot()
        case "selectInput":
            refreshAudioEnvironment(reason: "Manual input selection")
            snapshot.followSystemInput = false
            snapshot.selectedInputId = command.inputId
            snapshot.lastError = nil
            snapshot.statusMessage = "Using selected input device"
            emitSnapshot()
        case "followSystemInput":
            snapshot.followSystemInput = true
            refreshAudioEnvironment(reason: "Following system input", forceSystemSelection: true)
            snapshot.lastError = nil
            snapshot.statusMessage = idleStatusMessage()
            emitSnapshot()
        case "startProcessing":
            startProcessing()
        case "stopProcessing":
            stopProcessing()
        case "setStrength":
            snapshot.strength = max(0, min(1, command.strength ?? snapshot.strength))
            snapshot.statusMessage = snapshot.phase == "processing"
                ? "Processing microphone input through the native engine"
                : idleStatusMessage()
            snapshot.lastError = nil
            emitSnapshot()
        default:
            fail(message: "Unsupported engine command: \(command.type)")
        }
    }

    private func installAudioListeners() {
        var defaultInputAddress = self.defaultInputAddress
        var devicesAddress = self.devicesAddress
        AudioObjectAddPropertyListenerBlock(
            systemObjectID,
            &defaultInputAddress,
            DispatchQueue.main,
            defaultInputListener
        )
        AudioObjectAddPropertyListenerBlock(
            systemObjectID,
            &devicesAddress,
            DispatchQueue.main,
            devicesListener
        )
    }

    private func handleAudioEnvironmentChange(reason: String) {
        let wasProcessing = snapshot.phase == "processing"
        refreshAudioEnvironment(reason: reason, forceSystemSelection: snapshot.followSystemInput)
        if !wasProcessing {
            snapshot.statusMessage = idleStatusMessage()
        }
        emitSnapshot()
    }

    private func refreshAudioEnvironment(reason _: String, forceSystemSelection: Bool = false) {
        let defaultInputId = currentDefaultInputUID()
        snapshot.systemInputId = defaultInputId

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        snapshot.inputs = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                manufacturer: "macOS",
                isDefault: device.uniqueID == defaultInputId
            )
        }

        let availableIds = Set(snapshot.inputs.map(\.id))
        if snapshot.followSystemInput || forceSystemSelection {
            snapshot.selectedInputId = defaultInputId ?? snapshot.inputs.first?.id
            snapshot.followSystemInput = true
        } else if let selectedId = snapshot.selectedInputId, availableIds.contains(selectedId) {
            snapshot.selectedInputId = selectedId
        } else {
            snapshot.selectedInputId = defaultInputId ?? snapshot.inputs.first?.id
            snapshot.followSystemInput = true
        }
    }

    private func currentDefaultInputUID() -> String? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = defaultInputAddress

        let deviceStatus = AudioObjectGetPropertyData(
            systemObjectID,
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard deviceStatus == noErr, deviceID != 0 else {
            return nil
        }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        let uidStatus = AudioObjectGetPropertyData(
            deviceID,
            &uidAddress,
            0,
            nil,
            &size,
            &uid
        )

        guard uidStatus == noErr else {
            return nil
        }

        return uid as String
    }

    private func refreshPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            snapshot.permission = "granted"
        case .denied:
            snapshot.permission = "denied"
        case .restricted:
            snapshot.permission = "restricted"
        case .notDetermined:
            snapshot.permission = "not-determined"
        @unknown default:
            snapshot.permission = "unknown"
        }
    }

    private func idleStatusMessage() -> String {
        if snapshot.inputs.isEmpty {
            return "Waiting for a microphone device"
        }

        if snapshot.followSystemInput {
            if let current = currentInputName() {
                return "Following system input: \(current)"
            }
            return "Following system input"
        }

        return currentInputName().map { "Using selected input: \($0)" } ?? "Native engine ready"
    }

    private func currentInputName() -> String? {
        snapshot.inputs.first(where: { $0.id == snapshot.selectedInputId })?.name
    }

    private func startProcessing() {
        refreshAudioEnvironment(reason: "Start requested", forceSystemSelection: snapshot.followSystemInput)
        refreshPermission()

        guard !snapshot.inputs.isEmpty else {
            fail(message: "No microphone devices are available.")
            return
        }

        if snapshot.selectedInputId == nil {
            snapshot.selectedInputId = snapshot.systemInputId ?? snapshot.inputs.first?.id
        }

        let currentPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        switch currentPermission {
        case .authorized:
            beginSimulatedPipeline()
        case .notDetermined:
            snapshot.phase = "starting"
            snapshot.statusMessage = "Requesting microphone access"
            snapshot.lastError = nil
            emitSnapshot()

            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.refreshPermission()
                    if granted {
                        self?.beginSimulatedPipeline()
                    } else {
                        self?.fail(message: "Microphone access was denied.")
                    }
                }
            }
        case .denied, .restricted:
            fail(message: "Microphone access is required to start processing.")
        @unknown default:
            fail(message: "Microphone permission state is unknown.")
        }
    }

    private func beginSimulatedPipeline() {
        stopTimer()

        snapshot.phase = "processing"
        snapshot.statusMessage = "Processing microphone input through the native engine"
        snapshot.lastError = nil
        snapshot.metrics.framesProcessed = 0
        snapshot.metrics.inputLevel = 0.12
        snapshot.metrics.estimatedLatencyMs = max(10, 18 - snapshot.strength * 6)
        emitSnapshot()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .milliseconds(180), repeating: .milliseconds(400))
        timer.setEventHandler { [weak self] in
            self?.tickProcessing()
        }
        timer.resume()
        processingTimer = timer
    }

    private func tickProcessing() {
        guard snapshot.phase == "processing" else {
            return
        }

        snapshot.metrics.framesProcessed += 480
        snapshot.metrics.inputLevel = Double.random(in: 0.14...0.78)
        snapshot.metrics.estimatedLatencyMs = max(10, 18 - snapshot.strength * 6)
        snapshot.statusMessage = "Processing microphone input through the native engine"
        emitSnapshot()
    }

    private func stopProcessing() {
        snapshot.phase = "stopping"
        snapshot.statusMessage = "Stopping native engine"
        snapshot.lastError = nil
        emitSnapshot()

        stopTimer()
        refreshAudioEnvironment(reason: "Stop requested", forceSystemSelection: snapshot.followSystemInput)
        snapshot.phase = "idle"
        snapshot.statusMessage = idleStatusMessage()
        snapshot.metrics.inputLevel = 0
        emitSnapshot()
    }

    private func stopTimer() {
        processingTimer?.cancel()
        processingTimer = nil
    }

    private func fail(message: String) {
        stopTimer()
        snapshot.phase = "error"
        snapshot.lastError = message
        snapshot.statusMessage = "Native engine needs attention"
        emitSnapshot()
    }

    private func emitSnapshot() {
        do {
            let payload = try encoder.encode(
                SnapshotEnvelope(type: "snapshot", snapshot: snapshot)
            )

            if let line = String(data: payload, encoding: .utf8) {
                FileHandle.standardOutput.write(Data((line + "\n").utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("Failed to encode engine snapshot\n".utf8))
        }
    }
}

final class InputBridge: @unchecked Sendable {
    private var buffer = Data()
    private let runtime: EngineRuntime

    init(runtime: EngineRuntime) {
        self.runtime = runtime
    }

    func consume(_ data: Data) {
        buffer.append(data)
        while let range = buffer.range(of: Data([0x0a])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.lowerBound)

            if let line = String(data: lineData, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.runtime.handle(line: line)
                }
            }
        }
    }
}

final class EngineApplication {
    private let inputBridge: InputBridge

    init() {
        let runtime = EngineRuntime()
        inputBridge = InputBridge(runtime: runtime)
    }

    func run() -> Never {
        FileHandle.standardInput.readabilityHandler = { [inputBridge] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }

            inputBridge.consume(data)
        }

        dispatchMain()
    }
}

EngineApplication().run()
