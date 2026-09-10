# Architecture

ClearTone 0.2.1 is a native macOS utility. The SwiftUI interface and audio engine
run in one application process; there is no Electron, Chromium, Node.js runtime,
renderer process, or subprocess JSON bridge.

```text
SwiftUI dashboard + MenuBarExtra
              │
              ▼
ClearToneAppModel + EngineRuntime
              │
              ▼
AudioDeviceManager + AVAudioEngine
              │
              ▼
RNNoise (48 kHz, 480 samples) → Swift voice enhancement
              │
              ▼
VirtualMicrophoneOutput buffer pool
              │
              ▼
ClearTone Core Audio HAL driver
              │
              ▼
Meeting, streaming, recording, and voice-chat apps
```

## Application layers

| Layer | Implementation | Responsibility |
| --- | --- | --- |
| Presentation | SwiftUI and AppKit | Dashboard, menu-bar popup, tray-only lifecycle, errors, settings, and accessibility. |
| State and commands | `ClearToneAppModel`, `EngineStatePublisher`, `IPCCommandHandler` | Keeps UI state synchronized and serializes start, stop, input, strength, profile, and routing commands. The handler name is retained internally; it is not inter-process IPC. |
| Capture | `AVAudioEngine` and Core Audio | Lists physical inputs, follows or selects an input, captures frames, and converts to 48 kHz mono when necessary. |
| Noise reduction | RNNoise C | Processes every 480-sample frame without reducing the audio processing rate. |
| Voice finishing | Native Swift DSP | Speech-aware suppression, high-pass filtering, dereverb-lite, EQ, automatic gain, compression, and limiting. |
| Virtual output | `VirtualMicrophoneOutput` | Reuses bounded buffers and writes processed audio to the HAL device. |
| Virtual device | Core Audio Audio Server Plug-in | Publishes ClearTone Virtual Microphone as an input available to other apps. |

## Runtime behavior

- Audio stays local and does not require an account or network connection.
- Enabling Virtual Microphone selects it as the macOS default input and starts
  processing if necessary.
- Disabling routing or quitting normally restores the previous physical default
  input when available.
- Missing-driver and startup errors are reported in the same native UI.
- Audio metrics update at 1 Hz; process CPU and memory update every 10 seconds.
- GPU is not used for RNNoise. The performance panel reports GPU as system-managed
  because macOS may composite the SwiftUI interface on the GPU.

## Distribution

Swift Package Manager builds the app. Xcode command-line tools build the universal
HAL driver. Local builds are ad-hoc signed by default. Developer ID signing,
installer-package signing, notarization, and stapling are separate distribution
steps.
