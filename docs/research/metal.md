# Metal Shader Acceleration

## Overview

Metal is Apple's low-level GPU API. For audio processing, Metal can accelerate parallel operations like FFT, filter banks, and neural network inference.

## Use Cases for Noise Cancellation

### 1. Neural Network Inference via MPS (Metal Performance Shaders)
Apple's MPS framework provides GPU-accelerated neural network primitives:
- Convolution, LSTM, GRU layers
- Matrix multiplication
- Directly usable from Swift via `MetalPerformanceShaders`

### 2. FFT Acceleration
FFT is used in many noise suppression pipelines (STFT → mask → ISTFT):
```swift
import Accelerate  // vDSP provides FFT (CPU, SIMD-optimized)
// For GPU FFT:
import MetalPerformanceShaders
let fft = MPSFFT(device: metalDevice, ...)
```

### 3. Custom Metal Shaders
For operations that benefit from massive parallelism:
```metal
kernel void compute_rms(device const float *input [[buffer(0)]],
                        device float *output [[buffer(1)]],
                        uint id [[thread_position_in_grid]]) {
    // Parallel RMS computation across audio frames
}
```

## RNNoise + Metal: Not Straightforward

RNNoise is a C library with manual SIMD intrinsics (SSE, AVX). It cannot easily run on Metal because:
1. It's not a standard neural network (uses custom C DSP + NN mix)
2. The GRU inference is hand-optimized for CPU
3. No ONNX/PyTorch export available

**Conclusion**: Metal acceleration is NOT useful for RNNoise-based V1. It becomes relevant when switching to a CoreML or ONNX-based model.

## When to Use Metal

| Feature | Use Metal? | Notes |
|---------|-----------|-------|
| RNNoise inference | ❌ | C library, no GPU path |
| DeepFilterNet via CoreML | ✅ (auto) | CoreML handles GPU/ANE routing |
| Custom FFT/filter | ✅ | For future DSP pipelines |
| Metric computation (RMS) | ❌ | Too small to benefit from GPU |
| Audio resampling | ❌ | Use AudioConverter (built-in) |

## Recommendation

**Skip Metal for V1**. RNNoise runs on CPU efficiently enough. Metal becomes relevant when:
1. Switching to CoreML models (Metal is used automatically)
2. Building custom DSP pipeline with GPU-accelerated transforms
3. Post-V1: Adding spectrogram visualization or real-time analysis

For V1, focus on CPU-based processing with proper thread management.
