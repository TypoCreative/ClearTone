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
    private var running = false
    private var poolGeneration = 0

    func refreshState(enabled: Bool) -> VirtualMicrophoneState {
        let device = CoreAudioDevices.virtualMicrophone()
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
        guard let device = CoreAudioDevices.virtualMicrophone() else {
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
        stateLock.lock()
        running = true
        stateLock.unlock()
    }

    func stop() {
        guard running else { return }
        stateLock.lock()
        running = false
        poolGeneration += 1
        stateLock.unlock()
        player.stop()
        engine.stop()
        stateLock.lock()
        queuedBuffers = 0
        availableBuffers.removeAll(keepingCapacity: false)
        stateLock.unlock()
    }

    /// Returns queue depth in RNNoise-sized frames, or nil when the buffer is dropped.
    func enqueue(_ samples: [Float]) -> Int? {
        guard !samples.isEmpty else { return 0 }

        guard let lease = acquireBuffer(frameCount: AVAudioFrameCount(samples.count)),
              let destination = lease.buffer.pcm.floatChannelData?[0] else {
            return nil
        }

        let buffer = lease.buffer.pcm
        buffer.frameLength = AVAudioFrameCount(samples.count)
        destination.update(from: samples, count: samples.count)
        player.scheduleBuffer(buffer) { [weak self] in
            self?.releaseBuffer(lease.buffer, generation: lease.generation)
        }
        return lease.queueDepth
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

    private func acquireBuffer(frameCount: AVAudioFrameCount) -> (buffer: PooledAudioBuffer, queueDepth: Int, generation: Int)? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard running, queuedBuffers < maximumQueuedBuffers else { return nil }

        let buffer: PooledAudioBuffer?
        if let reusable = availableBuffers.popLast(), reusable.pcm.frameCapacity >= frameCount {
            buffer = reusable
        } else {
            buffer = PooledAudioBuffer(format: format, frameCapacity: frameCount)
        }
        guard let buffer else { return nil }
        queuedBuffers += 1
        return (buffer, queuedBuffers, poolGeneration)
    }

    private func releaseBuffer(_ buffer: PooledAudioBuffer, generation: Int) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard generation == poolGeneration else { return }
        queuedBuffers = max(0, queuedBuffers - 1)
        buffer.pcm.frameLength = 0
        if running && availableBuffers.count < maximumQueuedBuffers {
            availableBuffers.append(buffer)
        }
    }

    private func statusMessage(enabled: Bool, available: Bool) -> String {
        if !available { return "ClearTone Virtual Microphone driver is not installed" }
        if !enabled { return "Ready" }
        return "Routing cleaned audio to ClearTone Virtual Microphone"
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
