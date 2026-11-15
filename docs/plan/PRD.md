# ClearTone Product Requirements

## Product

ClearTone 0.3.0 is a local native microphone utility for macOS 13+ and Windows 10
1903+/Windows 11. It reduces background noise with RNNoise and keeps audio on the
device. macOS build number is 4.

## Goals

- Provide low-latency 48 kHz, 10 ms local speech cleanup.
- Keep one native application process and near-zero idle audio work.
- Preserve the current macOS routing, accessibility, and performance behavior.
- Provide a buildable Windows app and reproducible signed Windows release ZIP.
- Describe virtual-device and signing limits accurately.

## macOS requirements

- Select/follow the physical input and request permission only when starting.
- Apply RNNoise plus Natural, Clear, or Broadcast finishing.
- Toggle the ClearTone HAL virtual microphone and restore physical input routing.
- Keep dashboard, menu bar, Tray Only, metrics, recovery, and accessibility flows.

## Windows requirements

- Capture the default communications microphone through WASAPI shared mode.
- Request 48 kHz mono float conversion and process every complete 480-sample frame.
- Blend cleaned/original audio using a 0–100% strength control.
- List active playback endpoints, render to the selected endpoint, and support
  virtual-cable routing without changing the system-wide playback default.
- Offer Start/Stop, textual status, tray lifecycle, high-DPI UI, and live metrics.
- Show compact CPU and private-memory use without adding a monitoring process.
- Build quality artifacts without credentials and release artifacts with a valid
  application code-signing certificate.

## Non-goals for 0.3.0

- A Windows WDK virtual microphone or automatic endpoint switching.
- Windows driver certificate/signing, guaranteed SmartScreen reputation, MSI/MSIX,
  or Microsoft Store distribution.
- Cloud processing, accounts, analytics, or synchronization.
- Claiming macOS and Windows voice-finishing parity before listening tests.

## Acceptance criteria

- macOS tests and app bundle build pass after all path moves.
- Windows CMake Release x64 build passes on GitHub Actions.
- Windows quality check confirms its generated executable is unsigned.
- Release workflows build macOS DMGs with a signed app and a signed Windows EXE
  inside the portable ZIP.
- Documentation contains no obsolete root `native/` or root `web/` build path.
