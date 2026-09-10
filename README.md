# ClearTone — Native Voice Clarity for macOS

ClearTone is a native macOS microphone enhancement app. It removes background
noise, improves voice clarity, and routes the cleaned signal to other apps through
**ClearTone Virtual Microphone**.

The dashboard, menu bar interface, audio engine, settings, and performance monitor
run in one Swift process. ClearTone does not bundle Electron, Chromium, React,
Node.js, an account system, or a cloud audio service. Microphone audio stays on the
Mac.

Current version: **0.2.1**

## What It Does

1. Captures the selected physical microphone with Core Audio.
2. Converts its signal to mono 48 kHz audio when needed.
3. Processes every 480-sample, 10 ms frame with RNNoise.
4. Applies filtering, adaptive suppression, dereverb-lite, voice EQ, automatic
   gain, compression, and limiting.
5. Sends cleaned frames through the ClearTone Core Audio virtual microphone.
6. Automatically selects that virtual microphone as the macOS default input while
   routing is enabled, then restores the physical input when routing stops.

## Features

| Feature | Description |
| --- | --- |
| Real-time noise reduction | Runs RNNoise on every 10 ms frame without lowering the audio processing rate to save resources. |
| Voice enhancement | Adds native filtering, speech protection, dereverb-lite, EQ, gain control, compression, and limiting. |
| Voice profiles | Offers Natural, Clear, and Broadcast profiles. |
| Adjustable strength | Balances voice detail and stronger suppression from 0–100%. |
| One-switch virtual routing | Enables cleaned audio and changes the macOS default input from ClearTone. |
| Driver recovery | Detects a missing virtual microphone and opens the bundled installer. |
| Input control | Follows the current macOS input or locks processing to a selected physical microphone. |
| Live diagnostics | Shows input/output RMS, reduction, latency, dropped frames, and queue depth. |
| Lightweight performance panel | Shows native process CPU and resident memory; GPU work is handled by the macOS compositor, with no ClearTone GPU helper process. |
| Native dashboard and menu bar | Uses SwiftUI/AppKit controls with a compact tray-only mode. |
| Visible audio route | Shows Input → Voice Engine → Output in both the dashboard and compact menu-bar interface, including live routing state. |
| Accessibility | Provides native keyboard navigation, VoiceOver labels, scalable system fonts, semantic controls, and readable status/error messages. |
| Local processing | Requires no upload, sign-in, or internet connection for audio processing. |

## Architecture

ClearTone now uses one application process for UI and audio coordination. There is
no browser renderer, Electron main process, network utility process, GPU helper, or
JSON subprocess bridge.

```text
SwiftUI dashboard + 18 × 18 pt macOS menu-bar item
             │
             ▼
Native app model and settings
             │
             ▼
AVAudioEngine + Core Audio device control
             │
             ▼
RNNoise (10 ms frames) → native voice enhancement
             │
             ▼
Reusable virtual-output buffer pool
             │
             ▼
ClearTone Virtual Microphone HAL driver
             │
             ▼
Zoom, Meet, Teams, Discord, OBS, recording apps
```

| Layer | Technology | Responsibility |
| --- | --- | --- |
| App interface | SwiftUI and AppKit | Dashboard, menu bar, native controls, lifecycle, settings, errors, and accessibility. |
| Audio engine | Swift, AVAudioEngine, Core Audio | Device discovery, capture, conversion, processing coordination, and default-input routing. |
| Noise reduction | RNNoise C library | Neural suppression on 480-sample frames at 48 kHz. |
| Voice finishing | Native Swift DSP | Filtering, adaptive suppression, dereverb-lite, EQ, gain, compression, and limiting. |
| Virtual device | Core Audio Audio Server Plug-in | Exposes processed output as a macOS input device. |
| Build system | Swift Package Manager and Xcode command-line tools | Builds the app, HAL driver installer, application bundle, and DMG. |

The real-time path retains the existing buffer reuse, 480-sample fast path, pooled
virtual-output buffers, 1 Hz audio metrics, and delayed RNNoise cleanup. Moving the
UI to Swift does not reduce audio quality; it removes framework overhead around the
audio engine.

## Expected Resource Improvement

The native build targets one ClearTone application process instead of the previous
Electron main, renderer, GPU helper, network helper, and separate Swift engine.
This should substantially reduce idle RAM, CPU wakeups, application size, and
process count.

Exact memory and CPU depend on the microphone, macOS version, driver state, active
window, and whether processing is running. On the Apple Silicon development Mac,
the verified 0.2.1 build measured about 60 MB physical memory while idle, 0–0.1%
idle CPU, 16–28% of one CPU core while processing, and about 2.2 ms measured
processing latency. These are development measurements, not guaranteed limits.

## Benefits

- Lower idle memory and fewer processes.
- Faster launch and more consistent macOS controls.
- The same RNNoise and voice-enhancement quality as the previous engine.
- No Chromium or JavaScript runtime in the shipped application.
- One setup point for calls, streams, recordings, and voice chat.
- Local audio processing and native permission handling.
- Automatic restoration of the physical input on normal termination.

## Use Cases

- Remote meetings with fan, keyboard, HVAC, or nearby speech noise.
- Streaming and gaming through OBS or voice chat.
- Podcasts, voice-over, demos, and screen recordings.
- Online teaching, customer support, and shared workspaces.
- Accessibility situations where stronger voice-to-background contrast helps
  listeners.

## Development

### Requirements

- macOS 13 or newer
- Xcode 26 or newer with Swift 6.2
- Xcode command-line tools

Node.js and npm are not required by the native build scripts. The small root
`package.json` remains only as optional command aliases for existing contributors.

### Build and Run

```bash
# Run directly with Swift Package Manager
swift run --package-path native/swift-engine --disable-sandbox ClearTone

# Build and ad-hoc sign dist/ClearTone.app
scripts/build-app.sh

# Run native tests
scripts/check.sh

# Build the HAL driver installer
scripts/build-driver.sh

# Build the app, driver, and versioned DMG
scripts/package-mac.sh
```

The equivalent aliases are `npm run dev`, `npm run build`, `npm test`, and
`npm run dist:mac`; they execute the same Swift/shell commands and do not install
or launch Electron.

### Project Structure

```text
ClearTone/
├── native/
│   ├── swift-engine/
│   │   ├── Package.swift
│   │   ├── Resources/              # Info.plist, entitlements, driver package
│   │   ├── Sources/CRNNoise/       # RNNoise C sources
│   │   └── Sources/ClearToneEngine/
│   │       ├── AppEntry.swift      # Native app and menu bar entry point
│   │       ├── NativeApp.swift     # SwiftUI views, state, settings, metrics
│   │       └── ...                 # Core Audio and DSP pipeline
│   └── virtual-microphone-driver/  # Core Audio HAL driver source
├── scripts/                        # Native build, test, driver, and DMG scripts
├── docs/                           # Product decisions and research
└── .github/workflows/              # Native arm64/x64 release builds
```

### Signing

To build a DMG containing a Developer ID-signed app and driver, place
`_dev-id-apple.p12` in the repository root and run `scripts/package-mac.sh`. The
script asks for the certificate password without printing it, imports the identity
into a temporary keychain, signs the native app and driver, then deletes the
temporary keychain.

A public release must use a valid **Developer ID Application** identity with its
private key. GitHub Actions reads the base64-encoded certificate and password from
`CSC_LINK` and `CSC_KEY_PASSWORD`. Local builds fall back to ad-hoc signing.
Signing the installer package requires `CLEARTONE_INSTALLER_SIGN_IDENTITY`; the
current release workflow does not set it. DMG notarization and stapling also require
separate Apple notary credentials and are not implied by application code signing.

### Microphone Permission

The first processing start triggers the native macOS microphone permission dialog.
If access was denied, enable ClearTone under **System Settings → Privacy & Security
→ Microphone**, then reopen the app.

## License

MIT
