import AppKit
import SwiftUI

// MARK: - Engine Runtime (Coordinator)

final class EngineRuntime: @unchecked Sendable {
    let publisher: EngineStatePublisher
    let deviceManager: AudioDeviceManager
    let noiseProcessor: RNNoiseProcessor
    let virtualMicrophoneOutput: VirtualMicrophoneOutput
    let engineController: AudioEngineController
    let commandHandler: IPCCommandHandler
    let inputBridge: InputBridge

    private var isShuttingDown = false

    init() {
        publisher = EngineStatePublisher()
        deviceManager = AudioDeviceManager(publisher: publisher)
        virtualMicrophoneOutput = VirtualMicrophoneOutput()
        noiseProcessor = RNNoiseProcessor(
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
        commandHandler = IPCCommandHandler(
            publisher: publisher,
            deviceManager: deviceManager,
            engineController: engineController
        )
        inputBridge = InputBridge(handler: commandHandler)

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
        if publisher.snapshot.virtualMicrophone.enabled {
            try? deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: false)
        }
        deviceManager.uninstallAudioListeners()
    }
}

// MARK: - Entry Point

@main
struct ClearToneApp: App {
    @NSApplicationDelegateAdaptor(ClearToneAppDelegate.self) private var appDelegate
    @StateObject private var model = ClearToneAppModel()

    var body: some Scene {
        Window("ClearTone", id: "main") {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 620)
        }
        .defaultSize(width: 880, height: 720)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isProcessing ? "waveform.circle.fill" : "waveform.circle")
                .accessibilityLabel(model.isProcessing ? "ClearTone processing" : "ClearTone idle")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ClearToneAppDelegate: NSObject, NSApplicationDelegate {
    static var terminationHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.terminationHandler?()
    }
}
