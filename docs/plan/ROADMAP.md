# Roadmap

## Implemented in 0.3.0

- Platform structure under `apps/macos` and `apps/windows`.
- Existing native macOS app, HAL driver, landing prototype, and icons relocated
  without replacing artwork.
- Native Windows Win32 tray app with WASAPI capture/render and RNNoise processing.
- Windows output picker, strength control, textual route, status, audio metrics,
  and low-frequency CPU/private-memory metrics.
- Windows quality and release workflows producing an unsigned portable x64 ZIP.
- Root command aliases and macOS scripts updated for the new paths.

## Validation before publishing 0.3.0

- Run the Windows workflow on GitHub-hosted Windows and inspect the produced ZIP.
- Perform microphone, output, unplug/replug, sleep/wake, and long-run tests on a
  physical Windows 10 and Windows 11 machine.
- Perform listening comparisons before porting macOS voice-finishing profiles.
- Run the full Core Audio suite on an unrestricted macOS host.

## Later candidates

- Windows device pickers and persisted device selection.
- Native Windows finishing profiles after quality validation.
- Optional first-party Windows virtual microphone only if WDK maintenance and
  Microsoft signing become explicit product requirements.
- Apple notarization/stapling and broader Intel/Apple Silicon measurements.
