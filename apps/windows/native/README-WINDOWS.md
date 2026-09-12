# ClearTone for Windows

This is the native Windows build of ClearTone. It captures the default
communications microphone, processes 10 ms frames locally with RNNoise, and sends
the cleaned signal to a selected playback endpoint using WASAPI.

For calls and recordings, choose the input side of an installed virtual audio
cable in ClearTone's Output picker, then choose that cable's paired microphone
endpoint in the destination app. ClearTone does not install a Windows kernel driver
in this distribution.

## Build

Open **Developer PowerShell for Visual Studio 2022**, then run:

```powershell
./apps/windows/scripts/build.ps1
./apps/windows/scripts/check.ps1
./apps/windows/scripts/package.ps1
```

The executable is written to `dist/windows/ClearTone/ClearTone.exe`. Windows 10
version 1903 or newer is required. Windows 11 provides the full Mica backdrop.

## Security and signing

Quality builds are intentionally unsigned. Release builds use Authenticode
application signing through `npm run build`; they still perform no Microsoft
driver signing and do not include or silently install a driver.
