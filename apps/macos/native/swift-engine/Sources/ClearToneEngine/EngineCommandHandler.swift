import Foundation

enum EngineCommand {
    case refreshDevices
    case selectInput(String)
    case followSystemInput
    case startProcessing
    case stopProcessing
    case setStrength(Double)
    case setVoicePreset(VoicePreset)
    case setVirtualMicrophone(Bool)
}

/// Applies native UI actions. Capture and DSP lifecycle remain in their own controllers.
@MainActor
final class EngineCommandHandler {
    private let publisher: EngineStatePublisher
    private let deviceManager: AudioDeviceManager
    private let controller: AudioEngineController

    init(publisher: EngineStatePublisher, deviceManager: AudioDeviceManager, controller: AudioEngineController) {
        self.publisher = publisher
        self.deviceManager = deviceManager
        self.controller = controller
    }

    func handle(_ command: EngineCommand) throws {
        switch command {
        case .refreshDevices:
            deviceManager.refreshAudioEnvironment()
            publisher.refreshPermission()
            controller.refreshVirtualMicrophoneState()
            publisher.emitSnapshot()

        case .selectInput(let id):
            deviceManager.refreshAudioEnvironment()
            guard publisher.snapshot.inputs.contains(where: { $0.id == id }) else {
                throw EngineCommandError.invalidInputDevice
            }
            updateInputSelection {
                publisher.snapshot.followSystemInput = false
                publisher.snapshot.selectedInputId = id
            }

        case .followSystemInput:
            updateInputSelection {
                publisher.snapshot.followSystemInput = true
                deviceManager.refreshAudioEnvironment()
            }

        case .startProcessing:
            controller.startProcessing()

        case .stopProcessing:
            controller.stopProcessing()

        case .setStrength(let strength):
            guard strength.isFinite else { throw EngineCommandError.invalidStrength }
            publisher.snapshot.strength = max(0, min(1, strength))
            controller.setStrength(publisher.snapshot.strength)
            publisher.snapshot.lastError = nil
            publisher.snapshot.statusMessage = publisher.snapshot.phase == .processing
                ? EngineSnapshot.processingMessage
                : publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
            publisher.emitSnapshot()

        case .setVoicePreset(let preset):
            controller.setVoicePreset(preset)

        case .setVirtualMicrophone(let enabled):
            try controller.setVirtualMicrophone(enabled: enabled)
            if enabled && !publisher.snapshot.phase.isProcessing {
                controller.startProcessing()
            }
        }
    }

    private func updateInputSelection(_ update: () -> Void) {
        let shouldRestart = publisher.snapshot.phase == .processing
        if shouldRestart { controller.stopProcessing() }
        update()
        publisher.snapshot.lastError = nil
        publisher.snapshot.statusMessage = publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
        publisher.emitSnapshot()
        if shouldRestart { controller.startProcessing() }
    }
}

enum EngineCommandError: LocalizedError {
    case invalidInputDevice
    case invalidStrength

    var errorDescription: String? {
        switch self {
        case .invalidInputDevice:
            "The selected microphone is no longer available. Choose another microphone."
        case .invalidStrength:
            "Denoise strength must be a number between 0 and 1."
        }
    }
}
