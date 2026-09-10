# Tasks

## Complete

- [x] Replace Electron UI with a native SwiftUI/AppKit application.
- [x] Capture and select physical microphones with AVAudioEngine/Core Audio.
- [x] Integrate RNNoise at 48 kHz with 480-sample frames.
- [x] Add native voice finishing and three voice profiles.
- [x] Build the ClearTone Virtual Microphone HAL driver and installer.
- [x] Add automatic default-input routing and restoration.
- [x] Add dashboard, compact menu-bar controls, and Tray Only mode.
- [x] Add Input → Voice Engine → Output routing visualization.
- [x] Add audio and process performance diagnostics.
- [x] Harden timestamp handling and start/stop transitions.

## Release work

- [ ] Supply a valid Developer ID Application certificate with its private key.
- [ ] Configure Installer Developer ID signing for the driver package.
- [ ] Add notarization and stapling.
- [ ] Run CoreAudio integration tests outside the restricted sandbox.
- [ ] Validate arm64 and x86_64 release artifacts on physical Macs.
