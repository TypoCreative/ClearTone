# RNNoise Research

## Overview

[RNNoise](https://github.com/xiph/rnnoise) (v0.2, released Apr 2024) is a noise suppression library from Xiph.Org / Mozilla based on a recurrent neural network (GRU-based). It combines classical DSP with deep learning for real-time full-band speech enhancement at 48kHz.

- **License**: BSD-3-Clause
- **Language**: C (69.7%), Python (24.1% for training)
- **Stars**: 5.7k, Forks: 1.1k
- **Paper**: [A Hybrid DSP/Deep Learning Approach to Real-Time Full-Band Speech Enhancement](https://arxiv.org/pdf/1709.08243.pdf) (Valin, 2018)

## Key Specifications

| Property | Value |
|----------|-------|
| Sample rate | 48 kHz (fixed) |
| Frame size | 480 samples (= 10ms) |
| Audio format | Float32, mono |
| Model | Embedded GRU (~1.8M weights) or loadable `.bin` |
| CPU optimization | AVX2 (x86), SSE4.1 fallback |
| API style | C, opaque pointers |

**Critical**: Frame size is fixed at 480 samples. You cannot change it without retraining the model (see [issue #93](https://github.com/xiph/rnnoise/issues/93)). Audio must be resampled to exactly 48kHz mono before feeding into RNNoise.

## C API

```c
#include "rnnoise.h"

// Get constants
int frame_size = rnnoise_get_frame_size();  // Always returns 480
int state_size = rnnoise_get_size();        // Bytes needed for DenoiseState

// Create/destroy state (uses built-in default model)
DenoiseState *st = rnnoise_create(NULL);
// ... use it ...
rnnoise_destroy(st);

// Or load a custom model
RNNModel *model = rnnoise_model_from_filename("weights_blob.bin");
DenoiseState *st = rnnoise_create(model);
rnnoise_destroy(st);
rnnoise_model_free(model);

// Process a frame (in-place or separate in/out)
float in[480];
float out[480];
rnnoise_process_frame(st, out, in);
// out now contains denoised audio
```

### Custom Model Loading
- `rnnoise_model_from_file(FILE*)` — file must stay open
- `rnnoise_model_from_buffer(void*, int)` — buffer must stay valid
- `rnnoise_model_from_filename(const char*)` — simplest, self-contained
- Model format: binary "machine endian" `.bin` file

## Swift Integration Strategy

### Option A: Bridging Header + Direct C (Recommended)
```
native/swift-engine/
├── Sources/ClearToneEngine/
│   ├── main.swift
│   ├── rnnoise/               ← RNNoise C source copied here
│   │   ├── include/rnnoise.h
│   │   ├── src/rnnoise.c
│   │   └── src/rnnoise_data.c
│   └── bridging-header.h      ← #include "rnnoise/rnnoise.h"
```

In `Package.swift`, add C settings:
```swift
.target(
    name: "ClearToneEngine",
    dependencies: [],
    path: "Sources/ClearToneEngine",
    cSettings: [
        .define("RNNOISE_BUILD"),
        .headerSearchPath("rnnoise/include"),
        .headerSearchPath("rnnoise/src"),
    ]
)
```

The bridging header makes all C functions available as Swift global functions.

### Option B: System-installed library
```bash
brew install rnnoise  # If available via Homebrew
# Then add linker flags for -lrnnoise
```

### Option C: Embedded C target (cleanest)
Add a separate C target in Package.swift that wraps RNNoise, then depend on it from Swift.

## Swift Wrapper Design

```swift
// NoiseReductionProcessor.swift
import Foundation

final class RNNoiseProcessor {
    private let state: OpaquePointer
    private let frameSize: Int

    init?(modelPath: String? = nil) {
        frameSize = Int(rnnoise_get_frame_size())  // 480
        
        if let path = modelPath {
            guard let model = rnnoise_model_from_filename(path) else { return nil }
            guard let st = rnnoise_create(model) else {
                rnnoise_model_free(model)
                return nil
            }
            state = st
        } else {
            guard let st = rnnoise_create(nil) else { return nil }
            state = st
        }
    }

    func processFrame(_ input: [Float], _ output: inout [Float]) {
        guard input.count >= frameSize, output.count >= frameSize else { return }
        rnnoise_process_frame(state, &output, input)
    }

    deinit {
        rnnoise_destroy(state)
    }
}
```

## Performance on Apple Silicon

RNNoise is a C library without Neural Engine or GPU acceleration. On Apple Silicon (M1+):
- Runs on CPU only (Rosetta 2 for x86 build, or compile natively for arm64)
- Native arm64 build recommended — compile with `-march=armv8-a` or let clang auto-detect
- Estimated processing time per 10ms frame: **0.1–0.3ms** on M1 (very fast, ~1–3% CPU)
- No SIMD optimizations for ARM NEON by default — SSE/AVX2 paths are x86-only
- For better ARM performance, consider adding NEON intrinsics or switching to CoreML

## Build Instructions

```bash
git clone https://github.com/xiph/rnnoise.git
cd rnnoise
./autogen.sh    # Downloads model weights
./configure
make
# Produces: .libs/librnnoise.a (static library)
```

## Alternatives Considered

| Model | Strengths | Weaknesses |
|-------|-----------|------------|
| **RNNoise** | Tiny, fast, C API, proven | Fixed 48kHz/480-frame, no ARM SIMD |
| **DeepFilterNet** | Better quality, configurable | Larger model, Python-first, no C API |
| **CoreML** | Apple Neural Engine, Metal | Needs model conversion, less proven for denoise |
| **RTX Voice/NVIDIA** | Very high quality | Proprietary, GPU-only, NVIDIA only |

## Why RNNoise First

As stated in DECISIONS.md ("RNNoise first"):
1. **SIMPLEST INTEGRATION**: Pure C library, no external deps beyond libm
2. **PROVEN**: Used in Mozilla products, OBS Studio, NoiseTorch, Discord
3. **TINY**: Model ~1.8MB, memory ~100KB per instance
4. **FAST**: <1ms per frame on modern CPUs
5. **SWITCHABLE**: The `NoiseReductionProcessor` protocol can later swap to DeepFilterNet/CoreML

## Integration Checklist

- [ ] Clone RNNoise source into native/swift-engine
- [ ] Create bridging header with `#include "rnnoise.h"`
- [ ] Update Package.swift with C settings
- [ ] Build RNNoise as static library (or compile sources directly)
- [ ] Implement `NoiseReductionProcessor` Swift wrapper
- [ ] Handle 48kHz resampling if mic captures at different rate
- [ ] Verify with real microphone input
