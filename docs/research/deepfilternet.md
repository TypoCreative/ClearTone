# DeepFilterNet Research

## Overview

[DeepFilterNet](https://github.com/Rikorose/DeepFilterNet) is a deep learning-based noise suppression framework that outperforms RNNoise in speech quality benchmarks. It uses a complex-valued deep filtering architecture.

## Key Differences vs RNNoise

| Property | RNNoise | DeepFilterNet |
|----------|---------|---------------|
| Architecture | GRU (recurrent) | Deep filtering + ERB-scale encoding |
| Language | C | Python (training), Rust/ONNX (inference) |
| Model size | ~1.8MB | ~5-15MB (depending on variant) |
| Sample rate | 48kHz fixed | Configurable (16kHz, 48kHz) |
| Frame size | 480 fixed | Configurable |
| Quality (PESQ/DNSMOS) | Good | Better (state-of-the-art) |
| Inference speed | Very fast (C, CPU) | Fast (ONNX Runtime, can use CoreML) |
| ARM optimization | No NEON | Via ONNX Runtime |
| License | BSD-3-Clause | MIT |

## Integration Paths for Swift

### Option A: ONNX Runtime + CoreML
1. Export DeepFilterNet to ONNX
2. Convert ONNX → CoreML via `coremltools`
3. Run inference via CoreML on Apple Neural Engine
4. Requires: `onnxruntime`, `coremltools` Python scripts for conversion

### Option B: DF3 (DeepFilterNet 3) Rust → C FFI
DeepFilterNet 3 has a Rust implementation. Could create a C-compatible shared library:
```bash
cargo build --release --target aarch64-apple-darwin
# Produces: libdeepfilter.dylib
```
Then bridge via Swift C interop.

### Option C: ONNX Runtime C API directly
```swift
// Use onnxruntime C API
import onnxruntime  // Need to build C library
// Load DeepFilterNet ONNX model
// Run inference frame-by-frame
```

## Recommendation for ClearTone

**Defer to V2**. RNNoise is simpler to integrate and "good enough" for V1. DeepFilterNet can be a later upgrade path:
1. **V1**: RNNoise via direct C integration (simplest, proven)
2. **V2**: DeepFilterNet via CoreML for Neural Engine acceleration (better quality, Apple Silicon native)

The `NoiseReductionProcessor` protocol design should accommodate swapping implementations.

## Quality Benchmarks

| Metric | Noisy | RNNoise | DeepFilterNet2 | DeepFilterNet3 |
|--------|-------|---------|----------------|----------------|
| PESQ | ~1.5 | ~2.4 | ~2.8 | ~3.0 |
| STOI | ~0.85 | ~0.92 | ~0.94 | ~0.95 |
| DNSMOS | ~2.5 | ~3.2 | ~3.5 | ~3.7 |

(Approximate; varies by noise type and SNR)

## References

- GitHub: https://github.com/Rikorose/DeepFilterNet
- Paper: "DeepFilterNet: A Low Complexity Speech Enhancement Framework"
- DF3: https://github.com/Rikorose/DeepFilterNet/tree/main/DeepFilterNet3
