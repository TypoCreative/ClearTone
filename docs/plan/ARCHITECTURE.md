# Architecture

ClearTone 0.3.0 is a two-platform native product organized under `apps/macos`
and `apps/windows`. Both variants process audio locally in one application
process and share the vendored RNNoise C source and 48 kHz/480-sample frame model.

## Repository boundaries

| Area | Purpose |
| --- | --- |
| `apps/macos/native/swift-engine` | SwiftUI/AppKit app, AVAudioEngine capture, DSP, state, and tests. |
| `apps/macos/native/virtual-microphone-driver` | Core Audio HAL virtual microphone and package source. |
| `apps/macos/web` | Historical landing-page prototype; not shipped in the desktop app. |
| `apps/windows/native` | Win32 UI, tray lifecycle, WASAPI engine, CMake project, and resources. |
| `apps/windows/scripts` | PowerShell build and unsigned-artifact validation. |
| `scripts` | macOS app, driver, tests, and DMG automation. |

## macOS runtime

```text
SwiftUI/AppKit → AVAudioEngine/Core Audio → RNNoise → Swift voice finishing
                                                     ↓
                                  Core Audio HAL virtual microphone
```

The macOS app can select a physical input, apply Natural/Clear/Broadcast voice
profiles, publish metrics, toggle the bundled HAL device, switch the default input,
and restore the previous physical input.

## Windows runtime

```text
Win32/Mica UI + tray → WASAPI default communications capture
                              ↓
                      RNNoise strength blend
                              ↓
               WASAPI selected playback endpoint
```

The Windows audio thread opts into MMCSS `Audio`, requests shared-mode automatic
conversion to 48 kHz mono float, processes bounded 10 ms frames, and publishes
atomic metrics to the UI twice per second. It has no Electron/Chromium process and
performs no network requests. CPU and private-memory measurements are sampled by
the UI timer without adding a monitoring thread; GPU remains unused because the
small 10 ms RNNoise workload is CPU-efficient and does not benefit from transfer
overhead.

Windows does not bundle a kernel virtual-microphone driver. For call-app routing,
the playback endpoint must be an already-installed virtual audio cable. An unsigned
WDK driver would require Windows test mode and is not a normal end-user solution.

## Distribution

- macOS: SwiftPM/Xcode scripts produce app, driver package, and DMG; published
  releases retain the existing Developer ID policy.
- Windows: Visual Studio 2022/CMake produces a portable x64 ZIP. App and driver
  signing are intentionally absent, and no signing secrets are referenced.
