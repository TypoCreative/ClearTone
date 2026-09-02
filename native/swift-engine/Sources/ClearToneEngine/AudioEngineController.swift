import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

private final class ConverterInputBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var supplied = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

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
    private var inputConverter: AVAudioConverter?
    private var convertedBuffer: AVAudioPCMBuffer?
    private var isCapturing = false
    private var isTapInstalled = false
    private var captureGeneration = 0
    private let maximumStartAttempts = 3
    private let startRetryDelay: TimeInterval = 0.25

    init(publisher: EngineStatePublisher, deviceManager: AudioDeviceManager, noiseProcessor: RNNoiseProcessor) {
        self.publisher = publisher
        self.deviceManager = deviceManager
        self.noiseProcessor = noiseProcessor
    }

    func startProcessing() {
        guard !isCapturing, publisher.snapshot.phase != "starting" else { return }
        captureGeneration += 1
        let generation = captureGeneration

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
            beginAudioCapture(generation: generation, attempt: 1)
        case .notDetermined:
            publisher.snapshot.phase = "starting"
            publisher.snapshot.statusMessage = "Requesting microphone access"
            publisher.snapshot.lastError = nil
            publisher.emitSnapshot()

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
        captureGeneration += 1
        stopAudioCapture()
        if publisher.snapshot.virtualMicrophone.enabled {
            try? deviceManager.setVirtualMicrophoneAsSystemDefault(enabled: false)
            try? noiseProcessor.setVirtualMicrophone(enabled: false)
        }
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

        publisher.snapshot.phase = "starting"
        publisher.snapshot.statusMessage = attempt == 1
            ? "Starting audio engine"
            : "Retrying audio engine startup"
        publisher.snapshot.lastError = nil
        publisher.emitSnapshot()

        stopAudioCapture()

        let inputNode = audioEngine.inputNode

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
                retryOrFailStart(
                    message: "Could not select the requested microphone (Core Audio error \(status)).",
                    generation: generation,
                    attempt: attempt
                )
                return
            }
        }

        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            retryOrFailStart(
                message: "The selected microphone is not ready yet.",
                generation: generation,
                attempt: attempt
            )
            return
        }

        // Configure desired format: Float32, mono, 48kHz
        inputConverter = hardwareFormat == processingFormat
            ? nil
            : AVAudioConverter(from: hardwareFormat, to: processingFormat)
        inputConverter?.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        inputConverter?.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        if hardwareFormat != processingFormat, inputConverter == nil {
            retryOrFailStart(
                message: "Could not convert the selected microphone to 48 kHz mono audio.",
                generation: generation,
                attempt: attempt
            )
            return
        }

        // Install tap with 480-sample buffer (= 1 RNNoise frame = 10ms)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 480,
            format: hardwareFormat
        ) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer)
        }
        isTapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isCapturing = true
        } catch {
            retryOrFailStart(
                message: "Failed to start audio engine: \(error.localizedDescription)",
                generation: generation,
                attempt: attempt
            )
            return
        }

        // Notify RNNoise processor
        noiseProcessor.start(strength: publisher.snapshot.strength)
        if publisher.snapshot.phase == "error" {
            stopAudioCapture()
        }
    }

    private func stopAudioCapture() {
        audioEngine.stop()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.reset()
        inputConverter = nil
        convertedBuffer = nil
        isCapturing = false
    }

    private func retryOrFailStart(message: String, generation: Int, attempt: Int) {
        stopAudioCapture()
        guard generation == captureGeneration else { return }

        if attempt < maximumStartAttempts {
            publisher.snapshot.phase = "starting"
            publisher.snapshot.statusMessage = "Microphone is reconnecting…"
            publisher.snapshot.lastError = nil
            publisher.emitSnapshot()
            DispatchQueue.main.asyncAfter(deadline: .now() + startRetryDelay) { [weak self] in
                guard let self, self.captureGeneration == generation else { return }
                self.deviceManager.refreshAudioEnvironment(
                    reason: "Retrying audio startup",
                    forceSystemSelection: self.publisher.snapshot.followSystemInput
                )
                self.beginAudioCapture(generation: generation, attempt: attempt + 1)
            }
            return
        }

        fail(message: message)
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let processedBuffer: AVAudioPCMBuffer
        if let inputConverter {
            let ratio = processingFormat.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 1
            if convertedBuffer == nil || convertedBuffer!.frameCapacity < capacity {
                convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: processingFormat,
                    frameCapacity: capacity
                )
            }
            guard let convertedBuffer else { return }
            convertedBuffer.frameLength = 0

            let converterInput = ConverterInputBuffer(buffer: buffer)
            var conversionError: NSError?
            let status = inputConverter.convert(
                to: convertedBuffer,
                error: &conversionError
            ) { _, inputStatus in
                guard !converterInput.supplied else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                converterInput.supplied = true
                inputStatus.pointee = .haveData
                return converterInput.buffer
            }
            guard status != .error, conversionError == nil else { return }
            processedBuffer = convertedBuffer
        } else {
            processedBuffer = buffer
        }

        guard let channelData = processedBuffer.floatChannelData?[0] else { return }
        let frameCount = Int(processedBuffer.frameLength)

        noiseProcessor.feedSamples(
            channelData,
            count: frameCount,
            capturedAtNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }
}
