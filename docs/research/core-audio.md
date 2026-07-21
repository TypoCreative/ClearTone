# Core Audio Capture Research

## Overview

Core Audio is Apple's low-level audio framework for macOS/iOS. For real-time microphone capture with minimal latency, we need to bypass high-level APIs (AVAudioEngine, AVCaptureSession for audio-only) and work directly with AudioUnit and the Hardware Abstraction Layer (HAL).

## Architecture Layers

```
┌──────────────────────────────┐
│   App (Swift)                │
├──────────────────────────────┤
│   AVAudioEngine (high-level) │  ← Good for playback, NOT for low-latency capture
├──────────────────────────────┤
│   AudioUnit (mid-level)      │  ← RECOMMENDED: control over buffer sizes, callbacks
├──────────────────────────────┤
│   HAL / IO Kit (low-level)   │  ← Direct hardware access (complex)
└──────────────────────────────┘
```

## Approach: AudioUnit with VoiceProcessingIO

**Recommended approach**: Use `kAudioUnitSubType_VoiceProcessingIO` for mic capture with built-in echo cancellation, then tap the output for custom processing.

### Alternative: RemoteIO / HALOutput

For pure capture (no playback), use `kAudioUnitSubType_HALOutput`:
- Enable input, disable output
- Set up a render callback on the input scope
- Get Float32 buffers in real-time

### Step-by-step Swift Setup

```swift
import AudioToolbox
import AVFoundation

final class AudioCaptureController {
    private var audioUnit: AudioComponentInstance?

    func setup(desiredSampleRate: Float64 = 48000) throws {
        // 1. Describe the audio component
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        // 2. Find and instantiate
        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw AudioError.componentNotFound
        }
        AudioComponentInstanceNew(component, &audioUnit)

        guard let unit = audioUnit else { throw AudioError.instantiationFailed }

        // 3. Enable input, disable output
        var enableIO: UInt32 = 1
        AudioUnitSetProperty(unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,  // input bus
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size))

        enableIO = 0
        AudioUnitSetProperty(unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,  // output bus
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size))

        // 4. Set stream format (Float32, mono, 48kHz)
        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: desiredSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        AudioUnitSetProperty(unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,  // output from input bus → our callback
            1,  // input bus
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        // 5. Set render callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: renderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        AudioUnitSetProperty(unit,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            0,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        // 6. Allocate buffer for 10ms of audio
        var bufferSize: UInt32 = 512  // Can adjust for latency tradeoff
        AudioUnitSetProperty(unit,
            kAudioUnitProperty_MaximumFramesPerSlice,
            kAudioUnitScope_Global,
            0,
            &bufferSize,
            UInt32(MemoryLayout<UInt32>.size))

        // 7. Initialize and start
        AudioUnitInitialize(unit)
        AudioOutputUnitStart(unit)
    }
}

// Render callback - called on real-time audio thread
func renderCallback(
    _ inRefCon: UnsafeMutableRawPointer,
    _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
    _ inBusNumber: UInt32,
    _ inNumberFrames: UInt32,
    _ ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let capture = Unmanaged<AudioCaptureController>
        .fromOpaque(inRefCon)
        .takeUnretainedValue()

    guard let unit = capture.audioUnit else { return -1 }

    // Prepare buffer list
    var bufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: inNumberFrames * 4,
            mData: nil
        )
    )

    // Render audio
    let status = AudioUnitRender(unit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList)
    guard status == noErr else { return status }

    // Access float samples
    let floatPtr = bufferList.mBuffers.mData?.bindMemory(to: Float.self, capacity: Int(inNumberFrames))
    if let samples = floatPtr {
        let buffer = UnsafeBufferPointer(start: samples, count: Int(inNumberFrames))
        // ⚠️ DO NOT do heavy work here — push to a ring buffer / dispatch async
        capture.enqueueAudio(Array(buffer))
    }

    return noErr
}
```

## Critical Rules for Render Callback

1. **NO ALLOCATION**: No `malloc`, no Swift ARC-heavy ops, no object creation
2. **NO LOCKS**: No semaphores, no mutexes, no dispatch_sync
3. **NO I/O**: No file reads, no logging in production
4. **FAST PATH**: Copy to ring buffer, signal a condition variable, return
5. **Apple states**: Calling Swift methods inside AudioUnit callbacks is [strongly discouraged](https://stackoverflow.com/questions/59055774)

## Buffer Management Pattern

```
AudioUnit callback (real-time thread)
    │
    ├─> Ring Buffer (lock-free, single-producer single-consumer)
    │
    └─> Processing thread (dispatch queue)
            │
            ├─> Accumulate 480 samples (RNNoise frame)
            ├─> Feed into RNNoise
            └─> Compute metrics (RMS, noise reduction %)
```

## Permission Requirements

```xml
<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>ClearTone needs microphone access to apply noise cancellation.</string>
```

Check permission in Swift:
```swift
switch AVCaptureDevice.authorizationStatus(for: .audio) {
case .authorized: /* start capture */
case .notDetermined: /* request */
case .denied, .restricted: /* show error */
}
```

## Sample Rate Considerations

RNNoise requires exactly **48kHz**. If the microphone hardware provides a different rate:
- Use `AudioConverterRef` to resample
- Or configure the AudioUnit to request 48kHz (usually supported by macOS)
- Built-in Mac mics typically support 48kHz natively

## Latency Budget

| Component | Typical Latency |
|-----------|----------------|
| IO Buffer (256 samples @ 48kHz) | ~5.3ms |
| RNNoise processing (1 frame = 480 samples) | ~10ms (input), ~0.2ms (compute) |
| Output buffer | ~5.3ms |
| **Total theoretical** | **~15-21ms** |

Target: <20ms for imperceptible real-time use.
