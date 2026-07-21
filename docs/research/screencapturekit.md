# ScreenCaptureKit Audio Capture

## Overview

[ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) (macOS 12.3+) provides APIs for capturing screen content and audio. It can capture system audio output — useful for scenarios where ClearTone might want to process system audio (not just mic).

## Relevance to ClearTone

### Primary Use: Not Needed for V1
ClearTone V1 focuses on **microphone input** only. ScreenCaptureKit is relevant for:
- Capturing system audio (e.g., denoise game audio before streaming)
- Capturing app-specific audio (e.g., denoise a VoIP app's output)

### Future Use Case (V2+)
When ClearTone adds system audio capture:
```swift
import ScreenCaptureKit

// Capture system audio
let filter = SCContentFilter(display: .main, excludingWindows: [])
let config = SCStreamConfiguration()
config.capturesAudio = true
config.sampleRate = 48000
config.channelCount = 1

let stream = SCStream(filter: filter, configuration: config, delegate: nil)
try await stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
```

## Key Considerations

| Factor | ScreenCaptureKit | Core Audio Mic Capture |
|--------|-----------------|----------------------|
| macOS version | 12.3+ | 10.0+ |
| Permission | Screen Recording (TCC) | Microphone |
| Audio source | System/app output | Hardware mic input |
| Latency | Higher (varies) | Lower (direct) |
| Privacy indicator | Orange dot (screen recording) | Orange dot (mic) |

## Recommendation

**Skip for V1**. ScreenCaptureKit is orthogonal to the core mic denoising use case. Revisit when adding:
- System audio denoising for streamers
- App-specific audio capture
- Combined mic + system audio pipelines
