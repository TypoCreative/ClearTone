# Electron IPC Performance for Real-Time Audio Metrics

## Overview

ClearTone uses stdin/stdout JSON lines for IPC between Electron (Node.js) and the Swift engine. This document analyzes performance characteristics and optimization strategies.

## Current Architecture

```
Swift Engine (child process)
    │
    │ stdout ──> JSON lines (each ~500 bytes)
    │
    ▼
Electron Main Process
    │
    │ IPC (contextBridge)
    │
    ▼
React Renderer
```

## Message Format

```json
{"type":"snapshot","snapshot":{"phase":"processing","metrics":{"framesProcessed":840,"inputRms":0.45,"outputRms":0.12,"noiseReductionPercent":73,"estimatedLatencyMs":14.5},"inputs":[...],"strength":0.65,"statusMessage":"Processing..."}}
```

Typical size: **300-600 bytes** per snapshot.

## Current Emission Rate

The simulated pipeline emits a snapshot every **700ms** (`tickProcessing` timer). For real processing, we should emit every **100-200ms** — giving ~5-10 snapshots/second.

## Performance Analysis

| Component | Overhead | Notes |
|-----------|----------|-------|
| JSON encoding | ~0.1ms | Swift `JSONEncoder` per snapshot |
| Pipe write | ~0.01ms | stdout buffer write (non-blocking if buffer available) |
| JSON decoding (Node.js) | ~0.05ms | `JSON.parse()` per line |
| IPC to renderer | ~0.1ms | Electron `webContents.send()` |
| React re-render | ~1-5ms | Virtual DOM diff + paint |

**Total per snapshot**: ~1.5-6ms. At 100ms intervals, this is negligible.

## Optimization Strategies

### 1. Batch Metrics (Already Recommended)
Only emit full snapshots every 100-200ms, not per frame (10ms). The current `tickProcessing` approach of 700ms is too infrequent for real-time feel.

### 2. Sparse Snapshots
Only include changed fields:
```json
{"type":"metrics","framesProcessed":840,"inputRms":0.45,"noiseReductionPercent":73}
```
Instead of the full `EngineSnapshot`. This requires a delta protocol.

### 3. Binary Protocol (Optional)
Switch from JSON to a compact binary format (e.g., MessagePack, flatbuffers) for 80%+ size reduction. **Not needed for V1** — JSON at 100ms intervals is fine.

### 4. Ring Buffer for Renderer
On the Electron renderer side, debounce rapid updates to avoid excessive React re-renders:
```tsx
// useEngineSnapshot hook
const [snapshot, setSnapshot] = useState(initialSnapshot);

useEffect(() => {
    let timeout: NodeJS.Timeout;
    const handler = (_event, data) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => setSnapshot(data), 16);  // ~60fps cap
    };
    window.ipcRenderer.on('engine-snapshot', handler);
    return () => window.ipcRenderer.off('engine-snapshot', handler);
}, []);
```

## V1 Recommendation

1. **Emit snapshots every 100-150ms** (from real pipeline, not simulated)
2. **Keep JSON format** — simple and fast enough
3. **Add debounce in renderer** to prevent excessive re-renders
4. **Defer binary protocol to V2** unless profiling shows JSON is a bottleneck

## References

- Electron IPC performance: https://www.electronjs.org/docs/latest/tutorial/ipc
- Node.js child_process stdin/stdout: https://nodejs.org/api/child_process.html
