import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

final class AudioEngineController: @unchecked Sendable {
    private let publisher: EngineStatePublisher
    private let deviceManager: AudioDeviceManager
    private let noiseProcessor: RNNoiseProcessor

    // Core Audio capture
    private let audioEngine = AVAudioEngine()
    private var isCapturing = false

    init(publisher: EngineStatePublisher, deviceManager: AudioDeviceManager, noiseProcessor: RNNoiseProcessor) {
        self.publisher = publisher
        self.deviceManager = deviceManager
        self.noiseProcessor = noiseProcessor
    }

    func startProcessing() {
        deviceManager.refreshAudioEnvironment(
            reason: "Start requested",
            forceSystemSelection: publisher.snapshot.followSystemInput
        )
        publisher.refreshPermission()

        guard !publisher.snapshot.inputs.isEmpty else {
            fail(message: "No microphone devices are available.")
            return
        }

        if publisher.snapshot.selectedInputId == nil {
            publisher.snapshot.selectedInputId = publisher.snapshot.systemInputId ?? publisher.snapshot.inputs.first?.id
        }

        let currentPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        switch currentPermission {
        case .authorized:
            beginAudioCapture()
        case .notDetermined:
            publisher.snapshot.phase = "starting"
            publisher.snapshot.statusMessage = "Requesting microphone access"
            publisher.snapshot.lastError = nil
            publisher.emitSnapshot()

            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.publisher.refreshPermission()
                    if granted {
                        self?.beginAudioCapture()
                    } else {
                        self?.fail(message: "Microphone access was denied.")
                    }
                }
            }
        case .denied, .restricted:
            fail(
                message: "Microphone access was denied. Enable ClearTone in System Settings > Privacy & Security > Microphone, then restart the app."
            )
        @unknown default:
            fail(message: "Microphone permission state is unknown.")
        }
    }

    func stopProcessing() {
        publisher.snapshot.phase = "stopping"
        publisher.snapshot.statusMessage = "Stopping native engine"
        publisher.snapshot.lastError = nil
        publisher.emitSnapshot()

        stopAudioCapture()
        noiseProcessor.stop()

        deviceManager.refreshAudioEnvironment(
            reason: "Stop requested",
            forceSystemSelection: publisher.snapshot.followSystemInput
        )
        publisher.snapshot.phase = "idle"
        publisher.snapshot.statusMessage = publisher.idleStatusMessage(
            currentInputName: deviceManager.currentInputName()
        )
        publisher.emitSnapshot()
    }

    func fail(message: String) {
        stopAudioCapture()
        noiseProcessor.stop()
        publisher.snapshot.phase = "error"
        publisher.snapshot.lastError = message
        publisher.snapshot.statusMessage = "Native engine needs attention"
        publisher.emitSnapshot()
    }

    func setVirtualMicrophone(enabled: Bool) throws {
        noiseProcessor.refreshVirtualMicrophoneState()

        if enabled {
            publisher.refreshPermission()
            guard publisher.snapshot.permission == "granted" else {
                throw VirtualMicrophoneError.microphonePermissionRequired
            }
            guard !publisher.snapshot.inputs.isEmpty else {
                throw VirtualMicrophoneError.physicalInputRequired
            }
            do {
                try noiseProcessor.setVirtualMicrophone(enabled: true)
                try deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: true)
            } catch {
                try? noiseProcessor.setVirtualMicrophone(enabled: false)
                throw error
            }
        } else {
            try deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: false)
            try noiseProcessor.setVirtualMicrophone(enabled: false)
        }

        publisher.snapshot.lastError = nil
        publisher.snapshot.statusMessage = publisher.snapshot.virtualMicrophone.statusMessage
        publisher.emitSnapshot()
    }

    func refreshVirtualMicrophoneState() {
        noiseProcessor.refreshVirtualMicrophoneState()
    }

    func setStrength(_ value: Double) {
        noiseProcessor.setStrength(value)
    }

    func restartAfterDeviceChange() {
        stopProcessing()
        startProcessing()
    }

    // MARK: - Audio Capture

    private func beginAudioCapture() {
        guard !isCapturing else { return }

        let inputNode = audioEngine.inputNode
        _ = inputNode.outputFormat(forBus: 0)

        if let selectedUID = publisher.snapshot.selectedInputId,
           let selectedDeviceID = deviceManager.audioDeviceID(forUID: selectedUID),
           let inputUnit = inputNode.audioUnit {
            var mutableDeviceID = selectedDeviceID
            let status = AudioUnitSetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else {
                fail(message: "Could not select the requested microphone (Core Audio error \(status)).")
                return
            }
        }

        // Configure desired format: Float32, mono, 48kHz
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        ) else {
            fail(message: "Failed to create audio format (48kHz, Float32, mono).")
            return
        }

        // Install tap with 480-sample buffer (= 1 RNNoise frame = 10ms)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 480,
            format: desiredFormat
        ) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isCapturing = true
        } catch {
            fail(message: "Failed to start audio engine: \(error.localizedDescription)")
            return
        }

        // Notify RNNoise processor
        noiseProcessor.start(strength: publisher.snapshot.strength)
        if publisher.snapshot.phase == "error" {
            stopAudioCapture()
        }
    }

    private func stopAudioCapture() {
        guard isCapturing else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isCapturing = false
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        noiseProcessor.feedSamples(
            samples,
            capturedAtNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }
}
