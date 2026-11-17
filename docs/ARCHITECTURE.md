# Native macOS architecture

The UI and audio engine run in one process. UI actions use `EngineCommand` enum
cases with required values; there is no JSON round-trip, stdin bridge or simulated
processor in the production target.

| Component | Responsibility |
| --- | --- |
| AppEntry / NativeApp | Application scenes, menu bar, presentation and views |
| AppModel | Observable UI state, user settings and action errors |
| EngineRuntime | Component construction and shutdown |
| EngineCommandHandler | Main-actor command validation and input-setting changes |
| EngineStatePublisher | Snapshot publication and lifecycle transitions |
| AudioDeviceManager / CoreAudioDevices | Input selection/listeners and shared Core Audio property access |
| AudioEngineController | Microphone permission, capture, startup retry and cancellation |
| CaptureConversion | Converter and scratch buffer owned by a single input tap |
| RNNoiseProcessor / VoiceEnhancementProcessor | Frame accumulation, inference and voice finishing |
| VirtualMicrophoneOutput | Output engine and bounded playback-buffer pool |
| PerformanceSampler | Process CPU and resident-memory measurements |

Control commands run on the main actor. Audio listeners and snapshot updates
return to the main queue. The DSP state and accumulator stay on the serial
processing queue; capture hands off copied samples through a bounded pool.
Output-buffer completion callbacks return buffers under a lock and use generation
numbers to ignore retired sessions. Snapshot values are Sendable, and DSP startup
receives a captured configuration rather than reading live UI state on its queue.
The low-level callback adapters retain explicit `@unchecked Sendable` boundaries;
they are not general-purpose concurrent mutable services.

Input changes share one stop/update/restart path. Capture setup throws into one
retry handler, while generation checks preserve startup cancellation. Engine
phases are enum cases shared by controls, status display and processing logic.

The refactor preserves the RNNoise model, frame size, sample rate, converter
quality and finishing algorithms. Regression checks cover native command
validation, cancellation state, zero-copy format passthrough, stereo 44.1 kHz to
mono 48 kHz conversion, and the existing DSP/state cases. Actual microphone
prompts, reconnection and long calls still need hardware validation.
