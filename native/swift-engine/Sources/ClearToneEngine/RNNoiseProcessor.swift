import Foundation
import CRNNoise

// MARK: - Real RNNoise Processor with Metrics

final class RNNoiseProcessor: NoiseReductionProcessor, @unchecked Sendable {
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
    private let availableWorkSlots = DispatchSemaphore(value: 4)
    private var cleanupGeneration = 0
    private let memoryCleanupDelay: TimeInterval = 10
    private var isActive = false
    private var virtualMicrophoneEnabled = false

    // Metrics tracking
    private var framesProcessed: Int = 0
    private var lastMetricsEmitTime = Date()
    private let metricsEmitInterval: TimeInterval = 0.25

    init(publisher: EngineStatePublisher, virtualOutput: VirtualMicrophoneOutput) {
        self.publisher = publisher
        self.virtualOutput = virtualOutput
        self.frameSize = Int(rnnoise_get_frame_size()) // Always 480
        accumulator.reserveCapacity(frameSize)

        self.state = rnnoise_create(nil)
    }

    func start(strength: Double) {
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
            lastMetricsEmitTime = .distantPast
            isActive = true
            virtualMicrophoneEnabled = publisher.snapshot.virtualMicrophone.enabled
            return true
        }

        guard initialized else {
            publisher.snapshot.phase = "error"
            publisher.snapshot.lastError = "RNNoise could not allocate its processing state."
            publisher.snapshot.statusMessage = "Noise reduction is unavailable"
            publisher.emitSnapshot()
            return
        }

        publisher.snapshot.phase = "processing"
        publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
        publisher.snapshot.lastError = nil
        publisher.snapshot.metrics = EngineMetrics(
            framesProcessed: 0,
            inputRms: 0,
            outputRms: 0,
            noiseReductionPercent: 0,
            estimatedLatencyMs: 0,
            droppedFrames: 0,
            outputQueueFrames: 0
        )
        if publisher.snapshot.virtualMicrophone.enabled {
            do {
                try virtualOutput.start()
                publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: true)
            } catch {
                publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: true)
                publisher.snapshot.virtualMicrophone.statusMessage = error.localizedDescription
            }
        }
        publisher.emitSnapshot()
    }

    func stop() {
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

    func setVirtualMicrophone(enabled: Bool) throws {
        if enabled {
            try virtualOutput.start()
        } else {
            virtualOutput.stop()
        }
        processingQueue.sync {
            virtualMicrophoneEnabled = enabled
        }
        publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(enabled: enabled)
    }

    func refreshVirtualMicrophoneState() {
        publisher.snapshot.virtualMicrophone = virtualOutput.refreshState(
            enabled: publisher.snapshot.virtualMicrophone.enabled
        )
    }

    /// Feed incoming audio samples into the processor.
    /// Called from the audio capture callback.
    /// Internally accumulates into 480-sample frames, processes through RNNoise, and emits metrics.
    func feedSamples(_ samples: [Float], capturedAtNanoseconds: UInt64) {
        guard availableWorkSlots.wait(timeout: .now()) == .success else {
            DispatchQueue.main.async { [weak self] in
                self?.publisher.snapshot.metrics.droppedFrames += 1
            }
            return
        }

        processingQueue.async { [weak self] in
            guard let self else { return }
            defer { self.availableWorkSlots.signal() }
            guard self.isActive else { return }
            if self.accumulator.count == self.accumulatorReadIndex {
                self.accumulatorCaptureTime = capturedAtNanoseconds
            }
            self.accumulator.append(contentsOf: samples)

            // The accumulator is queue-confined, so audio callbacks cannot race
            // cleanup or RNNoise processing.
            while self.accumulator.count - self.accumulatorReadIndex >= self.frameSize {
                let endIndex = self.accumulatorReadIndex + self.frameSize
                let frame = Array(self.accumulator[self.accumulatorReadIndex..<endIndex])
                let frameCaptureTime = self.accumulatorCaptureTime ?? capturedAtNanoseconds
                self.accumulatorReadIndex = endIndex
                self.accumulatorCaptureTime = frameCaptureTime + 10_000_000
                self.processSingleFrame(frame, capturedAtNanoseconds: frameCaptureTime)
            }

            if self.accumulatorReadIndex >= self.frameSize * 4 {
                self.accumulator.removeFirst(self.accumulatorReadIndex)
                self.accumulatorReadIndex = 0
            }
        }
    }

    private func processSingleFrame(_ input: [Float], capturedAtNanoseconds: UInt64) {
        guard let st = state, input.count == frameSize else { return }
        var output = [Float](repeating: 0, count: frameSize)
        // RNNoise is trained for 16-bit PCM amplitude while AVAudioEngine supplies
        // normalized Float32 samples. Convert into the model domain, then back.
        var modelInput = input.map { $0 * 32_768 }

        // Compute input RMS before modification
        let inputRMS = computeRMS(input)

        // Run RNNoise
        rnnoise_process_frame(st, &output, &modelInput)

        // Apply strength blending (mix original and denoised based on strength)
        let currentStrength = strength
        let alpha = Float(currentStrength)
        for index in output.indices {
            let normalizedOutput = max(-1, min(1, output[index] / 32_768))
            output[index] = input[index] * (1 - alpha) + normalizedOutput * alpha
        }
        let blendedRMS = computeRMS(output)
        var queueDepth = 0
        var outputDropped = false
        if virtualMicrophoneEnabled {
            if let depth = virtualOutput.enqueue(output) {
                queueDepth = depth
            } else {
                outputDropped = true
            }
        }

        // Compute noise reduction percentage
        let reduction = inputRMS > 0
            ? max(0, min(100, (1.0 - blendedRMS / inputRMS) * 100))
            : 0

        // Update metrics
        framesProcessed += 1

        let now = Date()
        guard now.timeIntervalSince(lastMetricsEmitTime) >= metricsEmitInterval else {
            return
        }
        lastMetricsEmitTime = now

        let processedSamples = framesProcessed * frameSize
        let processingEnded = DispatchTime.now().uptimeNanoseconds
        let captureToProcessedMs = Double(processingEnded - capturedAtNanoseconds) / 1_000_000
        let queuedAudioMs = Double(queueDepth * frameSize) / 48_000 * 1_000
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publisher.snapshot.metrics.framesProcessed = processedSamples
            self.publisher.snapshot.metrics.inputRms = inputRMS
            self.publisher.snapshot.metrics.outputRms = blendedRMS
            self.publisher.snapshot.metrics.noiseReductionPercent = reduction
            self.publisher.snapshot.metrics.estimatedLatencyMs = captureToProcessedMs + queuedAudioMs
            self.publisher.snapshot.metrics.outputQueueFrames = queueDepth
            if outputDropped {
                self.publisher.snapshot.metrics.droppedFrames += 1
            }
            self.publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
            self.publisher.emitSnapshot()
        }
    }

    // MARK: - DSP Helpers

    private func computeRMS(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sumSquares = samples.reduce(0.0) { $0 + Double($1 * $1) }
        return sqrt(sumSquares / Double(samples.count))
    }

    deinit {
        if let st = state {
            rnnoise_destroy(st)
            state = nil
        }
    }
}
