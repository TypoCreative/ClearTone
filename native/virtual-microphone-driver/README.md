# ClearTone Virtual Microphone Driver

This macOS Audio Server Driver Plug-in publishes a duplex Core Audio device named
`ClearTone Virtual Microphone`. ClearTone writes cleaned audio to its output stream;
meeting and recording apps read the same samples from its input stream.

The implementation is based on Apple's `Creating an Audio Server Driver Plug-in`
sample and retains its MIT license in `LICENSE.txt`.

Build with:

```sh
npm run build:driver
```

The build creates a universal `.driver` bundle and an installer package under
`apps/resources/driver`. Installation targets `/Library/Audio/Plug-Ins/HAL` and
requires administrator approval. A logout or restart may be necessary before the
device appears in Core Audio.
