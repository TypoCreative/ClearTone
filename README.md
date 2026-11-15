# ClearTone — Native Voice Clarity for macOS and Windows

ClearTone is a lightweight, local microphone-enhancement app. It reduces
background noise and improves voice clarity without Electron, cloud processing,
accounts, or audio uploads.

Current version: **0.3.1** (macOS build 5)

## How to install

Download the DMG from https://github.com/TypoCreative/ClearTone/releases/latest:
choose **arm64** for Apple silicon (M1/M2/M3/M4 or newer) or **x64** for Intel.
This build is **not notarized by Apple**, so macOS may require manual approval.
Only approve a ClearTone download you trust from this repository.

1. Open `ClearTone-0.3.1-mac-<arch>.dmg`.
2. Drag **ClearTone.app** to **Applications**.
3. Eject the DMG, then open **ClearTone** from Applications.
4. If macOS blocks it, use either method below.

### Option A — Privacy & Security

1. Try opening ClearTone once. On the warning, choose **Done**, not Move to Trash.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the ClearTone security notice and choose **Open Anyway**.
4. Authenticate if asked, then choose **Open**.

To open the settings pane from Terminal:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy"
```

If the DMG itself is blocked, use the same Open Anyway steps for that DMG first.
Apple's instructions: https://support.apple.com/en-us/102445

### Option B — Terminal quarantine cleanup

After copying ClearTone to Applications, run:

```bash
codesign --verify --deep --strict "/Applications/ClearTone.app"
sudo xattr -dr com.apple.quarantine "/Applications/ClearTone.app"
open "/Applications/ClearTone.app"
```

Run the cleanup only if signature verification succeeds. `sudo` asks for your Mac
login password; no characters appear while typing. These commands remove only the
quarantine attribute from ClearTone, including its bundled driver installer.
They do not disable Gatekeeper globally or notarize the app.

If you cannot open the DMG at all, remove quarantine from that exact download
first, then open it. Example for Apple silicon in the default Downloads folder:

```bash
xattr -d com.apple.quarantine "$HOME/Downloads/ClearTone-0.3.1-mac-arm64.dmg"
open "$HOME/Downloads/ClearTone-0.3.1-mac-arm64.dmg"
```

Use `mac-x64.dmg` for Intel and adjust the path if your download is elsewhere.
“No such xattr” means that file already has no quarantine attribute.

### Microphone and virtual driver

Allow microphone access when prompted. In ClearTone, choose **Install Driver**
if the virtual microphone is unavailable, and follow the driver installer prompts.
If the bundled driver installer is blocked, approve that specific installer in
Privacy & Security, or use Option B on the installed app and retry Install Driver.
Restart or log out if ClearTone asks, then select **ClearTone Virtual Microphone**
in your meeting or recording app.

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
                              ClearTone 0.3.1
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
scripts/clear-quarantine.sh
```

Local app builds are ad-hoc signed. Apple-trusted macOS distribution requires Developer ID signing
and notarization. Current DMG releases use the manual approval steps above.

## Build Windows

Requirements: Windows 10 version 1903+ or Windows 11, Visual Studio 2022 with
Desktop development with C++, CMake, and a Windows SDK.

```powershell
./apps/windows/scripts/check.ps1
./apps/windows/scripts/package.ps1
```

Output: `dist/windows/ClearTone/ClearTone.exe`.

The GitHub Windows workflow produces
`ClearTone-0.3.1-windows-x64-signed.zip`. It signs and timestamps `ClearTone.exe`
with Authenticode, then verifies the signature before packaging. It does not sign
or install a virtual-microphone driver.

## One build command for both platforms

Run the same command on either supported operating system:

```bash
npm run build
```

On macOS, `npm run build` produces a DMG using `_dev-id-apple.p12` or an
installed Keychain identity selected by `CLEARTONE_APP_SIGN_IDENTITY`. Set
`CLEARTONE_MAC_CERTIFICATE_PASSWORD` (or `MACOS_CERTIFICATE_PASSWORD` /
`CSC_KEY_PASSWORD`), or enter the P12 password at the hidden prompt.

Apple Development signing is supported for the current manual-install builds.
Output: `dist/ClearTone-0.3.1-mac-<arch>.dmg`, containing ClearTone.app, an
Applications shortcut and `HOW_TO_INSTALL.md`. There is no top-level PKG or
automatic quarantine cleanup. The virtual microphone driver retains its bundled
PKG, installed from the app's **Install Driver** action.

On Windows, provide `WINDOWS_CERTIFICATE_PFX` as a file path or base64 value and
optionally `WINDOWS_CERTIFICATE_PASSWORD`. The script uses `signtool.exe`, SHA-256,
and an RFC 3161 timestamp, then requires Authenticode status `Valid`. Passwords are
passed through the process environment and never written into artifacts or source.

GitHub Actions uses `MAC_CSC_LINK` / `MAC_CSC_KEY_PASSWORD` (with legacy
`CSC_LINK` / `CSC_KEY_PASSWORD` fallbacks) for the base64 signing P12 and password.
Windows uses `WIN_CSC_LINK` / `WIN_CSC_KEY_PASSWORD`.

## Distribution status

- macOS DMG workflow: arm64 and x64, with manual installation instructions.
  The current app is signed with Apple Development and is not notarized.
- v0.3.0 PKGs are superseded by v0.3.1 DMGs. Switching to DMG does not remove
  Gatekeeper warnings; use the scoped allow steps in **How to install** above.
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

For a local ad-hoc signed DMG without a signing certificate:

```bash
CLEARTONE_APP_SIGN_IDENTITY=- CLEARTONE_DRIVER_SIGN_IDENTITY=- npm run dist:mac
```

The resulting DMG is not notarized. See **How to install** for manual approval.
