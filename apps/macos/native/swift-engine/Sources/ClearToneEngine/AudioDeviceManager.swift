import CoreAudio
import AVFoundation
import Foundation

final class AudioDeviceManager: @unchecked Sendable {
    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

    private let observedSelectors: [AudioObjectPropertySelector] = [
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioHardwarePropertyDevices
    ]

    private var audioListenersInstalled = false
    private var previousPhysicalDefaultInputUID: String?

    private let publisher: EngineStatePublisher
    var onProcessingDeviceChange: (() -> Void)?

    private lazy var environmentListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.handleAudioEnvironmentChange()
    }

    init(publisher: EngineStatePublisher) {
        self.publisher = publisher
    }

    // MARK: - Device Discovery

    func currentInputName() -> String? {
        publisher.snapshot.inputs.first(where: { $0.id == publisher.snapshot.selectedInputId })?.name
    }

    func refreshAudioEnvironment() {
        let rawDefaultInputId = CoreAudioDevices.defaultInputUID()
        let virtualUID = CoreAudioDevices.virtualMicrophone()?.uid
        func isVirtual(_ uid: String?) -> Bool {
            guard let uid else { return false }
            return uid == VirtualMicrophoneOutput.deviceUID || uid == virtualUID
        }
        let defaultInputId = isVirtual(rawDefaultInputId)
            ? previousPhysicalDefaultInputUID ?? publisher.snapshot.selectedInputId
            : rawDefaultInputId
        if let rawDefaultInputId, !isVirtual(rawDefaultInputId) {
            previousPhysicalDefaultInputUID = rawDefaultInputId
        }
        publisher.snapshot.systemInputId = defaultInputId

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        publisher.snapshot.inputs = discoverySession.devices
            .filter { !isVirtual($0.uniqueID) && $0.localizedName != VirtualMicrophoneOutput.deviceName }
            .map { device in
                AudioInputDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    manufacturer: "macOS",
                    isDefault: device.uniqueID == defaultInputId
                )
            }

        if !publisher.snapshot.followSystemInput,
           publisher.snapshot.inputs.contains(where: { $0.id == publisher.snapshot.selectedInputId }) {
            return
        }
        publisher.snapshot.selectedInputId = Self.availableInput(preferred: defaultInputId, inputs: publisher.snapshot.inputs)
        publisher.snapshot.followSystemInput = true
    }

    static func availableInput(preferred: String?, inputs: [AudioInputDevice]) -> String? {
        inputs.first(where: { $0.id == preferred })?.id ?? inputs.first?.id
    }

    func setVirtualMicrophoneAsSystemDefault(enabled: Bool) throws {
        let targetUID: String
        if enabled {
            if let current = CoreAudioDevices.defaultInputUID(), !isVirtualMicrophoneUID(current) {
                previousPhysicalDefaultInputUID = current
            }
            guard let virtualUID = CoreAudioDevices.virtualMicrophone()?.uid else {
                throw AudioDeviceError.virtualMicrophoneUnavailable
            }
            targetUID = virtualUID
        } else {
            guard let physicalUID = Self.availableInput(
                preferred: previousPhysicalDefaultInputUID ?? publisher.snapshot.selectedInputId,
                inputs: publisher.snapshot.inputs
            ) else {
                throw AudioDeviceError.physicalInputUnavailable
            }
            targetUID = physicalUID
        }

        guard let targetDeviceID = CoreAudioDevices.deviceID(forUID: targetUID) else {
            throw enabled
                ? AudioDeviceError.virtualMicrophoneUnavailable
                : AudioDeviceError.physicalInputUnavailable
        }

        var address = CoreAudioDevices.address(kAudioHardwarePropertyDefaultInputDevice)
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
        return uid == VirtualMicrophoneOutput.deviceUID || uid == CoreAudioDevices.virtualMicrophone()?.uid
    }

    private func handleAudioEnvironmentChange() {
        let wasProcessing = publisher.snapshot.phase == .processing
        let previousInput = publisher.snapshot.selectedInputId
        refreshAudioEnvironment()
        if wasProcessing && previousInput != publisher.snapshot.selectedInputId {
            onProcessingDeviceChange?()
        } else {
            if !wasProcessing {
                publisher.snapshot.statusMessage = publisher.idleStatusMessage(currentInputName: currentInputName())
            }
            publisher.emitSnapshot()
        }
    }

    // MARK: - Audio Listeners

    func installAudioListeners() {
        guard !audioListenersInstalled else { return }

        for selector in observedSelectors {
            var address = CoreAudioDevices.address(selector)
            AudioObjectAddPropertyListenerBlock(systemObjectID, &address, .main, environmentListener)
        }
        audioListenersInstalled = true
    }

    func uninstallAudioListeners() {
        guard audioListenersInstalled else { return }

        for selector in observedSelectors {
            var address = CoreAudioDevices.address(selector)
            AudioObjectRemovePropertyListenerBlock(systemObjectID, &address, .main, environmentListener)
        }
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
