# Product Direction

Build ClearTone as a two-platform, lightweight native voice-clarity product.

- Keep macOS on SwiftUI/AppKit, AVAudioEngine/Core Audio, RNNoise, native Swift DSP,
  and its existing HAL virtual microphone.
- Keep Windows on Win32, WASAPI, RNNoise, CMake, and one low-overhead process.
- Keep audio local and preserve the existing icon/logo.
- Organize all platform source under `apps/macos` and `apps/windows`.
- Treat the Windows portable artifact as intentionally unsigned and never imply
  that it includes a production virtual microphone.
- Ground documentation in implemented source and tested CI behavior, separating
  current capability from planned parity work.
