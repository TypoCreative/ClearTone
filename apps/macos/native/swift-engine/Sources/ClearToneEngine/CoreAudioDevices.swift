import CoreAudio

/// Shared Core Audio property access for capture selection and virtual output.
enum CoreAudioDevices {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static func allIDs() -> [AudioDeviceID] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &property, 0, nil, &size) == noErr,
              size > 0, Int(size) % MemoryLayout<AudioDeviceID>.size == 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &property, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return Array(devices.prefix(Int(size) / MemoryLayout<AudioDeviceID>.size))
    }

    static func stringProperty(_ selector: AudioObjectPropertySelector, of object: AudioObjectID) -> String? {
        var property = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeUnretainedValue() as String?
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allIDs().first { stringProperty(kAudioDevicePropertyDeviceUID, of: $0) == uid }
    }

    static func defaultInputUID() -> String? {
        var property = address(kAudioHardwarePropertyDefaultInputDevice)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &property, 0, nil, &size, &device) == noErr,
              device != 0 else { return nil }
        return stringProperty(kAudioDevicePropertyDeviceUID, of: device)
    }

    static func virtualMicrophone() -> (id: AudioDeviceID, uid: String)? {
        for id in allIDs() {
            guard let uid = stringProperty(kAudioDevicePropertyDeviceUID, of: id) else { continue }
            if uid == VirtualMicrophoneOutput.deviceUID
                || stringProperty(kAudioObjectPropertyName, of: id) == VirtualMicrophoneOutput.deviceName {
                return (id, uid)
            }
        }
        return nil
    }
}
