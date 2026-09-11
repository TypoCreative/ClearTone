# ClearTone — Native Voice Clarity for macOS and Windows

ClearTone is a lightweight, local microphone-enhancement app. It reduces
background noise and improves voice clarity without Electron, cloud processing,
accounts, or audio uploads.

Current version: **0.3.0** (macOS build 4)

## What it does

ClearTone captures microphone audio, converts it to 48 kHz mono, processes every
480-sample/10 ms frame with RNNoise, and sends the cleaned signal to a platform
audio output. Processing stays on the device.

- **macOS:** AVAudioEngine/Core Audio → native voice finishing → ClearTone Core
  Audio HAL virtual microphone.
- **Windows:** WASAPI default communications input → RNNoise → selected playback
  endpoint. Select an installed virtual audio cable as that endpoint when another
  app must receive the result as a microphone.

The Windows build is intentionally unsigned. It includes no application
certificate and no Windows kernel driver or Microsoft driver-signing setup.

## Features

| Capability | macOS | Windows |
| --- | --- | --- |
| Native single-process desktop UI | SwiftUI/AppKit | Win32 with Windows 11 Mica fallback |
| Local RNNoise processing | Yes, 10 ms frames | Yes, 10 ms frames |
| Voice finishing profiles | Natural, Clear, Broadcast | Planned after listening parity tests |
| Processing strength | 0–100% | 0–100% |
| Output selection | Automatic HAL route | Native playback-device picker |
| System tray/menu bar | Yes | Yes |
| Live input/output/voice metrics | Yes | Yes |
| Compact CPU/memory metrics | Yes | Yes |
| Built-in virtual microphone | Core Audio HAL plug-in | No; use an installed virtual cable |
| Automatic default-input switching | Yes | Not applicable without a Windows virtual driver |
| Account or cloud audio service | No | No |

## Architecture

```text
                              ClearTone 0.3.0
                                     │
                 ┌───────────────────┴───────────────────┐
                 │                                       │
       apps/macos/native                       apps/windows/native
                 │                                       │
        SwiftUI + AppKit                           Win32 + tray
                 │                                       │
   AVAudioEngine + Core Audio                    WASAPI shared mode
                 │                                       │
                 └──────────── RNNoise C ────────────────┘
                                 48 kHz mono
                 │                                       │
       Swift voice finishing                    strength blend
                 │                                       │
      Core Audio HAL virtual mic              playback/virtual cable
```

Both applications are native and keep the real-time pipeline in one process. The
Windows CMake target reuses the same vendored RNNoise source as macOS, avoiding a
second model copy and keeping suppression behavior aligned.

## Benefits

- Low idle overhead and no browser/helper-process tree.
- Private, offline audio processing.
- Predictable 10 ms RNNoise frame size on both platforms.
- Native tray/menu-bar lifecycle and platform accessibility controls.
- Separate platform build scripts and CI jobs, so a Windows change does not alter
  the macOS release artifact.

## Use cases

- Meetings with fan, keyboard, HVAC, or nearby speech noise.
- Streaming, gaming, and voice chat.
- Podcast, voice-over, demo, and screen-recording workflows.
- Teaching and support calls where clearer speech improves accessibility.

## Project structure

```text
ClearTone/
├── apps/
│   ├── macos/
│   │   ├── native/
│   │   │   ├── swift-engine/               # Swift app, DSP, RNNoise source
│   │   │   └── virtual-microphone-driver/  # Core Audio HAL driver
│   │   ├── web/                            # Archived landing prototype
│   │   └── build/                          # Existing source icon assets
│   └── windows/
│       ├── native/                         # Win32/WASAPI/CMake application
│       └── scripts/                        # PowerShell build and checks
├── scripts/                                # macOS build, driver, test, DMG
├── docs/                                   # Current plan and research history
└── .github/workflows/                      # macOS and Windows quality/releases
```

The existing ClearTone icon/logo is preserved. The Windows `.ico` is generated
from the same existing PNG and the original macOS `.icns` remains unchanged.

## Build macOS

Requirements: macOS 13+, Xcode 26+, and Swift 6.2.

```bash
swift run --package-path apps/macos/native/swift-engine --disable-sandbox ClearTone
scripts/check.sh
scripts/build-app.sh
scripts/build-driver.sh
scripts/package-mac.sh
```

Local app builds are ad-hoc signed. Public macOS releases still require the
appropriate Apple identities and notarization.

## Build Windows

Requirements: Windows 10 version 1903+ or Windows 11, Visual Studio 2022 with
Desktop development with C++, CMake, and a Windows SDK.

```powershell
./apps/windows/scripts/check.ps1
./apps/windows/scripts/package.ps1
```

Output: `dist/windows/ClearTone/ClearTone.exe`.

The GitHub Windows workflow produces
`ClearTone-0.3.0-windows-x64-unsigned.zip`. Because signing is intentionally
disabled, Windows SmartScreen may warn before launch. The release never claims to
contain a signed app or signed virtual-microphone driver.

## Distribution status

- macOS DMG workflow: arm64 and x64, with Developer ID required for published
  releases under the existing policy.
- Windows ZIP workflow: x64 portable artifact, intentionally unsigned.
- Windows virtual microphone: not bundled. A production first-party endpoint
  remains a separate WDK and Microsoft-signing project.

## License

MIT
