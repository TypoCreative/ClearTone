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

Local Windows quality builds remain unsigned. Release builds support Authenticode
application signing, but include no Windows kernel driver or Microsoft
driver-signing setup.

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
├── scripts/                                # macOS build, driver, test, PKG
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
scripts/clear-quarantine.sh
```

Local app builds are ad-hoc signed. Public macOS releases require a Developer ID
Application identity; notarization remains a separate release step.

## Build Windows

Requirements: Windows 10 version 1903+ or Windows 11, Visual Studio 2022 with
Desktop development with C++, CMake, and a Windows SDK.

```powershell
./apps/windows/scripts/check.ps1
./apps/windows/scripts/package.ps1
```

Output: `dist/windows/ClearTone/ClearTone.exe`.

The GitHub Windows workflow produces
`ClearTone-0.3.0-windows-x64-signed.zip`. It signs and timestamps `ClearTone.exe`
with Authenticode, then verifies the signature before packaging. It does not sign
or install a virtual-microphone driver.

## One build command for both platforms

Run the same command on either supported operating system:

```bash
npm run build
```

On macOS, `npm run build` produces a **public distribution** PKG and requires:

- Developer ID Application identity with its private key (`_dev-id-apple.p12`
  or `CLEARTONE_APP_SIGN_IDENTITY` from your Keychain).
- Developer ID Installer identity with its private key (in the same P12,
  `_dev-id-installer.p12`, or `CLEARTONE_INSTALLER_SIGN_IDENTITY`).
- Notarization credentials: `CLEARTONE_NOTARY_PROFILE`, or an App Store Connect
  API key using `CLEARTONE_NOTARY_KEY_PATH`, `CLEARTONE_NOTARY_KEY_ID`, and
  `CLEARTONE_NOTARY_ISSUER_ID` for a team key.

Set `CLEARTONE_MAC_CERTIFICATE_PASSWORD` (or `MACOS_CERTIFICATE_PASSWORD` /
`CSC_KEY_PASSWORD`), or use the hidden interactive prompt. A separate Installer
P12 can use `CLEARTONE_INSTALLER_CERTIFICATE_PASSWORD`.

The build signs and notarizes the nested HAL driver installer before embedding
it, then signs, notarizes and staples the final app installer. It requires
Gatekeeper acceptance before reporting success. Apple Development and unsigned
installers are rejected for public builds.

Output: `dist/ClearTone-0.3.0-mac-<arch>.pkg`. Installation places ClearTone in
`/Applications` on the selected volume, verifies its bundle/signature and removes
only its quarantine attribute. See [distribution setup](docs/MACOS_DISTRIBUTION.md).

On Windows, provide `WINDOWS_CERTIFICATE_PFX` as a file path or base64 value and
optionally `WINDOWS_CERTIFICATE_PASSWORD`. The script uses `signtool.exe`, SHA-256,
and an RFC 3161 timestamp, then requires Authenticode status `Valid`. Passwords are
passed through the process environment and never written into artifacts or source.

GitHub Actions uses `MAC_CSC_LINK` / `MAC_CSC_KEY_PASSWORD` (with legacy
`CSC_LINK` / `CSC_KEY_PASSWORD` fallbacks) for the Developer ID Application P12.
`MAC_INSTALLER_CSC_LINK` / `MAC_INSTALLER_CSC_KEY_PASSWORD` optionally supply a
separate Developer ID Installer P12. `MAC_NOTARY_KEY_BASE64`, `MAC_NOTARY_KEY_ID`
and `MAC_NOTARY_ISSUER_ID` configure notarization. P12 and P8 contents are base64
repository secrets. Windows uses `WIN_CSC_LINK` / `WIN_CSC_KEY_PASSWORD`.

## Distribution status

- macOS PKG workflow: arm64 and x64. Public upload requires Developer ID signing,
  Apple notarization, a stapled ticket, and Gatekeeper acceptance.
- Existing v0.3.0 assets were published with Apple Development app signatures and
  unsigned PKGs. They are internal test artifacts and may be blocked by Gatekeeper.
  They are not retroactively notarized by this pipeline change.
- Windows ZIP workflow: signed and timestamped x64 portable artifact.
- Quality CI may still produce temporary unsigned binaries for compilation tests.
- Published Windows ZIPs are uploaded directly as GitHub Release assets, avoiding
  the separate GitHub Actions artifact-storage quota.
- Windows virtual microphone: not bundled. A production first-party endpoint
  remains a separate WDK and Microsoft-signing project.

## License

MIT

## Dependency and security checks

There are no npm or remote SwiftPM packages to upgrade. RNNoise is vendored C,
shared by macOS and Windows; upstream tracking and local patches are recorded in
`docs/SECURITY.md`. GitHub Actions dependencies are pinned to verified commit IDs.

`npm run check` runs Swift tests, RNNoise security regression checks with AddressSanitizer
and UndefinedBehaviorSanitizer, and a release app build. `npm audit --audit-level=low`
is enforced in quality CI. Windows CTest also runs the RNNoise regression checks.

For a local PKG without a signing certificate:

```bash
CLEARTONE_APP_SIGN_IDENTITY=- CLEARTONE_DRIVER_SIGN_IDENTITY=- npm run dist:mac
```

This produces an ad-hoc signed app inside an unsigned installer for local testing.
Quarantine cleanup after installation does not notarize the installer or bypass
Gatekeeper's initial check of a downloaded PKG. Public distribution requires Developer ID
Application, Developer ID Installer, and Apple notarization.
