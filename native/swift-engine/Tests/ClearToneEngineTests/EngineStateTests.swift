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
}
