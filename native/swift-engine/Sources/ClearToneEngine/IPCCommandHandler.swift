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
            handle(command: command)
        } catch {
            engineController.fail(message: "Unable to decode bridge command.")
        }
    }

    private func handle(command: EngineCommand) {
        switch command.type {
        case "getStatus", "listInputs":
            deviceManager.refreshAudioEnvironment(reason: "Status requested")
            publisher.refreshPermission()
            publisher.emitSnapshot()

        case "selectInput":
            deviceManager.refreshAudioEnvironment(reason: "Manual input selection")
            publisher.snapshot.followSystemInput = false
            publisher.snapshot.selectedInputId = command.inputId
            publisher.snapshot.lastError = nil
            publisher.snapshot.statusMessage = "Using selected input device"
            publisher.emitSnapshot()

        case "followSystemInput":
            publisher.snapshot.followSystemInput = true
            deviceManager.refreshAudioEnvironment(reason: "Following system input", forceSystemSelection: true)
            publisher.snapshot.lastError = nil
            publisher.snapshot.statusMessage = publisher.idleStatusMessage(
                currentInputName: deviceManager.currentInputName()
            )
            publisher.emitSnapshot()

        case "startProcessing":
            engineController.startProcessing()

        case "stopProcessing":
            engineController.stopProcessing()

        case "setStrength":
            publisher.snapshot.strength = max(0, min(1, command.strength ?? publisher.snapshot.strength))
            publisher.snapshot.statusMessage = publisher.snapshot.phase == "processing"
                ? "Processing microphone input through the native engine"
                : publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
            publisher.snapshot.lastError = nil
            publisher.emitSnapshot()

        default:
            engineController.fail(message: "Unsupported engine command: \(command.type)")
        }
    }
}

// MARK: - Input Bridge

final class InputBridge: @unchecked Sendable {
    private var buffer = Data()
    private let handler: IPCCommandHandler

    init(handler: IPCCommandHandler) {
        self.handler = handler
    }

    func consume(_ data: Data) {
        buffer.append(data)
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
