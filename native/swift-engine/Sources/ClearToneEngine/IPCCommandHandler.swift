import Foundation

final class IPCCommandHandler: @unchecked Sendable {
    private let publisher: EngineStatePublisher
    private let deviceManager: AudioDeviceManager
    private let engineController: AudioEngineController

    init(publisher: EngineStatePublisher, deviceManager: AudioDeviceManager, engineController: AudioEngineController) {
        self.publisher = publisher
        self.deviceManager = deviceManager
        self.engineController = engineController
    }

    func handle(line: String) {
        guard let data = line.data(using: .utf8) else { return }

        do {
            let command = try JSONDecoder().decode(EngineCommand.self, from: data)
            do {
                try handle(command: command)
                publisher.emitAcknowledgement(requestId: command.requestId, ok: true)
            } catch {
                let message = error.localizedDescription
                publisher.snapshot.lastError = message
                publisher.emitSnapshot()
                publisher.emitAcknowledgement(
                    requestId: command.requestId,
                    ok: false,
                    error: message
                )
            }
        } catch {
            engineController.fail(message: "Unable to decode bridge command.")
        }
    }

    private func handle(command: EngineCommand) throws {
        switch command.type {
        case "getStatus":
            // Heartbeats only need the current snapshot. Device discovery and
            // Core Audio enumeration are comparatively expensive and are
            // triggered explicitly by listInputs or system audio listeners.
            publisher.emitSnapshot()

        case "listInputs":
            deviceManager.refreshAudioEnvironment(reason: "Status requested")
            publisher.refreshPermission()
            engineController.refreshVirtualMicrophoneState()
            publisher.emitSnapshot()

        case "selectInput":
            deviceManager.refreshAudioEnvironment(reason: "Manual input selection")
            guard let inputId = command.inputId,
                  publisher.snapshot.inputs.contains(where: { $0.id == inputId }) else {
                throw EngineCommandError.invalidInputDevice
            }
            let shouldRestart = publisher.snapshot.phase == "processing"
            if shouldRestart {
                engineController.stopProcessing()
            }
            publisher.snapshot.followSystemInput = false
            publisher.snapshot.selectedInputId = inputId
            publisher.snapshot.lastError = nil
            publisher.snapshot.statusMessage = "Using selected input device"
            publisher.emitSnapshot()
            if shouldRestart {
                engineController.startProcessing()
            }

        case "followSystemInput":
            let shouldRestart = publisher.snapshot.phase == "processing"
            if shouldRestart {
                engineController.stopProcessing()
            }
            publisher.snapshot.followSystemInput = true
            deviceManager.refreshAudioEnvironment(reason: "Following system input", forceSystemSelection: true)
            publisher.snapshot.lastError = nil
            publisher.snapshot.statusMessage = publisher.idleStatusMessage(
                currentInputName: deviceManager.currentInputName()
            )
            publisher.emitSnapshot()
            if shouldRestart {
                engineController.startProcessing()
            }

        case "startProcessing":
            engineController.startProcessing()

        case "stopProcessing":
            engineController.stopProcessing()

        case "setStrength":
            guard let strength = command.strength, strength.isFinite else {
                throw EngineCommandError.invalidStrength
            }
            publisher.snapshot.strength = max(0, min(1, strength))
            engineController.setStrength(publisher.snapshot.strength)
            publisher.snapshot.statusMessage = publisher.snapshot.phase == "processing"
                ? "Processing microphone input through the native engine"
                : publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
            publisher.snapshot.lastError = nil
            publisher.emitSnapshot()

        case "setVoicePreset":
            guard let preset = command.voicePreset else {
                throw EngineCommandError.invalidVoicePreset
            }
            engineController.setVoicePreset(preset)

        case "setVirtualMicrophone":
            guard let enabled = command.enabled else {
                throw EngineCommandError.invalidVirtualMicrophoneState
            }
            try engineController.setVirtualMicrophone(enabled: enabled)
            if enabled,
               publisher.snapshot.phase != "processing",
               publisher.snapshot.phase != "starting" {
                engineController.startProcessing()
            }

        default:
            throw EngineCommandError.unsupportedCommand(command.type)
        }
    }
}

enum EngineCommandError: LocalizedError {
    case invalidInputDevice
    case invalidStrength
    case invalidVirtualMicrophoneState
    case invalidVoicePreset
    case unsupportedCommand(String)

    var errorDescription: String? {
        switch self {
        case .invalidInputDevice:
            return "The selected microphone is no longer available. Choose another microphone."
        case .invalidStrength:
            return "Denoise strength must be a number between 0 and 1."
        case .invalidVirtualMicrophoneState:
            return "Virtual microphone state is invalid."
        case .invalidVoicePreset:
            return "Voice preset must be Natural, Clear, or Broadcast."
        case .unsupportedCommand(let type):
            return "Unsupported engine command: \(type)"
        }
    }
}

// MARK: - Input Bridge

final class InputBridge: @unchecked Sendable {
    private let maximumBufferBytes = 1_000_000
    private var buffer = Data()
    private let handler: IPCCommandHandler

    init(handler: IPCCommandHandler) {
        self.handler = handler
    }

    func consume(_ data: Data) {
        buffer.append(data)
        guard buffer.count <= maximumBufferBytes else {
            buffer.removeAll(keepingCapacity: false)
            handler.handle(line: "")
            return
        }
        while let range = buffer.range(of: Data([0x0a])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.lowerBound)

            if let line = String(data: lineData, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.handler.handle(line: line)
                }
            }
        }
    }
}
