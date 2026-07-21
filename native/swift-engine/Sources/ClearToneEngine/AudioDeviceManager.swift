import CoreAudio
import AVFoundation
import Foundation

final class AudioDeviceManager: @unchecked Sendable {
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

    private var audioListenersInstalled = false

    let publisher: EngineStatePublisher

    private lazy var defaultInputListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self else { return }
        let wasProcessing = self.publisher.snapshot.phase == "processing"
        self.handleAudioEnvironmentChange(reason: "System input changed", wasProcessing: wasProcessing)
    }

    private lazy var devicesListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self else { return }
        let wasProcessing = self.publisher.snapshot.phase == "processing"
        self.handleAudioEnvironmentChange(reason: "Audio devices updated", wasProcessing: wasProcessing)
    }

    init(publisher: EngineStatePublisher) {
        self.publisher = publisher
    }

    // MARK: - Device Discovery

    func currentDefaultInputUID() -> String? {
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

    func currentInputName() -> String? {
        publisher.snapshot.inputs.first(where: { $0.id == publisher.snapshot.selectedInputId })?.name
    }

    func refreshAudioEnvironment(reason _: String = "", forceSystemSelection: Bool = false) {
        let defaultInputId = currentDefaultInputUID()
        publisher.snapshot.systemInputId = defaultInputId

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        publisher.snapshot.inputs = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                manufacturer: "macOS",
                isDefault: device.uniqueID == defaultInputId
            )
        }

        let availableIds = Set(publisher.snapshot.inputs.map(\.id))
        if publisher.snapshot.followSystemInput || forceSystemSelection {
            publisher.snapshot.selectedInputId = defaultInputId ?? publisher.snapshot.inputs.first?.id
            publisher.snapshot.followSystemInput = true
        } else if let selectedId = publisher.snapshot.selectedInputId, availableIds.contains(selectedId) {
            publisher.snapshot.selectedInputId = selectedId
        } else {
            publisher.snapshot.selectedInputId = defaultInputId ?? publisher.snapshot.inputs.first?.id
            publisher.snapshot.followSystemInput = true
        }
    }

    func handleAudioEnvironmentChange(reason: String, wasProcessing: Bool) {
        refreshAudioEnvironment(reason: reason, forceSystemSelection: publisher.snapshot.followSystemInput)
        if !wasProcessing {
            publisher.snapshot.statusMessage = publisher.idleStatusMessage(currentInputName: currentInputName())
        }
        publisher.emitSnapshot()
    }

    // MARK: - Audio Listeners

    func installAudioListeners() {
        guard !audioListenersInstalled else { return }

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
        audioListenersInstalled = true
    }

    func uninstallAudioListeners() {
        guard audioListenersInstalled else { return }

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
        audioListenersInstalled = false
    }
}
