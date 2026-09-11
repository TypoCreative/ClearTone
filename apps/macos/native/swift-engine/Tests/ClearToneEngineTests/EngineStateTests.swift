import Foundation
import XCTest
@testable import ClearToneEngine

final class EngineStateTests: XCTestCase {
    func testInitialStateKeepsVirtualMicrophoneOff() {
        let publisher = EngineStatePublisher()

        XCTAssertFalse(publisher.snapshot.virtualMicrophone.enabled)
        XCTAssertFalse(publisher.snapshot.virtualMicrophone.available)
        XCTAssertEqual(publisher.snapshot.metrics.droppedFrames, 0)
        XCTAssertEqual(publisher.snapshot.metrics.outputQueueFrames, 0)
        XCTAssertEqual(publisher.snapshot.voicePreset, .clear)
    }

    func testVirtualMicrophoneReportsUnavailableWithoutDriver() {
        let output = VirtualMicrophoneOutput()
        let state = output.refreshState(enabled: true)

        XCTAssertTrue(state.enabled)
        if !state.available {
            XCTAssertTrue(state.statusMessage.contains("not installed"))
        }
    }

    func testRefreshDisablesVirtualMicrophoneWhenDriverDisappears() {
        let publisher = EngineStatePublisher()
        let output = VirtualMicrophoneOutput()
        let processor = RNNoiseProcessor(publisher: publisher, virtualOutput: output)

        publisher.snapshot.virtualMicrophone.enabled = true
        processor.refreshVirtualMicrophoneState()

        if !publisher.snapshot.virtualMicrophone.available {
            XCTAssertFalse(publisher.snapshot.virtualMicrophone.enabled)
        }
    }

    func testRNNoiseProcessesNormalizedAudioAndReportsMeasuredLatency() {
        let publisher = EngineStatePublisher()
        let output = VirtualMicrophoneOutput()
        let processor = RNNoiseProcessor(publisher: publisher, virtualOutput: output)
        processor.start(strength: 0.65)

        let samples = (0..<480).map { index in
            Float(sin(2 * Double.pi * 440 * Double(index) / 48_000) * 0.1)
        }
        processor.feedSamples(
            samples,
            capturedAtNanoseconds: DispatchTime.now().uptimeNanoseconds
        )

        let processed = expectation(description: "RNNoise metrics emitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertGreaterThanOrEqual(publisher.snapshot.metrics.framesProcessed, 480)
            XCTAssertTrue(publisher.snapshot.metrics.estimatedLatencyMs.isFinite)
            XCTAssertGreaterThanOrEqual(publisher.snapshot.metrics.estimatedLatencyMs, 0)
            processed.fulfill()
        }
        wait(for: [processed], timeout: 1)
        processor.stop()
    }

    func testRNNoiseClampsFutureFrameTimestampInsteadOfOverflowing() {
        let publisher = EngineStatePublisher()
        let output = VirtualMicrophoneOutput()
        let processor = RNNoiseProcessor(publisher: publisher, virtualOutput: output)
        processor.start(strength: 0.65)

        let samples = [Float](repeating: 0.05, count: 480)
        processor.feedSamples(
            samples,
            capturedAtNanoseconds: DispatchTime.now().uptimeNanoseconds + 50_000_000
        )

        let processed = expectation(description: "Future timestamp is clamped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertGreaterThanOrEqual(publisher.snapshot.metrics.framesProcessed, 480)
            XCTAssertEqual(publisher.snapshot.metrics.estimatedLatencyMs, 0)
            processed.fulfill()
        }
        wait(for: [processed], timeout: 1)
        processor.stop()
    }

    func testVoiceEnhancementRemovesDCAndPreventsClipping() {
        let processor = VoiceEnhancementProcessor(preset: .broadcast)
        var samples = [Float](repeating: 1.5, count: 480)

        for _ in 0..<20 {
            processor.process(&samples, speechProbability: 0.8)
            samples = [Float](repeating: 1.5, count: 480)
        }
        processor.process(&samples, speechProbability: 0.8)

        XCTAssertLessThanOrEqual(samples.map(abs).max() ?? 0, 0.901)
        XCTAssertLessThan(abs(samples.reduce(0, +) / Float(samples.count)), 0.1)
    }

    func testAdaptiveSuppressionProtectsActiveSpeech() {
        let processor = VoiceEnhancementProcessor(preset: .clear)
        let duringSilence = processor.effectiveNoiseReductionStrength(
            baseStrength: 0.65,
            speechProbability: 0
        )
        let duringSpeech = processor.effectiveNoiseReductionStrength(
            baseStrength: 0.65,
            speechProbability: 1
        )

        XCTAssertGreaterThan(duringSilence, duringSpeech)
    }

    func testVoiceEnhancementMeetsRealtimeFrameBudget() {
        let processor = VoiceEnhancementProcessor(preset: .clear)
        let frame = (0..<480).map { index in
            Float(sin(2 * Double.pi * 220 * Double(index) / 48_000) * 0.2)
        }
        let startedAt = Date()

        for _ in 0..<500 {
            var samples = frame
            processor.process(&samples, speechProbability: 0.75)
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.0)
    }
}
