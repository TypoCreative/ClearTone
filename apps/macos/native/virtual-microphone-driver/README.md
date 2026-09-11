# ClearTone Virtual Microphone Driver

This macOS Audio Server Driver Plug-in publishes a duplex Core Audio device named
`ClearTone Virtual Microphone`. ClearTone writes cleaned audio to its output stream;
meeting and recording apps read the same samples from its input stream.

The implementation is based on Apple's `Creating an Audio Server Driver Plug-in`
sample and retains its MIT license in `LICENSE.txt`.

Build with:

```sh
scripts/build-driver.sh
```

The build creates a universal `.driver` bundle and the installer package at
`apps/macos/native/swift-engine/Resources/driver/ClearToneVirtualMicrophone.pkg`. The app
bundles this package and opens it when the user selects **Install Driver**.
Installation targets `/Library/Audio/Plug-Ins/HAL`, requires administrator
approval, and restarts Core Audio through the package's post-install script. If the
device does not appear immediately, log out or restart macOS.

The driver exposes a 48 kHz stereo Float32 duplex device. ClearTone writes cleaned
frames to the output side; meeting and recording apps consume them from the input
side. The app detects the driver by UID or name before enabling automatic routing.

Local builds use ad-hoc signing by default. Set
`CLEARTONE_DRIVER_SIGN_IDENTITY` to sign the driver and
`CLEARTONE_INSTALLER_SIGN_IDENTITY` to sign the installer package for distribution.
