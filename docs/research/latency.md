# Latency Research

## Overview

Real-time noise cancellation requires low end-to-end latency — ideally **<20ms** to avoid perceptible delay. This document analyzes the latency budget and optimization strategies for ClearTone.

## Latency Budget Breakdown

```
Total budget target: <20ms

Capture (IO buffer)        ████████░░  5.3ms  (256 samples @ 48kHz)
Resampling (if needed)     █░░░░░░░░░  0.5ms  (hardware typically 48kHz natively)
Ring buffer transfer       █░░░░░░░░░  0.1ms  (lock-free SPSC)
Frame accumulation         ██████████  10ms   (480 samples = 1 RNNoise frame)
RNNoise inference          █░░░░░░░░░  0.3ms  (M1/M2 native)
RMS/metric computation     █░░░░░░░░░  0.1ms
IPC serialization → emit   █░░░░░░░░░  0.2ms
────────────────────────────────────────────
TOTAL (theoretical)                   ~16.5ms
```

## Key Latency Factors

### 1. IO Buffer Size

| Buffer Size | Latency (48kHz) | CPU Overhead | Notes |
|-------------|-----------------|--------------|-------|
| 64 samples  | 1.3ms          | High (15+ callbacks per 10ms frame) | Requires aggressive optimization |
| 128 samples | 2.7ms          | Medium-High | Good balance |
| **256 samples** | **5.3ms**    | **Medium** | **Recommended for V1** |
| 512 samples | 10.7ms         | Low | Noticeable delay |

### 2. RNNoise Frame Size

RNNoise processes exactly **480 samples at 48kHz = 10ms**. This is a fixed requirement of the model architecture. You MUST accumulate 10ms of audio before processing.

### 3. VoiceProcessingIO

`kAudioUnitSubType_VoiceProcessingIO` adds echo cancellation but **increases latency** by 20-50ms due to its internal processing. **Avoid for V1** — use `kAudioUnitSubType_HALOutput` for pure capture.

## Optimization Strategies

### Ring Buffer (Lock-Free SPSC)

```swift
// Single-producer (audio callback) → single-consumer (processing queue)
final class LockFreeRingBuffer {
    private var buffer: [Float]
    private var readIndex: AtomicInt = 0
    private var writeIndex: AtomicInt = 0

    func write(_ samples: [Float]) { /* atomic swap */ }
    func read(_ count: Int) -> [Float]? { /* atomic swap */ }
}
```

### Audio Thread Priority

```swift
// Set real-time thread priority for audio processing
let audioQueue = DispatchQueue(
    label: "audio.processing",
    qos: .userInteractive,  // Highest priority
    attributes: [],
    autoreleaseFrequency: .workItem,
    target: nil
)

// On the audio thread itself (render callback):
// Thread priority is automatically set to real-time by Core Audio
// Do NOT change it or add locks
```

### Pre-allocation

```swift
// Pre-allocate all buffers to avoid malloc in hot path
private var inputFrame: [Float] = Array(repeating: 0, count: 480)
private var outputFrame: [Float] = Array(repeating: 0, count: 480)
private var accumulator: [Float] = []
accumulator.reserveCapacity(480)
```

### Batch Metric Emission

Don't emit IPC metrics on every frame (10ms). Batch every 100-200ms for efficiency:

```swift
private var metricsTickCounter = 0
private let metricsEmitInterval = 15  // ~150ms at 10ms frames

func processFrame(_ samples: [Float]) {
    metricsTickCounter += 1
    if metricsTickCounter >= metricsEmitInterval {
        emitMetrics()  // JSON serialization + IPC emit
        metricsTickCounter = 0
    }
}
```

## Benchmarking Approach

```swift
// Measure end-to-end latency
// Method: Play a test tone, capture it, measure time delta

// 1. Pass a known signal through the pipeline
// 2. Timestamp at capture (mach_absolute_time)
// 3. Timestamp when metrics arrive at Electron
// 4. Subtract to get end-to-end latency

var captureTime: UInt64 = 0

func renderCallback(...) -> OSStatus {
    captureTime = mach_absolute_time()  // High-res timestamp
    // ... process ...
}

func emitMetrics() {
    let now = mach_absolute_time()
    let latencyNanos = now - captureTime
    let latencyMs = Double(latencyNanos) * timebase.numer / timebase.denom / 1_000_000
}
```

## Comparison: Industry Benchmarks

| Product | Reported Latency | Approach |
|---------|-----------------|----------|
| Krisp | 15-25ms | Custom DNN, Apple Silicon native |
| NVIDIA RTX Voice | 20-40ms | GPU-accelerated, Windows only |
| Discord Krisp | 20ms | Krisp SDK integration |
| OBS RNNoise | 10-20ms | Direct RNNoise in audio pipeline |
| **ClearTone target** | **<20ms** | **RNNoise + Core Audio** |

## macOS-Specific Tips

1. **Process Audio Tap (macOS 14.2+)**: New API for system-wide audio capture. Not needed for mic-only V1 but useful for virtual mic routing later.
2. **Audio Workgroups**: iOS/macOS 14+ feature for cooperative thread scheduling — not applicable to V1.
3. **Sample Rate**: macOS microphone hardware defaults to the format set by the first active client. Set 48kHz explicitly.
4. **Power Nap**: Disable App Nap during processing (`NSProcessInfo.processInfo.beginActivity`).

## V1 Recommendation

- Use 256-sample IO buffer (~5ms capture latency)
- Process on a dedicated `.userInteractive` queue
- Emit metrics every ~150ms (not every frame)
- Defer complex optimizations (NEON SIMD, real-time scheduler) to post-V1
