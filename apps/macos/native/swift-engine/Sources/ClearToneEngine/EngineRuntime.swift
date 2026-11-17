import Foundation

@MainActor
final class EngineRuntime {
    let publisher: EngineStatePublisher
    private let deviceManager: AudioDeviceManager
    private let engineController: AudioEngineController
    let commandHandler: EngineCommandHandler

    private var isShuttingDown = false

    init() {
        publisher = EngineStatePublisher()
        deviceManager = AudioDeviceManager(publisher: publisher)
        let virtualMicrophoneOutput = VirtualMicrophoneOutput()
        let noiseProcessor = RNNoiseProcessor(
            publisher: publisher,
            virtualOutput: virtualMicrophoneOutput
        )
        engineController = AudioEngineController(
            publisher: publisher,
            deviceManager: deviceManager,
            noiseProcessor: noiseProcessor
        )
        deviceManager.onProcessingDeviceChange = { [weak engineController] in
            engineController?.restartAfterDeviceChange()
        }
        commandHandler = EngineCommandHandler(
            publisher: publisher,
            deviceManager: deviceManager,
            controller: engineController
        )

        deviceManager.refreshAudioEnvironment()
        publisher.refreshPermission()
        deviceManager.installAudioListeners()
        publisher.transition(
            to: .idle,
            message: publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
        )
    }

    func prepareForTermination() {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        engineController.stopProcessing()
        if publisher.snapshot.virtualMicrophone.enabled {
            try? deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: false)
        }
        deviceManager.uninstallAudioListeners()
    }
}
