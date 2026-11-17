import AVFoundation

struct AudioCaptureError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) { errorDescription = message }
}

/// Each tap owns its conversion state, so retired taps cannot mutate a new session.
final class CaptureConversion: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let format: AVAudioFormat
    private var convertedBuffer: AVAudioPCMBuffer?

    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
        format = outputFormat
        if inputFormat == outputFormat {
            converter = nil
        } else {
            guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw AudioCaptureError("Could not convert the selected microphone to 48 kHz mono audio.")
            }
            converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
            converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
            self.converter = converter
        }
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 1
        if convertedBuffer == nil || convertedBuffer!.frameCapacity < capacity {
            convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)
        }
        guard let convertedBuffer else { return nil }
        convertedBuffer.frameLength = 0
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, inputStatus in
            guard !supplied else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status != .error && error == nil ? convertedBuffer : nil
    }
}
