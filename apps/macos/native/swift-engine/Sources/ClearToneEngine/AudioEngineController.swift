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
    private let processingFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 1,
        interleaved: false
    )!
    private var configurationObserver: NSObjectProtocol?
    private var isCapturing = false
    private var isTapInstalled = false
    private var captureGeneration = 0
    private let maximumStartAttempts = 3
    private let startRetryDelay: TimeInterval = 0.25

    init(publisher: EngineStatePublisher, deviceManager: AudioDeviceManager, noiseProcessor: RNNoiseProcessor) {
        self.publisher = publisher
        self.deviceManager = deviceManager
        self.noiseProcessor = noiseProcessor
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: .main
        ) { [weak self] _ in
            guard let self, self.isCapturing, !self.audioEngine.isRunning else { return }
            self.restartAfterDeviceChange()
        }
    }

    func startProcessing() {
        guard !isCapturing, publisher.snapshot.phase != .starting else { return }
        captureGeneration += 1
        let generation = captureGeneration

        publisher.refreshPermission()

        let currentPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        switch currentPermission {
        case .authorized:
            beginAudioCapture(generation: generation, attempt: 1)
        case .notDetermined:
            publisher.transition(to: .starting, message: "Requesting microphone access")

            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard self?.captureGeneration == generation else { return }
                    self?.publisher.refreshPermission()
                    if granted {
                        self?.beginAudioCapture(generation: generation, attempt: 1)
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
        captureGeneration += 1
        publisher.transition(to: .stopping, message: "Stopping native engine")

        stopAudioCapture()
        noiseProcessor.stop()

        deviceManager.refreshAudioEnvironment()
        publisher.transition(
            to: .idle,
            message: publisher.idleStatusMessage(currentInputName: deviceManager.currentInputName())
        )
    }

    func fail(message: String) {
        captureGeneration += 1
        stopAudioCapture()
        if publisher.snapshot.virtualMicrophone.enabled {
            try? deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: false)
            try? noiseProcessor.setVirtualMicrophone(enabled: false)
        }
        noiseProcessor.stop()
        publisher.transition(to: .error, message: "Native engine needs attention", error: message)
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

    func setVoicePreset(_ preset: VoicePreset) {
        publisher.snapshot.voicePreset = preset
        noiseProcessor.setVoicePreset(preset)
        publisher.snapshot.lastError = nil
        publisher.snapshot.statusMessage = "Voice profile: \(preset.rawValue.capitalized)"
        publisher.emitSnapshot()
    }

    func restartAfterDeviceChange() {
        stopProcessing()
        startProcessing()
    }

    // MARK: - Audio Capture

    private func beginAudioCapture(generation: Int, attempt: Int) {
        guard generation == captureGeneration, !isCapturing else { return }

        deviceManager.refreshAudioEnvironment()
        guard !publisher.snapshot.inputs.isEmpty else {
            fail(message: "No microphone devices are available.")
            return
        }

        publisher.transition(
            to: .starting,
            message: attempt == 1 ? "Starting audio engine" : "Retrying audio engine startup"
        )

        stopAudioCapture()

        do {
            try startAudioCapture()
        } catch {
            retryOrFailStart(message: error.localizedDescription, generation: generation, attempt: attempt)
            return
        }

        // Notify RNNoise processor
        noiseProcessor.start(strength: publisher.snapshot.strength)
        if publisher.snapshot.phase == .error {
            stopAudioCapture()
        }
    }

    private func startAudioCapture() throws {
        let inputNode = audioEngine.inputNode
        guard let selectedUID = publisher.snapshot.selectedInputId,
              let selectedDeviceID = CoreAudioDevices.deviceID(forUID: selectedUID),
              let inputUnit = inputNode.audioUnit else {
            throw AudioCaptureError("The selected microphone disconnected. Choose an available microphone.")
        }
        var deviceID = selectedDeviceID
        let status = AudioUnitSetProperty(
            inputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global,
            0, &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioCaptureError("Could not select the requested microphone (Core Audio error \(status)).")
        }

        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            throw AudioCaptureError("The selected microphone is not ready yet.")
        }
        let conversion = try CaptureConversion(inputFormat: hardwareFormat, outputFormat: processingFormat)
        inputNode.installTap(onBus: 0, bufferSize: 480, format: hardwareFormat) { [weak self] buffer, _ in
            guard let processed = conversion.convert(buffer),
                  let samples = processed.floatChannelData?[0] else { return }
            self?.noiseProcessor.feedSamples(
                samples, count: Int(processed.frameLength),
                capturedAtNanoseconds: DispatchTime.now().uptimeNanoseconds
            )
        }
        isTapInstalled = true
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw AudioCaptureError("Failed to start audio engine: \(error.localizedDescription)")
        }
        isCapturing = true
    }

    private func stopAudioCapture() {
        // Suppress reentrant configuration notifications during intentional stops.
        isCapturing = false
        audioEngine.stop()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.reset()
    }

    private func retryOrFailStart(message: String, generation: Int, attempt: Int) {
        stopAudioCapture()
        guard generation == captureGeneration else { return }

        if attempt < maximumStartAttempts {
            publisher.transition(to: .starting, message: "Microphone is reconnecting…")
            DispatchQueue.main.asyncAfter(deadline: .now() + startRetryDelay) { [weak self] in
                guard let self, self.captureGeneration == generation else { return }
                self.beginAudioCapture(generation: generation, attempt: attempt + 1)
            }
            return
        }

        fail(message: message)
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }
}
