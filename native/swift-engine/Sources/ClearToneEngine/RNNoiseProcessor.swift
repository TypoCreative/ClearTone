import Foundation
import CRNNoise

// MARK: - Real RNNoise Processor with Metrics

final class RNNoiseProcessor: NoiseReductionProcessor, @unchecked Sendable {
    private let publisher: EngineStatePublisher
    private var state: OpaquePointer?
    private let frameSize: Int
    private var strength: Double = 0.65

    // Frame accumulation buffer
    private var accumulator: [Float] = []
    private let processingQueue = DispatchQueue(label: "cleartone.rnnoise.processing", qos: .userInteractive)
    private var cleanupGeneration = 0
    private let memoryCleanupDelay: TimeInterval = 10
    private var isActive = false

    // Metrics tracking
    private var framesProcessed: Int = 0
    private var lastMetricsEmitTime = Date()
    private let metricsEmitInterval: TimeInterval = 0.25

    init(publisher: EngineStatePublisher) {
        self.publisher = publisher
        self.frameSize = Int(rnnoise_get_frame_size()) // Always 480
        accumulator.reserveCapacity(frameSize)

        guard let st = rnnoise_create(nil) else {
            fatalError("Failed to initialize RNNoise state")
        }
        self.state = st
    }

    func start(strength: Double) {
        processingQueue.sync {
            cleanupGeneration += 1
            if state == nil {
                guard let newState = rnnoise_create(nil) else {
                    fatalError("Failed to reinitialize RNNoise state")
                }
                state = newState
            }
            self.strength = strength
            framesProcessed = 0
            accumulator.removeAll(keepingCapacity: true)
            lastMetricsEmitTime = .distantPast
            isActive = true
        }

        publisher.snapshot.phase = "processing"
        publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
        publisher.snapshot.lastError = nil
        publisher.snapshot.metrics = EngineMetrics(
            framesProcessed: 0,
            inputRms: 0,
            outputRms: 0,
            noiseReductionPercent: 0,
            estimatedLatencyMs: 0
        )
        publisher.emitSnapshot()
    }

    func stop() {
        let scheduledGeneration = processingQueue.sync {
            isActive = false
            accumulator.removeAll(keepingCapacity: true)
            cleanupGeneration += 1
            return cleanupGeneration
        }
        publisher.snapshot.metrics.inputRms = 0
        publisher.snapshot.metrics.outputRms = 0
        publisher.snapshot.metrics.noiseReductionPercent = 0

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

    /// Feed incoming audio samples into the processor.
    /// Called from the audio capture callback.
    /// Internally accumulates into 480-sample frames, processes through RNNoise, and emits metrics.
    func feedSamples(_ samples: [Float]) {
        processingQueue.async { [weak self] in
            guard let self, self.isActive else { return }
            self.accumulator.append(contentsOf: samples)

            // The accumulator is queue-confined, so audio callbacks cannot race
            // cleanup or RNNoise processing.
            while self.accumulator.count >= self.frameSize {
                let frame = Array(self.accumulator.prefix(self.frameSize))
                self.accumulator.removeFirst(self.frameSize)
                self.processSingleFrame(frame)
            }
        }
    }

    private func processSingleFrame(_ input: [Float]) {
        guard let st = state, input.count == frameSize else { return }

        var output = [Float](repeating: 0, count: frameSize)
        var inCopy = input

        // Compute input RMS before modification
        let inputRMS = computeRMS(input)

        // Run RNNoise
        rnnoise_process_frame(st, &output, &inCopy)

        // Apply strength blending (mix original and denoised based on strength)
        let currentStrength = strength
        let alpha = Float(currentStrength)
        for index in output.indices {
            output[index] = input[index] * (1 - alpha) + output[index] * alpha
        }
        let blendedRMS = computeRMS(output)

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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publisher.snapshot.metrics.framesProcessed = processedSamples
            self.publisher.snapshot.metrics.inputRms = inputRMS
            self.publisher.snapshot.metrics.outputRms = blendedRMS
            self.publisher.snapshot.metrics.noiseReductionPercent = reduction
            self.publisher.snapshot.metrics.estimatedLatencyMs = max(8, 16 - currentStrength * 5)
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
