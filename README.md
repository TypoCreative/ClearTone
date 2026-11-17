# ClearTone — Native Voice Clarity for macOS

ClearTone is a lightweight, local microphone-enhancement app. It reduces
background noise and improves voice clarity without Electron, cloud processing,
accounts, or audio uploads.

Current version: **0.3.2** (macOS build 6)

## How to install

Download the DMG from https://github.com/TypoCreative/ClearTone/releases/latest:
choose **arm64** for Apple silicon (M1/M2/M3/M4 or newer) or **x64** for Intel.
This build is **not notarized by Apple**, so macOS may require manual approval.
Only approve a ClearTone download you trust from this repository.

1. Open `ClearTone-0.3.2-mac-<arch>.dmg`.
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
xattr -d com.apple.quarantine "$HOME/Downloads/ClearTone-0.3.2-mac-arm64.dmg"
open "$HOME/Downloads/ClearTone-0.3.2-mac-arm64.dmg"
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

## Supported Mac laptops

ClearTone requires **macOS 13 Ventura or newer** and the matching native build.
Compatibility below follows the deployment target and [Apple’s Ventura model list](https://support.apple.com/en-us/102861).
It describes software compatibility, not a performance certification on every model.

| Mac laptop | Download | Support |
| --- | --- | --- |
| MacBook Air with Apple silicon, including M1 (2020) | arm64 | Supported; M1 Air is the baseline optimization target |
| MacBook Pro with Apple silicon | arm64 | Supported |
| Intel MacBook Air (2018–2020) | x64 | Supported with macOS 13+; performance varies |
| Intel MacBook Pro (2017–2020) | x64 | Supported with macOS 13+; performance varies |
| MacBook 12-inch (2017) | x64 | Meets OS requirement; sustained performance not measured |
| Earlier Intel laptops / macOS 12 or older | — | Unsupported |

M1 Air with 8 GB RAM is an intended configuration. CPU, memory, battery use and
thermal behavior still need measurement on an actual M1 Air during a long call.
Use the arm64 build on Apple silicon and menu-bar-only mode to release the main
window’s rendering surface. No reduced-quality audio mode is required.

## Features

| Feature | Apple silicon Mac | Intel Mac |
| --- | --- | --- |
| Native SwiftUI app and menu bar | Yes | Yes |
| Offline RNNoise, 48 kHz mono, 10 ms frames | Yes | Yes |
| Natural / Clear / Broadcast voice profiles | Yes | Yes |
| Adjustable processing strength | Yes | Yes |
| Built-in and external microphone selection | Yes | Yes |
| Follow system microphone and reconnect on device changes | Yes | Yes |
| ClearTone Virtual Microphone | Yes, bundled driver installation required | Yes, bundled driver installation required |
| Automatic default-input routing | Yes, when virtual microphone is enabled | Yes, when virtual microphone is enabled |
| Input/output, reduction and latency metrics | Yes | Yes |
| CPU and memory metrics | Yes | Yes |
| Menu-bar-only mode | Yes | Yes |
| Account, audio upload or cloud processing required | No | No |
| Apple notarization in current release | No; manual approval may be needed | No; manual approval may be needed |

## What it does

AVAudioEngine captures microphone audio and converts it to 48 kHz mono when
needed. Every 480-sample frame passes through RNNoise and native voice finishing,
then goes to the Core Audio HAL virtual microphone when enabled. Audio stays on
the device. Model, sample rate, finishing profiles and processing strength remain
the same across supported Macs.

The processing queue has a bounded buffer pool and reuses sample storage. RNNoise
state is allocated on Start and released after a short idle delay. UI audio metrics
update once per second and process CPU/memory metrics every ten seconds.
See [performance measurements and validation limits](docs/PERFORMANCE.md).

If startup is waiting for microphone access or reconnecting, use **Cancel Starting**
and retry. Allow microphone access in System Settings and select an available
physical microphone. macOS audio configuration changes that stop capture trigger
a restart while processing is active.

Windows sources remain for reference/local builds; GitHub Actions no longer
builds, verifies or publishes Windows artifacts.

## Use cases

- Meetings with fan, keyboard, HVAC, or nearby speech noise.
- Streaming, gaming, and voice chat.
- Podcast, voice-over, demo, and screen-recording workflows.
- Teaching and support calls where clearer speech improves accessibility.

See [native code architecture](docs/ARCHITECTURE.md) for component responsibilities
and audio queue ownership.

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
└── .github/workflows/                      # macOS quality/releases
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

## Signed local build

Run the local signing wrapper:

```bash
npm run build
```

On macOS, `npm run build` produces a DMG using `_dev-id-apple.p12` or an
installed Keychain identity selected by `CLEARTONE_APP_SIGN_IDENTITY`. Set
`CLEARTONE_MAC_CERTIFICATE_PASSWORD` (or `MACOS_CERTIFICATE_PASSWORD` /
`CSC_KEY_PASSWORD`), or enter the P12 password at the hidden prompt.

Apple Development signing is supported for the current manual-install builds.
Output: `dist/ClearTone-0.3.2-mac-<arch>.dmg`, containing ClearTone.app, an
Applications shortcut and `HOW_TO_INSTALL.md`. There is no top-level PKG or
automatic quarantine cleanup. The virtual microphone driver retains its bundled
PKG, installed from the app's **Install Driver** action.

On Windows, provide `WINDOWS_CERTIFICATE_PFX` as a file path or base64 value and
optionally `WINDOWS_CERTIFICATE_PASSWORD`. The script uses `signtool.exe`, SHA-256,
and an RFC 3161 timestamp, then requires Authenticode status `Valid`. Passwords are
passed through the process environment and never written into artifacts or source.

GitHub Actions uses `MAC_CSC_LINK` / `MAC_CSC_KEY_PASSWORD` (with legacy
`CSC_LINK` / `CSC_KEY_PASSWORD` fallbacks) for the base64 signing P12 and password.
Windows signing variables are only used by local Windows scripts.

## Distribution status

- macOS DMG workflow: arm64 and x64, with manual installation instructions.
  The current app is signed with Apple Development and is not notarized.
- v0.3.0 PKGs are superseded by v0.3.1 DMGs. Switching to DMG does not remove
  Gatekeeper warnings; use the scoped allow steps in **How to install** above.
- Windows CI and release builds are disabled. Existing historical release assets
  are not deleted by this change.

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
