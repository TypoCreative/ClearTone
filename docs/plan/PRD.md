# ClearTone Product Requirements

## Product

ClearTone is a native macOS microphone utility that reduces background noise,
improves speech clarity, and can expose the cleaned signal to other applications
through ClearTone Virtual Microphone.

Current version: **0.2.1 (build 3)**

Minimum system: **macOS 13**

## Goals

- Provide real-time, local voice cleanup with low latency.
- Let users configure the physical input, suppression strength, and voice profile
  in one place.
- Route cleaned audio to any macOS app with one explicit toggle.
- Keep idle resource use and process count substantially below the previous
  Electron architecture.
- Provide clear error recovery when microphone permission, input devices, or the
  virtual microphone driver are unavailable.

## Current user experience

The dashboard uses a two-column native glass layout:

1. **Voice Engine** starts and stops processing.
2. **Audio Routing** shows Input → Voice Engine → Output and controls Virtual
   Microphone.
3. **Audio Setup** selects the input, noise-reduction strength, and Natural, Clear,
   or Broadcast profile.
4. **System Health** shows audio metrics plus CPU, memory, GPU ownership, and
   process count.

The menu-bar popup exposes the same essential controls in compact form. Tray Only
hides the desktop window while keeping the menu-bar interface available. The tray
symbol is monochrome and sized to the standard macOS menu-bar content area.

## Functional requirements

- Request microphone permission only when processing is started.
- Follow the macOS default physical input or use a selected physical input.
- Process 48 kHz mono audio in 480-sample RNNoise frames.
- Keep processing quality unchanged when the metrics UI is idle.
- Persist input selection, strength, voice profile, Virtual Microphone state, and
  Tray Only preference locally.
- When Virtual Microphone is enabled, start processing automatically and select
  ClearTone as the macOS default input.
- Restore the previous physical default input when routing is disabled or the app
  terminates normally.
- Offer the bundled driver installer when the HAL device is missing.
- Prevent duplicate start/stop actions while the engine is transitioning.

## Non-goals

- Cloud audio processing, accounts, analytics, or synchronization.
- GPU or Metal execution for RNNoise; its small sequential 10 ms workload remains
  on CPU to avoid transfer and dispatch overhead.
- Automatic installation of the HAL driver without macOS administrator approval.
- Claiming Developer ID distribution or notarization for ad-hoc local builds.

## Acceptance criteria

- The app builds as a native arm64 or x86_64 macOS application.
- Start Processing produces live input/output metrics without crashing.
- Virtual Microphone is enabled only when the driver is detected.
- Tray Only leaves no desktop window and remains controllable from the menu bar.
- Idle CPU returns near zero after processing stops.
- VoiceOver identifies engine state, routing nodes, controls, metrics, and errors.
