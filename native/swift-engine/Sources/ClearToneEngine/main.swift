import Foundation

// MARK: - Engine Runtime (Coordinator)

final class EngineRuntime: @unchecked Sendable {
    let publisher: EngineStatePublisher
    let deviceManager: AudioDeviceManager
    let noiseProcessor: NoiseReductionProcessor
    let engineController: AudioEngineController
    let commandHandler: IPCCommandHandler
    let inputBridge: InputBridge

    private var isShuttingDown = false

    init() {
        // 1. Create state publisher
        publisher = EngineStatePublisher()

        // 2. Create device manager
        deviceManager = AudioDeviceManager(publisher: publisher)

        // 3. Create noise processor — real RNNoise for production, simulated for testing
        noiseProcessor = RNNoiseProcessor(publisher: publisher)
        // noiseProcessor = SimulatedNoiseReductionProcessor(publisher: publisher)

        // 4. Create engine controller
        engineController = AudioEngineController(
            publisher: publisher,
            deviceManager: deviceManager,
            noiseProcessor: noiseProcessor
        )

        // 5. Create command handler
        commandHandler = IPCCommandHandler(
            publisher: publisher,
            deviceManager: deviceManager,
            engineController: engineController
        )

        // 6. Create input bridge
        inputBridge = InputBridge(handler: commandHandler)

        // 7. Initialize engine state
        deviceManager.refreshAudioEnvironment(reason: "startup", forceSystemSelection: true)
        publisher.refreshPermission()
        deviceManager.installAudioListeners()
        publisher.snapshot.phase = "idle"
        publisher.snapshot.statusMessage = publisher.idleStatusMessage(
            currentInputName: deviceManager.currentInputName()
        )
        publisher.emitSnapshot()
    }

    func prepareForTermination() {
        guard !isShuttingDown else { return }
        isShuttingDown = true

        noiseProcessor.stop()
        deviceManager.uninstallAudioListeners()
    }

    func run() -> Never {
        FileHandle.standardInput.readabilityHandler = { [inputBridge, weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                FileHandle.standardInput.readabilityHandler = nil
                DispatchQueue.main.async {
                    self?.prepareForTermination()
                    exit(EXIT_SUCCESS)
                }
                return
            }

            inputBridge.consume(data)
        }

        dispatchMain()
    }
}

// MARK: - Entry Point

let runtime = EngineRuntime()
runtime.run()
