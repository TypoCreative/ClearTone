import Foundation
import CRNNoise

// MARK: - Real RNNoise Processor with Metrics

private final class AudioWorkBuffer: @unchecked Sendable {
    var samples: [Float]
    var count = 0

    init(capacity: Int) {
        samples = [Float](repeating: 0, count: capacity)
    }

    func prepare(count: Int) {
        self.count = count
        if samples.count < count {
            samples = [Float](repeating: 0, count: count)
        }
    }
}

final class RNNoiseProcessor: @unchecked Sendable {
    private let publisher: EngineStatePublisher
    private let virtualOutput: VirtualMicrophoneOutput
    private var state: OpaquePointer?
    private let frameSize: Int
    private var strength: Double = 0.65

    // Frame accumulation buffer
    private var accumulator: [Float] = []
    private var accumulatorReadIndex = 0
    private var accumulatorCaptureTime: UInt64?
    private let processingQueue = DispatchQueue(label: "cleartone.rnnoise.processing", qos: .userInteractive)
    private let workBufferLock = NSLock()
    private var availableWorkBuffers: [AudioWorkBuffer]
    private var cleanupGeneration = 0
    // Main-thread counterpart prevents queued metrics from an older session.
    private var metricsGeneration = 0
    private let memoryCleanupDelay: TimeInterval = 2
    private var isActive = false
    private var virtualMicrophoneEnabled = false
    private let voiceEnhancement = VoiceEnhancementProcessor()
    private var frameBuffer: [Float]
    private var modelInputBuffer: [Float]
    private var outputBuffer: [Float]

    // Metrics tracking
    private var framesProcessed: Int = 0
    private var lastMetricsEmitNanoseconds: UInt64 = 0
    private let metricsEmitIntervalNanoseconds: UInt64 = 1_000_000_000

    init(publisher: EngineStatePublisher, virtualOutput: VirtualMicrophoneOutput) {
        let rnnoiseFrameSize = Int(rnnoise_get_frame_size())
        self.publisher = publisher
        self.virtualOutput = virtualOutput
        self.frameSize = rnnoiseFrameSize // Always 480
        self.frameBuffer = [Float](repeating: 0, count: rnnoiseFrameSize)
        self.modelInputBuffer = [Float](repeating: 0, count: rnnoiseFrameSize)
        self.outputBuffer = [Float](repeating: 0, count: rnnoiseFrameSize)
        self.availableWorkBuffers = [
            AudioWorkBuffer(capacity: rnnoiseFrameSize),
            AudioWorkBuffer(capacity: rnnoiseFrameSize)
        ]
        accumulator.reserveCapacity(rnnoiseFrameSize)
    }

    func start(strength: Double) {
        metricsGeneration += 1
        let configuration = publisher.snapshot
        let initialized = processingQueue.sync {
            cleanupGeneration += 1
            if state == nil {
                state = rnnoise_create(nil)
            }
            guard state != nil else { return false }
            self.strength = strength
            framesProcessed = 0
            accumulator.removeAll(keepingCapacity: true)
            accumulatorReadIndex = 0
            accumulatorCaptureTime = nil
            lastMetricsEmitNanoseconds = 0
            isActive = true
            virtualMicrophoneEnabled = configuration.virtualMicrophone.enabled
            voiceEnhancement.setPreset(configuration.voicePreset)
            voiceEnhancement.reset()
            return true
        }

        guard initialized else {
            publisher.transition(
                to: .error, message: "Noise reduction is unavailable",
                error: "RNNoise could not allocate its processing state."
            )
            return
        }

        publisher.snapshot.phase = .processing
        publisher.snapshot.statusMessage = EngineSnapshot.processingMessage
        publisher.snapshot.lastError = nil
        publisher.snapshot.metrics = EngineMetrics()
        if publisher.snapshot.virtualMicrophone.enabled {
            do {
                try virtualOutput.start()
                publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: true)
            } catch {
                processingQueue.sync {
                    virtualMicrophoneEnabled = false
                }
                publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: false)
                publisher.snapshot.virtualMicrophone.statusMessage = error.localizedDescription
            }
        }
        publisher.emitSnapshot()
    }

    func stop() {
        metricsGeneration += 1
        let scheduledGeneration = processingQueue.sync {
            isActive = false
            accumulator.removeAll(keepingCapacity: true)
            accumulatorReadIndex = 0
            accumulatorCaptureTime = nil
            cleanupGeneration += 1
            return cleanupGeneration
        }
        publisher.snapshot.metrics.inputRms = 0
        publisher.snapshot.metrics.outputRms = 0
        publisher.snapshot.metrics.noiseReductionPercent = 0
        publisher.snapshot.metrics.outputQueueFrames = 0
        virtualOutput.stop()

        processingQueue.asyncAfter(deadline: .now() + memoryCleanupDelay) { [weak self] in
            guard let self else { return }
            guard !self.isActive, self.cleanupGeneration == scheduledGeneration else { return }
            self.accumulator.removeAll(keepingCapacity: false)
            self.trimAvailableWorkBuffers()
            if let state = self.state {
                rnnoise_destroy(state)
                self.state = nil
            }
        }
    }

    func setStrength(_ value: Double) {
        let normalizedValue = max(0, min(1, value))
        processingQueue.async { [weak self] in
            self?.strength = normalizedValue
        }
    }

    func setVoicePreset(_ preset: VoicePreset) {
        processingQueue.async { [weak self] in
            self?.voiceEnhancement.setPreset(preset)
        }
    }

    func setVirtualMicrophone(enabled: Bool) throws {
        if enabled {
            try virtualOutput.start()
            processingQueue.sync { virtualMicrophoneEnabled = true }
        } else {
            // Drain in-flight enqueue calls before touching AVAudioPlayerNode.
            processingQueue.sync { virtualMicrophoneEnabled = false }
            virtualOutput.stop()
        }
        publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: enabled)
    }

    func refreshVirtualMicrophoneState() {
        var refreshedState = virtualOutput.refreshState(
            enabled: publisher.snapshot.virtualMicrophone.enabled
        )
        if refreshedState.enabled && !refreshedState.available {
            processingQueue.sync {
                virtualMicrophoneEnabled = false
            }
            virtualOutput.stop()
            refreshedState.enabled = false
        }
        publisher.snapshot.virtualMicrophone = refreshedState
    }

    /// Feed incoming audio samples into the processor.
    /// Called from the audio capture callback.
    /// Internally accumulates into 480-sample frames, processes through RNNoise, and emits metrics.
    func feedSamples(_ samples: [Float], capturedAtNanoseconds: UInt64) {
        samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            feedSamples(
                baseAddress,
                count: buffer.count,
                capturedAtNanoseconds: capturedAtNanoseconds
            )
        }
    }

    func feedSamples(
        _ source: UnsafePointer<Float>,
        count: Int,
        capturedAtNanoseconds: UInt64
    ) {
        guard count > 0, let workBuffer = acquireWorkBuffer(count: count) else {
            DispatchQueue.main.async { [weak self] in
                self?.publisher.snapshot.metrics.droppedFrames += 1
            }
            return
        }

        workBuffer.samples.withUnsafeMutableBufferPointer { destination in
            destination.baseAddress?.update(from: source, count: count)
        }

        processingQueue.async { [weak self] in
            guard let self else { return }
            defer { self.releaseWorkBuffer(workBuffer) }
            guard self.isActive else { return }
            let samples = workBuffer.samples

            // Most devices already deliver exactly one 10 ms frame. Avoid the
            // accumulator and an additional copy for this common hot path.
            if self.accumulator.isEmpty && workBuffer.count == self.frameSize {
                self.processSingleFrame(samples, capturedAtNanoseconds: capturedAtNanoseconds)
                return
            }

            if self.accumulator.count == self.accumulatorReadIndex {
                self.accumulatorCaptureTime = capturedAtNanoseconds
            }
            self.accumulator.append(contentsOf: samples.prefix(workBuffer.count))

            // The accumulator is queue-confined, so audio callbacks cannot race
            // cleanup or RNNoise processing.
            while self.accumulator.count - self.accumulatorReadIndex >= self.frameSize {
                let endIndex = self.accumulatorReadIndex + self.frameSize
                for index in 0..<self.frameSize {
                    self.frameBuffer[index] = self.accumulator[self.accumulatorReadIndex + index]
                }
                let frameCaptureTime = self.accumulatorCaptureTime ?? capturedAtNanoseconds
                self.accumulatorReadIndex = endIndex
                self.accumulatorCaptureTime = frameCaptureTime + 10_000_000
                self.processSingleFrame(self.frameBuffer, capturedAtNanoseconds: frameCaptureTime)
            }

            if self.accumulatorReadIndex == self.accumulator.count {
                self.accumulator.removeAll(keepingCapacity: true)
                self.accumulatorReadIndex = 0
                self.accumulatorCaptureTime = nil
            } else if self.accumulatorReadIndex >= self.frameSize * 4 {
                self.accumulator.removeFirst(self.accumulatorReadIndex)
                self.accumulatorReadIndex = 0
            }
        }
    }

    private func acquireWorkBuffer(count: Int) -> AudioWorkBuffer? {
        workBufferLock.lock()
        defer { workBufferLock.unlock() }
        guard let buffer = availableWorkBuffers.popLast() else { return nil }
        buffer.prepare(count: count)
        return buffer
    }

    private func releaseWorkBuffer(_ buffer: AudioWorkBuffer) {
        workBufferLock.lock()
        availableWorkBuffers.append(buffer)
        workBufferLock.unlock()
    }

    private func trimAvailableWorkBuffers() {
        workBufferLock.lock()
        for buffer in availableWorkBuffers {
            buffer.samples = [Float](repeating: 0, count: frameSize)
            buffer.count = 0
        }
        workBufferLock.unlock()
    }

    private func processSingleFrame(_ input: [Float], capturedAtNanoseconds: UInt64) {
        guard let st = state, input.count >= frameSize else { return }
        let measurementTime = DispatchTime.now().uptimeNanoseconds
        let shouldEmitMetrics = lastMetricsEmitNanoseconds == 0
            || (measurementTime >= lastMetricsEmitNanoseconds
                && measurementTime - lastMetricsEmitNanoseconds >= metricsEmitIntervalNanoseconds)

        // RNNoise is trained for 16-bit PCM amplitude while AVAudioEngine supplies
        // normalized Float32 samples. Convert into the model domain, then back.
        var inputSumSquares = 0.0
        for index in 0..<frameSize {
            let sample = input[index].isFinite ? max(-1, min(1, input[index])) : 0
            modelInputBuffer[index] = sample * 32_768
            if shouldEmitMetrics {
                inputSumSquares += Double(sample * sample)
            }
        }

        // Run RNNoise
        let speechProbability = rnnoise_process_frame(st, &outputBuffer, &modelInputBuffer)

        // Apply strength blending (mix original and denoised based on strength)
        let currentStrength = voiceEnhancement.effectiveNoiseReductionStrength(
            baseStrength: strength,
            speechProbability: speechProbability
        )
        let alpha = Float(currentStrength)
        var denoisedSumSquares = 0.0
        for index in 0..<frameSize {
            let normalizedOutput = max(-1, min(1, outputBuffer[index] / 32_768))
            let cleanInput = modelInputBuffer[index] / 32_768
            let blendedOutput = cleanInput * (1 - alpha) + normalizedOutput * alpha
            outputBuffer[index] = blendedOutput
            if shouldEmitMetrics {
                denoisedSumSquares += Double(blendedOutput * blendedOutput)
            }
        }
        let enhancedRMS = voiceEnhancement.process(
            &outputBuffer,
            speechProbability: speechProbability,
            measureOutputRMS: shouldEmitMetrics
        )
        var queueDepth = 0
        var outputDropped = false
        if virtualMicrophoneEnabled {
            if let depth = virtualOutput.enqueue(outputBuffer) {
                queueDepth = depth
            } else {
                outputDropped = true
            }
        }

        // Update metrics
        framesProcessed += 1

        if outputDropped {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.publisher.snapshot.phase == .processing else { return }
                self.publisher.snapshot.metrics.droppedFrames += 1
            }
        }
        guard shouldEmitMetrics else { return }
        lastMetricsEmitNanoseconds = measurementTime

        let inputRMS = sqrt(inputSumSquares / Double(frameSize))
        let denoisedRMS = sqrt(denoisedSumSquares / Double(frameSize))
        let reduction = inputRMS > 0
            ? max(0, min(100, (1.0 - denoisedRMS / inputRMS) * 100))
            : 0
        let processedSamples = framesProcessed * frameSize
        let processingEnded = DispatchTime.now().uptimeNanoseconds
        // A converted hardware buffer can contain more than one 10 ms frame.
        // The estimated timestamp for a later frame may briefly be ahead of
        // `DispatchTime.now()`. Unsigned subtraction traps in that case, so
        // clamp latency to zero until the monotonic clock catches up.
        let elapsedNanoseconds = processingEnded >= capturedAtNanoseconds
            ? processingEnded - capturedAtNanoseconds
            : 0
        let captureToProcessedMs = Double(elapsedNanoseconds) / 1_000_000
        let queuedAudioMs = Double(queueDepth * frameSize) / 48_000 * 1_000
        let generation = cleanupGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.metricsGeneration == generation,
                  self.publisher.snapshot.phase == .processing else { return }
            self.publisher.snapshot.metrics.framesProcessed = processedSamples
            self.publisher.snapshot.metrics.inputRms = inputRMS
            self.publisher.snapshot.metrics.outputRms = enhancedRMS
            self.publisher.snapshot.metrics.noiseReductionPercent = reduction
            self.publisher.snapshot.metrics.estimatedLatencyMs = captureToProcessedMs + queuedAudioMs
            self.publisher.snapshot.metrics.outputQueueFrames = queueDepth
            self.publisher.snapshot.statusMessage = EngineSnapshot.processingMessage
            self.publisher.emitSnapshot()
        }
    }

    deinit {
        if let st = state {
            rnnoise_destroy(st)
            state = nil
        }
    }
}
