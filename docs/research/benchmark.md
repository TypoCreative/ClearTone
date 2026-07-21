# Benchmarking Approach

## Overview

Benchmarking noise cancellation requires measuring multiple dimensions: latency, CPU usage, noise reduction quality, and perceptual quality.

## Metrics to Track

### 1. Processing Performance
| Metric | Unit | Target | How to Measure |
|--------|------|--------|----------------|
| Process time per frame | ms | <0.5ms | `mach_absolute_time` around `rnnoise_process_frame` |
| CPU usage | % | <5% per core | `host_processor_info` or `top -pid` |
| Memory usage | MB | <50MB total | `task_info` (resident_size) |
| Frame drops | count | 0 | Counter on ring buffer overflow |

### 2. Audio Quality
| Metric | Target | How to Measure |
|--------|--------|----------------|
| Input RMS | Valid range (0.01-1.0) | Computed from float samples |
| Output RMS | Lower than input RMS (less noise) | Computed after RNNoise |
| Noise reduction % | 30-90% depending on environment | (inputRMS - outputRMS) / inputRMS |
| SNR improvement | >6dB | Requires reference clean signal |

### 3. End-to-End Latency
```swift
// Loopback test: play test tone → capture → measure round-trip
func measureLatency() -> TimeInterval {
    let startTime = Date()
    // Start processing, emit test tone
    // Time until metric arrives at Electron renderer
    return Date().timeIntervalSince(startTime)
}
```

## Benchmarking Framework

### Swift-Side Measurement
```swift
struct ProcessingStats {
    var framesProcessed: UInt64 = 0
    var totalProcessingTimeNanos: UInt64 = 0
    var maxProcessingTimeNanos: UInt64 = 0
    var frameDrops: UInt64 = 0
    var lastFrameInputRMS: Float = 0
    var lastFrameOutputRMS: Float = 0

    var avgProcessingTimeMs: Double {
        guard framesProcessed > 0 else { return 0 }
        return Double(totalProcessingTimeNanos) / Double(framesProcessed) / 1_000_000
    }
}

// In the processing hot path:
func processFrame(_ samples: [Float]) {
    let start = mach_absolute_time()
    rnnoise_process_frame(state, &output, input)
    let end = mach_absolute_time()

    stats.totalProcessingTimeNanos += end - start
    stats.maxProcessingTimeNanos = max(stats.maxProcessingTimeNanos, end - start)
    stats.framesProcessed += 1
}
```

### Electron-Side Monitoring
The `MetricsGrid` component already displays:
- `framesProcessed` — throughput indicator
- `inputRms` / `outputRms` — signal levels
- `noiseReductionPercent` — effectiveness
- `estimatedLatencyMs` — perceived delay

These should transition from simulated data to real measurements.

## Test Environment

For reproducible benchmarks:
1. **Quiet room** (baseline): Minimal background noise
2. **Office noise** (moderate): Keyboard, HVAC, distant conversation
3. **Cafe noise** (challenging): Multiple voices, music, clatter
4. **Fan/white noise** (steady-state): Constant broadband noise

## Recommendation

1. Build real-time stats collection into `NoiseReductionProcessor`
2. Expose stats via the existing `EngineMetrics` struct
3. Run A/B comparisons: raw vs denoised recordings
4. Log benchmark data to file for analysis (optional debug toggle)
