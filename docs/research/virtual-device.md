# Virtual Microphone Device

## Decision

ClearTone uses a Core Audio Audio Server Driver Plug-in (HAL), not AudioDriverKit.
Apple's AudioDriverKit documentation says virtual devices should use an Audio Server
Driver Plug-in and that AudioDriverKit supports physical audio devices.

## Implemented Design

- Device name: `ClearTone Virtual Microphone`
- Device UID: `com.typocreative.cleartone.virtual-microphone`
- Driver bundle ID: `com.typocreative.cleartone.virtual-microphone.driver`
- Universal binary: arm64 and x86_64
- Format: duplex 32-bit Float32 stereo LPCM at 44.1 or 48 kHz
- Transport: an absolute-frame-tagged ring buffer copies the output stream to input
- Install location: `/Library/Audio/Plug-Ins/HAL`

The Swift engine captures the selected physical microphone, processes 48 kHz audio
with RNNoise, and writes it to the virtual device output. The HAL plug-in exposes the
same samples through its input stream. ClearTone then selects the virtual device as
the macOS default input, so apps that follow the system microphone switch without
per-app setup.

## Installation UX

The toggle remains disabled until the driver is detected. **Install Driver** runs
the bundled `.pkg` from ClearTone; macOS requests administrator approval. The package restarts
`coreaudiod`, and ClearTone polls device discovery for up to three minutes. Some OS
versions may still require logout or restart.

## Build and Release

`npm run build:driver` builds the Xcode target, verifies a universal driver bundle,
and creates `apps/resources/driver/ClearToneVirtualMicrophone.pkg`.

Development output is ad-hoc signed. Release builds should provide:

- `CLEARTONE_DRIVER_SIGN_IDENTITY`: Developer ID Application certificate name
- `CLEARTONE_INSTALLER_SIGN_IDENTITY`: Developer ID Installer certificate name

The package and final app must be notarized for frictionless distribution outside
the Mac App Store.

## Source and License

The implementation is adapted from Apple's `Creating an Audio Server Driver Plug-in`
sample. Apple publishes that sample under the MIT license; the original license is
retained in `apps/macos/native/virtual-microphone-driver/LICENSE.txt`.

## References

- https://developer.apple.com/documentation/coreaudio/creating-an-audio-server-driver-plug-in
- https://developer.apple.com/documentation/audiodriverkit/creating-an-audio-device-driver
