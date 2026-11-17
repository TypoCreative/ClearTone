import XCTest
@testable import ClearToneEngine

final class EngineCommandTests: XCTestCase {
    func testInvalidStrengthPreservesCurrentSettingsAndPhase() async throws {
        try await MainActor.run {
            let fixture = CommandFixture()
            fixture.publisher.snapshot.phase = .idle
            let originalStrength = fixture.publisher.snapshot.strength
            for strength in [Double.nan, .infinity, -.infinity] {
                XCTAssertThrowsError(try fixture.handler.handle(.setStrength(strength)))
            }
            XCTAssertEqual(fixture.publisher.snapshot.strength, originalStrength)
            XCTAssertEqual(fixture.publisher.snapshot.phase, .idle)
        }
    }

    func testNativeSettingsCommandsClampStrengthAndApplyPreset() async throws {
        try await MainActor.run {
            let fixture = CommandFixture()
            try fixture.handler.handle(.setStrength(2))
            XCTAssertEqual(fixture.publisher.snapshot.strength, 1)
            try fixture.handler.handle(.setStrength(-1))
            XCTAssertEqual(fixture.publisher.snapshot.strength, 0)
            try fixture.handler.handle(.setVoicePreset(.natural))
            XCTAssertEqual(fixture.publisher.snapshot.voicePreset, .natural)
            XCTAssertNil(fixture.publisher.snapshot.lastError)
        }
    }

    func testStopCancelsStartingStateAndAllowsAnotherAction() async throws {
        try await MainActor.run {
            let fixture = CommandFixture()
            fixture.publisher.snapshot.phase = .starting
            try fixture.handler.handle(.stopProcessing)
            XCTAssertEqual(fixture.publisher.snapshot.phase, .idle)
            XCTAssertFalse(fixture.publisher.snapshot.phase.isProcessing)
            try fixture.handler.handle(.setVoicePreset(.broadcast))
            XCTAssertEqual(fixture.publisher.snapshot.voicePreset, .broadcast)
        }
    }
}

@MainActor
private struct CommandFixture {
    let publisher = EngineStatePublisher()
    let handler: EngineCommandHandler

    init() {
        let devices = AudioDeviceManager(publisher: publisher)
        let processor = RNNoiseProcessor(publisher: publisher, virtualOutput: VirtualMicrophoneOutput())
        let controller = AudioEngineController(publisher: publisher, deviceManager: devices, noiseProcessor: processor)
        handler = EngineCommandHandler(publisher: publisher, deviceManager: devices, controller: controller)
    }
}
