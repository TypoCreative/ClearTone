import AVFoundation
import XCTest
@testable import ClearToneEngine

final class CaptureConversionTests: XCTestCase {
    func testMatchingFormatPassesThroughWithoutCopying() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        input.frameLength = 480
        let conversion = try CaptureConversion(inputFormat: format, outputFormat: format)
        XCTAssertTrue(conversion.convert(input) === input)
    }

    func testStereo44100InputConvertsToFinite48000MonoAudio() throws {
        let inputFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let outputFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4_410))
        input.frameLength = 4_410
        let channels = try XCTUnwrap(input.floatChannelData)
        for channel in 0..<2 {
            for index in 0..<4_410 {
                channels[channel][index] = Float(sin(2 * Double.pi * 220 * Double(index) / 44_100) * 0.1)
            }
        }
        let conversion = try CaptureConversion(inputFormat: inputFormat, outputFormat: outputFormat)
        let output = try XCTUnwrap(conversion.convert(input))
        XCTAssertEqual(output.format.sampleRate, 48_000)
        XCTAssertEqual(output.format.channelCount, 1)
        XCTAssertGreaterThan(output.frameLength, 0)
        let samples = try XCTUnwrap(output.floatChannelData?[0])
        XCTAssertTrue(UnsafeBufferPointer(start: samples, count: Int(output.frameLength)).allSatisfy { $0.isFinite })
    }
}
