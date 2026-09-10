# Roadmap

## Shipped in 0.2.1

- Native SwiftUI/AppKit dashboard and menu-bar interface.
- Core Audio input selection and automatic default-input following.
- RNNoise processing with Natural, Clear, and Broadcast voice profiles.
- ClearTone Virtual Microphone HAL driver and bundled installer.
- One-toggle routing with automatic processing and physical-input restoration.
- Tray Only mode, accessible controls, live metrics, and low-frequency performance
  monitoring.
- Crash protection for future frame timestamps and guarded engine transitions.
- Reusable buffers and reduced per-frame diagnostics overhead.

## Release readiness

- Validate the signed app and driver with a current Developer ID Application
  certificate.
- Add an Installer Developer ID identity for the `.pkg`.
- Add Apple notarization and stapling to the public release workflow.
- Run the full CoreAudio integration suite on an unrestricted macOS host.
- Measure processing on several Intel and Apple Silicon devices and publish a
  performance range.

## Later candidates

- Device-change stress testing across USB, Bluetooth, and aggregate devices.
- Optional diagnostic export with explicit user consent.
- Additional voice profiles only when listening tests show a clear benefit.
- Driver update and version health checks in the app.
