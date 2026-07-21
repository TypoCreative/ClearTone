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

    // Metrics tracking
    private var framesProcessed: Int = 0
    private var lastMetricsEmitTime = Date()
    private let metricsEmitInterval: TimeInterval = 0.15 // 150ms

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
        self.strength = strength
        framesProcessed = 0
        accumulator.removeAll(keepingCapacity: true)

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
        accumulator.removeAll(keepingCapacity: true)
        publisher.snapshot.metrics.inputRms = 0
        publisher.snapshot.metrics.outputRms = 0
        publisher.snapshot.metrics.noiseReductionPercent = 0
    }

    func setStrength(_ value: Double) {
        strength = max(0, min(1, value))
    }

    /// Feed incoming audio samples into the processor.
    /// Called from the audio capture callback.
    /// Internally accumulates into 480-sample frames, processes through RNNoise, and emits metrics.
    func feedSamples(_ samples: [Float]) {
        accumulator.append(contentsOf: samples)

        // Process complete frames
        while accumulator.count >= frameSize {
            let frame = Array(accumulator.prefix(frameSize))
            accumulator.removeFirst(frameSize)

            processingQueue.async { [weak self] in
                self?.processSingleFrame(frame)
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
        let blendedOutput = applyStrength(input: input, denoised: output, strength: strength)
        let blendedRMS = computeRMS(blendedOutput)

        // Compute noise reduction percentage
        let reduction = inputRMS > 0
            ? max(0, min(100, (1.0 - blendedRMS / inputRMS) * 100))
            : 0

        // Update metrics
        framesProcessed += 1

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publisher.snapshot.metrics.framesProcessed = self.framesProcessed * self.frameSize
            self.publisher.snapshot.metrics.inputRms = inputRMS
            self.publisher.snapshot.metrics.outputRms = blendedRMS
            self.publisher.snapshot.metrics.noiseReductionPercent = reduction
            self.publisher.snapshot.metrics.estimatedLatencyMs = max(8, 16 - self.strength * 5)

            // Throttle metric emission
            let now = Date()
            if now.timeIntervalSince(self.lastMetricsEmitTime) >= self.metricsEmitInterval {
                self.lastMetricsEmitTime = now
                self.publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
                self.publisher.emitSnapshot()
            }
        }
    }

    // MARK: - DSP Helpers

    private func computeRMS(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sumSquares = samples.reduce(0.0) { $0 + Double($1 * $1) }
        return sqrt(sumSquares / Double(samples.count))
    }

    /// Blend original and denoised audio based on strength parameter.
    /// strength=0 → original, strength=1 → fully denoised
    private func applyStrength(input: [Float], denoised: [Float], strength: Double) -> [Float] {
        let alpha = Float(strength)
        return zip(input, denoised).map { $0 * (1 - alpha) + $1 * alpha }
    }

    deinit {
        if let st = state {
            rnnoise_destroy(st)
            state = nil
        }
    }
}
