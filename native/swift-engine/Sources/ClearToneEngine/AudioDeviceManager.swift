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
    private var previousPhysicalDefaultInputUID: String?

    let publisher: EngineStatePublisher
    var onProcessingDeviceChange: (() -> Void)?

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
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
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

        return uid?.takeUnretainedValue() as String?
    }

    func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        allAudioDeviceIDs().first { deviceID in
            stringProperty(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceUID
            ) == uid
        }
    }

    func currentInputName() -> String? {
        publisher.snapshot.inputs.first(where: { $0.id == publisher.snapshot.selectedInputId })?.name
    }

    func refreshAudioEnvironment(reason _: String = "", forceSystemSelection: Bool = false) {
        let rawDefaultInputId = currentDefaultInputUID()
        let defaultInputId = isVirtualMicrophoneUID(rawDefaultInputId)
            ? previousPhysicalDefaultInputUID ?? publisher.snapshot.selectedInputId
            : rawDefaultInputId
        if let rawDefaultInputId, !isVirtualMicrophoneUID(rawDefaultInputId) {
            previousPhysicalDefaultInputUID = rawDefaultInputId
        }
        publisher.snapshot.systemInputId = defaultInputId

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        publisher.snapshot.inputs = discoverySession.devices
            .filter { !isVirtualMicrophoneUID($0.uniqueID) && $0.localizedName != VirtualMicrophoneOutput.deviceName }
            .map { device in
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

    func setVirtualMicrophoneAsSystemDefault(enabled: Bool) throws {
        let targetUID: String
        if enabled {
            if let current = currentDefaultInputUID(), !isVirtualMicrophoneUID(current) {
                previousPhysicalDefaultInputUID = current
            }
            guard let virtualUID = virtualMicrophoneDeviceUID() else {
                throw AudioDeviceError.virtualMicrophoneUnavailable
            }
            targetUID = virtualUID
        } else {
            guard let physicalUID = previousPhysicalDefaultInputUID
                ?? publisher.snapshot.selectedInputId
                ?? publisher.snapshot.inputs.first?.id else {
                throw AudioDeviceError.physicalInputUnavailable
            }
            targetUID = physicalUID
        }

        guard let targetDeviceID = audioDeviceID(forUID: targetUID) else {
            throw enabled
                ? AudioDeviceError.virtualMicrophoneUnavailable
                : AudioDeviceError.physicalInputUnavailable
        }

        var address = defaultInputAddress
        var mutableDeviceID = targetDeviceID
        let status = AudioObjectSetPropertyData(
            systemObjectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        guard status == noErr else {
            throw AudioDeviceError.cannotSetSystemInput(status)
        }
    }

    private func isVirtualMicrophoneUID(_ uid: String?) -> Bool {
        guard let uid else { return false }
        return uid == VirtualMicrophoneOutput.deviceUID || uid == virtualMicrophoneDeviceUID()
    }

    private func virtualMicrophoneDeviceUID() -> String? {
        allAudioDeviceIDs().compactMap { deviceID -> String? in
            let uid = stringProperty(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceUID
            )
            let name = stringProperty(
                objectID: deviceID,
                selector: kAudioObjectPropertyName
            )
            return uid == VirtualMicrophoneOutput.deviceUID || name == VirtualMicrophoneOutput.deviceName
                ? uid
                : nil
        }.first
    }

    private func allAudioDeviceIDs() -> [AudioDeviceID] {
        var address = devicesAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            systemObjectID,
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        var devices = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            systemObjectID,
            &address,
            0,
            nil,
            &size,
            &devices
        ) == noErr else { return [] }
        return devices
    }

    private func stringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &value
        ) == noErr else { return nil }
        return value?.takeUnretainedValue() as String?
    }

    func handleAudioEnvironmentChange(reason: String, wasProcessing: Bool) {
        refreshAudioEnvironment(reason: reason, forceSystemSelection: publisher.snapshot.followSystemInput)
        if wasProcessing {
            onProcessingDeviceChange?()
            return
        } else {
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

enum AudioDeviceError: LocalizedError {
    case virtualMicrophoneUnavailable
    case physicalInputUnavailable
    case cannotSetSystemInput(OSStatus)

    var errorDescription: String? {
        switch self {
        case .virtualMicrophoneUnavailable:
            return "ClearTone Virtual Microphone driver is not installed."
        case .physicalInputUnavailable:
            return "No physical microphone is available to restore."
        case .cannotSetSystemInput(let status):
            return "Could not change the system microphone (Core Audio error \(status))."
        }
    }
}
