# CoreML Noise Model Options

## Overview

CoreML is Apple's on-device machine learning framework that can leverage the Neural Engine, GPU, and CPU on Apple Silicon. For noise cancellation, a CoreML model would run natively with hardware acceleration.

## Advantages for ClearTone

1. **Neural Engine**: Dedicated AI hardware on M1+ chips — faster and more power-efficient than CPU
2. **Zero bridging**: Swift-native API, no C bridging headers needed
3. **Built-in optimization**: Automatic quantization, model compilation
4. **Background execution**: Can run on low-power cores

## Model Conversion Path

### From RNNoise → CoreML
Not directly possible (RNNoise is C, not a standard ML framework). Would require:
1. Extract RNNoise weights (from C arrays in `rnnoise_data.c`)
2. Reconstruct PyTorch/TensorFlow model matching the architecture
3. Convert to CoreML via coremltools

### From DeepFilterNet → CoreML
More feasible:
1. DeepFilterNet has PyTorch training code
2. Export to ONNX: `torch.onnx.export()`
3. Convert ONNX → CoreML: `coremltools.convert(onnx_model)`
4. Use in Swift: `MLModel.load(contentsOf:)`

```python
# Conversion script
import coremltools as ct
import onnx

onnx_model = onnx.load("deepfilternet.onnx")
coreml_model = ct.convert(onnx_model, 
    inputs=[ct.TensorType(name="input", shape=(1, 480))])
coreml_model.save("DeepFilterNet.mlmodel")
```

```swift
// Swift usage
import CoreML

let model = try await DeepFilterNet.load()
let input = try MLMultiArray(shape: [1, 480], dataType: .float32)
let prediction = try await model.prediction(input: input)
```

## Custom CoreML Model

Building a custom noise suppression model for CoreML:
- Train in PyTorch/TensorFlow
- Use a lightweight architecture (GRU, causal convolution)
- Target <2MB model size, <0.5ms inference per frame
- Convert via coremltools

## Considerations

| Factor | CoreML | RNNoise (C) |
|--------|--------|-------------|
| Integration effort | Medium (need model + conversion) | Low (C library, bridging header) |
| Performance on M1 | Excellent (Neural Engine) | Good (CPU only) |
| Power efficiency | Better (ANE is low-power) | Moderate |
| Model flexibility | High (swap .mlmodel easily) | Fixed (compile-time weights) |
| Debugging | Opaque (black box) | Transparent (C code) |

## Recommendation

**Defer to V2/V3**. RNNoise gives us a working solution fast. CoreML path is better long-term but requires:
1. Model training or conversion expertise
2. CoreML pipeline benchmarking
3. Buffer format bridging (CoreML uses MLMultiArray)

Once RNNoise integration is stable, add CoreML as `NoiseReductionProcessor` protocol conformance for an instant quality upgrade.
