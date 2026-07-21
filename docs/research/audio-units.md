# Audio Units Processing Chain

## Overview

For ClearTone, the audio processing chain needs to:
1. Capture microphone input
2. Process through RNNoise (denoise)
3. Compute real-time metrics (RMS, noise reduction %)
4. Output denoised audio (initially to monitor, later to virtual mic)

## Architecture Options

### Option A: Standalone Capture + Separate Processing
```
Microphone → AudioUnit (capture) → Ring Buffer → RNNoise (dispatch queue) → Metrics
```
**Pros**: Simple, independent RNNoise processing.  
**Cons**: Extra latency from thread hop.

### Option B: AudioUnit with AUGraph
```
Microphone → AUConverter (if needed) → Custom AU (RNNoise) → Output AU
```
**Pros**: All in audio thread, lowest latency.  
**Cons**: Custom AudioUnit is complex to implement. AUGraph is deprecated (use AVAudioEngine or manual connections).

### Option C: AVAudioEngine with Manual Tap (Simplest for V1)
```
Microphone → AVAudioEngine input node → installTap → RNNoise → Metrics
```
**Pros**: Easy Swift API, auto format conversion, built-in permission.  
**Cons**: Slightly higher overhead, less control over buffer sizes.

### Recommended for V1: Option C then migrate to Option A if latency is an issue

## AVAudioEngine Implementation (V1 Starter)

```swift
import AVFoundation

final class AudioProcessingPipeline {
    private let engine = AVAudioEngine()
    private var rnnoise: RNNoiseProcessor?
    private let processingQueue = DispatchQueue(label: "audio.processing")

    func start(denoiseStrength: Float = 0.65) throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        )!

        // Install tap with 480-sample buffer (matches RNNoise frame size)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 480,
            format: desiredFormat
        ) { [weak self] buffer, when in
            self?.processAudioBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Accumulate into 480-sample frames for RNNoise
        processingQueue.async { [weak self] in
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            // Feed to RNNoise, compute metrics, emit to IPC
            self?.processSamples(samples)
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}
```

## Custom AudioUnit Rendering Chain

For production, a custom render callback gives more control:

```swift
// kAudioUnitSubType_VoiceProcessingIO
// Built-in features: echo cancellation, automatic gain control
// We hijack the render callback to insert RNNoise processing

func voiceIOCallback(
    _ inRefCon: UnsafeMutableRawPointer,
    _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
    _ inBusNumber: UInt32,
    _ inNumberFrames: UInt32,
    _ ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    // 1. Render input from mic
    // 2. If we have 480 samples accumulated:
    //    a. Pass through RNNoise
    //    b. Compute output RMS
    //    c. Update noise reduction percentage
    // 3. Copy denoised audio to ioData (for monitoring)
    return noErr
}
```

## RMS Computation

```swift
func computeRMS(_ samples: [Float]) -> Double {
    let sumSquares = samples.reduce(0.0) { $0 + Double($1 * $1) }
    return sqrt(sumSquares / Double(samples.count))
}

func computeNoiseReduction(inputRMS: Double, outputRMS: Double) -> Double {
    guard inputRMS > 0 else { return 0 }
    let reduction = (1.0 - outputRMS / inputRMS) * 100.0
    return max(0, min(100, reduction))
}
```

## Processing Chain Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Mic Capture  │ ──> │ Ring Buffer  │ ──> │ Frame Buffer │
│ (AudioUnit)  │     │ (lock-free)  │     │ (480 samples)│
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ IPC Metrics  │ <── │ RMS Calc     │ <── │ RNNoise      │
│ (JSON emit)  │     │              │     │ Process      │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Key Decisions

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Engine API | AVAudioEngine first | Fast to build, easy to debug |
| Buffer size | 480 frames (= 10ms) | Matches RNNoise exactly |
| Threading | Dedicated serial queue | Avoids blocking audio thread |
| Format | Float32, mono, 48kHz | Required by RNNoise |
| Conversion | AVAudioConverter | Built-in, handles resampling |
| Monitoring | Play through output (optional) | Helps user hear the effect |
