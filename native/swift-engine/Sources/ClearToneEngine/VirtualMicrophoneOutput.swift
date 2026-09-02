import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

private final class PooledAudioBuffer: @unchecked Sendable {
    let pcm: AVAudioPCMBuffer

    init?(
        format: AVAudioFormat,
        frameCapacity: AVAudioFrameCount
    ) {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCapacity
        ) else { return nil }
        pcm = buffer
    }
}

/// Routes processed mono PCM to the output side of the ClearTone loopback device.
/// The device's input side is what conferencing apps see as a microphone.
final class VirtualMicrophoneOutput: @unchecked Sendable {
    static let deviceName = "ClearTone Virtual Microphone"
    static let deviceUID = "com.typocreative.cleartone.virtual-microphone"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 1,
        interleaved: false
    )!
    private let stateLock = NSLock()
    private let maximumQueuedBuffers = 8
    private let outputFrameCapacity: AVAudioFrameCount = 480
    private var availableBuffers: [PooledAudioBuffer] = []
    private var queuedBuffers = 0
    private var configuredDeviceID: AudioDeviceID?
    private var running = false

    func refreshState(enabled: Bool) -> VirtualMicrophoneState {
        let device = findVirtualDevice()
        return VirtualMicrophoneState(
            enabled: enabled,
            available: device != nil,
            deviceId: device.map { String($0.id) },
            deviceName: Self.deviceName,
            statusMessage: statusMessage(enabled: enabled, available: device != nil)
        )
    }

    func start() throws {
        guard !running else { return }
        guard let device = findVirtualDevice() else {
            throw VirtualMicrophoneError.deviceUnavailable
        }

        if player.engine == nil {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        guard let outputUnit = engine.outputNode.audioUnit else {
            throw VirtualMicrophoneError.outputUnitUnavailable
        }

        var deviceID = device.id
        let status = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw VirtualMicrophoneError.cannotSelectDevice(status)
        }

        engine.prepare()
        try engine.start()
        player.play()
        prepareBufferPool()
        configuredDeviceID = device.id
        running = true
    }

    func stop() {
        guard running else { return }
        player.stop()
        engine.stop()
        stateLock.lock()
        queuedBuffers = 0
        availableBuffers.removeAll(keepingCapacity: false)
        stateLock.unlock()
        configuredDeviceID = nil
        running = false
    }

    /// Returns queue depth in RNNoise-sized frames, or nil when the buffer is dropped.
    func enqueue(_ samples: [Float]) -> Int? {
        guard running, !samples.isEmpty else { return 0 }

        guard let pooledBuffer = acquireBuffer(frameCount: AVAudioFrameCount(samples.count)),
              let destination = pooledBuffer.pcm.floatChannelData?[0] else {
            return nil
        }

        let buffer = pooledBuffer.pcm
        buffer.frameLength = AVAudioFrameCount(samples.count)
        destination.update(from: samples, count: samples.count)
        let queueDepth = currentQueueDepth
        player.scheduleBuffer(buffer) { [weak self, pooledBuffer] in
            self?.releaseBuffer(pooledBuffer)
        }
        return queueDepth
    }

    var currentQueueDepth: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return queuedBuffers
    }

    private func prepareBufferPool() {
        stateLock.lock()
        if availableBuffers.isEmpty {
            availableBuffers.reserveCapacity(maximumQueuedBuffers)
            for _ in 0..<maximumQueuedBuffers {
                if let buffer = PooledAudioBuffer(
                    format: format,
                    frameCapacity: outputFrameCapacity
                ) {
                    availableBuffers.append(buffer)
                }
            }
        }
        stateLock.unlock()
    }

    private func acquireBuffer(frameCount: AVAudioFrameCount) -> PooledAudioBuffer? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard running, queuedBuffers < maximumQueuedBuffers else { return nil }

        let buffer: PooledAudioBuffer?
        if let reusable = availableBuffers.popLast(), reusable.pcm.frameCapacity >= frameCount {
            buffer = reusable
        } else {
            buffer = PooledAudioBuffer(format: format, frameCapacity: frameCount)
        }
        guard buffer != nil else { return nil }
        queuedBuffers += 1
        return buffer
    }

    private func releaseBuffer(_ buffer: PooledAudioBuffer) {
        stateLock.lock()
        queuedBuffers = max(0, queuedBuffers - 1)
        buffer.pcm.frameLength = 0
        if running && availableBuffers.count < maximumQueuedBuffers {
            availableBuffers.append(buffer)
        }
        stateLock.unlock()
    }

    private func statusMessage(enabled: Bool, available: Bool) -> String {
        if !available { return "ClearTone Virtual Microphone driver is not installed" }
        if !enabled { return "Ready" }
        return "Routing cleaned audio to ClearTone Virtual Microphone"
    }

    private func findVirtualDevice() -> (id: AudioDeviceID, uid: String)? {
        audioDeviceIDs().compactMap { id -> (AudioDeviceID, String)? in
            guard let uid = stringProperty(
                objectID: id,
                selector: kAudioDevicePropertyDeviceUID
            ) else { return nil }
            let name = stringProperty(
                objectID: id,
                selector: kAudioObjectPropertyName
            )
            guard uid == Self.deviceUID || name == Self.deviceName else { return nil }
            return (id, uid)
        }.first
    }

    private func audioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        ) == noErr else { return [] }
        return devices
    }

    private func stringProperty(objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
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
}

enum VirtualMicrophoneError: LocalizedError {
    case deviceUnavailable
    case outputUnitUnavailable
    case cannotSelectDevice(OSStatus)
    case microphonePermissionRequired
    case physicalInputRequired

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "ClearTone Virtual Microphone driver is not installed."
        case .outputUnitUnavailable:
            return "The virtual microphone audio output is unavailable."
        case .cannotSelectDevice(let status):
            return "Could not select ClearTone Virtual Microphone (Core Audio error \(status))."
        case .microphonePermissionRequired:
            return "Allow microphone access before enabling Virtual Microphone."
        case .physicalInputRequired:
            return "Connect a physical microphone before enabling Virtual Microphone."
        }
    }
}
