import Foundation

enum VoicePreset: String, Codable, CaseIterable {
    case natural
    case clear
    case broadcast
}

private struct VoiceEnhancementParameters {
    let highPassFrequency: Double
    let warmthGainDB: Double
    let presenceGainDB: Double
    let noiseSuppressionMultiplier: Double
    let targetRMS: Float
    let maximumAutomaticGain: Float
    let compressorThreshold: Float
    let compressorRatio: Float
    let limiterCeiling: Float
    let minimumDereverbGain: Float

    static func parameters(for preset: VoicePreset) -> Self {
        switch preset {
        case .natural:
            return Self(
                highPassFrequency: 70,
                warmthGainDB: 0.5,
                presenceGainDB: 1.5,
                noiseSuppressionMultiplier: 0.9,
                targetRMS: 0.10,
                maximumAutomaticGain: 2.0,
                compressorThreshold: 0.45,
                compressorRatio: 2.0,
                limiterCeiling: 0.95,
                minimumDereverbGain: 0.82
            )
        case .clear:
            return Self(
                highPassFrequency: 85,
                warmthGainDB: -0.5,
                presenceGainDB: 3.0,
                noiseSuppressionMultiplier: 1.0,
                targetRMS: 0.125,
                maximumAutomaticGain: 2.5,
                compressorThreshold: 0.38,
                compressorRatio: 2.5,
                limiterCeiling: 0.93,
                minimumDereverbGain: 0.72
            )
        case .broadcast:
            return Self(
                highPassFrequency: 95,
                warmthGainDB: 2.0,
                presenceGainDB: 2.5,
                noiseSuppressionMultiplier: 1.1,
                targetRMS: 0.158,
                maximumAutomaticGain: 3.0,
                compressorThreshold: 0.30,
                compressorRatio: 3.5,
                limiterCeiling: 0.90,
                minimumDereverbGain: 0.66
            )
        }
    }
}

private struct BiquadFilter {
    private var b0: Float = 1
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0
    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0

    mutating func configureHighPass(frequency: Double, sampleRate: Double, quality: Double = 0.707) {
        let omega = 2 * Double.pi * frequency / sampleRate
        let cosine = cos(omega)
        let alpha = sin(omega) / (2 * quality)
        let denominator = 1 + alpha
        b0 = Float((1 + cosine) / 2 / denominator)
        b1 = Float(-(1 + cosine) / denominator)
        b2 = b0
        a1 = Float(-2 * cosine / denominator)
        a2 = Float((1 - alpha) / denominator)
    }

    mutating func configurePeaking(
        frequency: Double,
        gainDB: Double,
        sampleRate: Double,
        quality: Double
    ) {
        let amplitude = pow(10, gainDB / 40)
        let omega = 2 * Double.pi * frequency / sampleRate
        let alpha = sin(omega) / (2 * quality)
        let cosine = cos(omega)
        let denominator = 1 + alpha / amplitude
        b0 = Float((1 + alpha * amplitude) / denominator)
        b1 = Float(-2 * cosine / denominator)
        b2 = Float((1 - alpha * amplitude) / denominator)
        a1 = b1
        a2 = Float((1 - alpha / amplitude) / denominator)
    }

    mutating func process(_ sample: Float) -> Float {
        let output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = sample
        y2 = y1
        y1 = output
        return output
    }

    mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}

/// Lightweight real-time voice finishing after RNNoise.
/// The processor is queue-confined by RNNoiseProcessor.
final class VoiceEnhancementProcessor {
    private let sampleRate = 48_000.0
    private var preset: VoicePreset
    private var parameters: VoiceEnhancementParameters
    private var highPass = BiquadFilter()
    private var warmth = BiquadFilter()
    private var presence = BiquadFilter()
    private var automaticGain: Float = 1
    private var fastEnvelope: Float = 0
    private var lateEnvelope: Float = 0

    init(preset: VoicePreset = .clear) {
        self.preset = preset
        self.parameters = .parameters(for: preset)
        configureFilters()
    }

    func setPreset(_ preset: VoicePreset) {
        guard self.preset != preset else { return }
        self.preset = preset
        parameters = .parameters(for: preset)
        configureFilters()
        reset()
    }

    func reset() {
        highPass.reset()
        warmth.reset()
        presence.reset()
        automaticGain = 1
        fastEnvelope = 0
        lateEnvelope = 0
    }

    func effectiveNoiseReductionStrength(baseStrength: Double, speechProbability: Float) -> Double {
        let normalizedSpeech = speechProbability.isFinite
            ? max(0, min(1, speechProbability))
            : 0
        let speechProtection = 1.15 - 0.25 * Double(normalizedSpeech)
        return max(
            0,
            min(1, baseStrength * parameters.noiseSuppressionMultiplier * speechProtection)
        )
    }

    @discardableResult
    func process(_ samples: inout [Float], speechProbability: Float) -> Double {
        guard !samples.isEmpty else { return 0 }

        var sumSquares: Float = 0
        let speech = speechProbability.isFinite
            ? max(0, min(1, speechProbability))
            : 0

        for index in samples.indices {
            var sample = highPass.process(samples[index])

            // Dereverb-lite: attenuate low-level late energy while protecting active speech.
            let magnitude = abs(sample)
            fastEnvelope += 0.08 * (magnitude - fastEnvelope)
            lateEnvelope += 0.0025 * (magnitude - lateEnvelope)
            let tailAmount = lateEnvelope > 0.000_1
                ? max(0, min(1, 1 - fastEnvelope / (lateEnvelope * 0.8 + 0.000_1)))
                : 0
            let dereverbAmount = tailAmount * (1 - speech * 0.75)
            let dereverbGain = 1 - dereverbAmount * (1 - parameters.minimumDereverbGain)
            sample *= dereverbGain

            sample = warmth.process(sample)
            sample = presence.process(sample)
            samples[index] = sample
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(samples.count))
        let desiredGain = rms > 0.000_1
            ? min(parameters.maximumAutomaticGain, parameters.targetRMS / rms)
            : 1
        let smoothing: Float = desiredGain < automaticGain ? 0.18 : 0.025
        automaticGain += smoothing * (desiredGain - automaticGain)

        var outputSumSquares = 0.0
        for index in samples.indices {
            var sample = samples[index] * automaticGain
            let magnitude = abs(sample)
            if magnitude > parameters.compressorThreshold {
                let compressedMagnitude = parameters.compressorThreshold
                    + (magnitude - parameters.compressorThreshold) / parameters.compressorRatio
                sample = copysign(compressedMagnitude, sample)
            }
            let limitedSample = softLimit(sample, ceiling: parameters.limiterCeiling)
            samples[index] = limitedSample
            outputSumSquares += Double(limitedSample * limitedSample)
        }

        return sqrt(outputSumSquares / Double(samples.count))
    }

    private func configureFilters() {
        highPass.configureHighPass(
            frequency: parameters.highPassFrequency,
            sampleRate: sampleRate
        )
        warmth.configurePeaking(
            frequency: 180,
            gainDB: parameters.warmthGainDB,
            sampleRate: sampleRate,
            quality: 0.8
        )
        presence.configurePeaking(
            frequency: 3_200,
            gainDB: parameters.presenceGainDB,
            sampleRate: sampleRate,
            quality: 0.9
        )
    }

    private func softLimit(_ sample: Float, ceiling: Float) -> Float {
        let magnitude = abs(sample)
        let knee = ceiling * 0.82
        guard magnitude > knee else { return sample }
        let availableRange = ceiling - knee
        let normalized = (magnitude - knee) / max(availableRange, 0.000_1)
        let limited = knee + availableRange * tanh(normalized) / tanh(1)
        return copysign(min(ceiling, limited), sample)
    }
}
