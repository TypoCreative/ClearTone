import Foundation

// MARK: - Noise Reduction Processor Protocol

protocol NoiseReductionProcessor: AnyObject {
    func start(strength: Double)
    func stop()
    func setStrength(_ value: Double)
    func feedSamples(_ samples: [Float], capturedAtNanoseconds: UInt64)
    func setVirtualMicrophone(enabled: Bool) throws
    func refreshVirtualMicrophoneState()
}

// MARK: - Simulated Implementation

final class SimulatedNoiseReductionProcessor: NoiseReductionProcessor {
    private let publisher: EngineStatePublisher
    private var processingTimer: DispatchSourceTimer?
    private var strength: Double = 0.65

    init(publisher: EngineStatePublisher) {
        self.publisher = publisher
    }

    func start(strength: Double) {
        stopTimer()

        self.strength = strength

        publisher.snapshot.phase = "processing"
        publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
        publisher.snapshot.lastError = nil
        publisher.snapshot.metrics.framesProcessed = 0
        publisher.snapshot.metrics.inputRms = 0.12
        publisher.snapshot.metrics.outputRms = 0.1
        publisher.snapshot.metrics.noiseReductionPercent = strength * 100
        publisher.snapshot.metrics.estimatedLatencyMs = max(10, 18 - strength * 6)
        publisher.emitSnapshot()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(700))
        timer.setEventHandler { [weak self] in
            self?.tickProcessing()
        }
        timer.resume()
        processingTimer = timer
    }

    func stop() {
        stopTimer()
        publisher.snapshot.metrics.inputRms = 0
        publisher.snapshot.metrics.outputRms = 0
        publisher.snapshot.metrics.noiseReductionPercent = 0
    }

    func setStrength(_ value: Double) {
        strength = value
    }

    func feedSamples(_: [Float], capturedAtNanoseconds _: UInt64) {}

    func setVirtualMicrophone(enabled: Bool) throws {
        publisher.snapshot.virtualMicrophone.enabled = enabled
        publisher.snapshot.virtualMicrophone.statusMessage = enabled
            ? "Virtual microphone is unavailable in simulated mode"
            : "Virtual microphone is off"
    }

    func refreshVirtualMicrophoneState() {}

    // MARK: - Simulation Tick

    private func tickProcessing() {
        guard publisher.snapshot.phase == "processing" else { return }

        publisher.snapshot.metrics.framesProcessed += 840
        publisher.snapshot.metrics.inputRms = Double.random(in: 0.14...0.78)
        publisher.snapshot.metrics.outputRms = max(
            0,
            publisher.snapshot.metrics.inputRms - (Double.random(in: 0.02...0.18) * strength)
        )
        publisher.snapshot.metrics.noiseReductionPercent = max(
            0,
            min(100, (publisher.snapshot.metrics.inputRms - publisher.snapshot.metrics.outputRms) * 140)
        )
        publisher.snapshot.metrics.estimatedLatencyMs = max(10, 18 - strength * 6)
        publisher.snapshot.statusMessage = "Processing microphone input through the native engine"
        publisher.emitSnapshot()
    }

    private func stopTimer() {
        processingTimer?.cancel()
        processingTimer = nil
    }
}
