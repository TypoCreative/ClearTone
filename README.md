# ClearTone — Real-Time Voice Clarity for macOS

ClearTone is an on-device microphone enhancement app for macOS. It removes
background noise, improves voice clarity, and routes the cleaned signal to other
apps through **ClearTone Virtual Microphone**.

No account, cloud service, or internet connection is required. Audio processing
stays on the Mac.

Current version: **0.2.1**

## What It Does

ClearTone turns a physical microphone into a cleaner, application-ready audio
source:

1. Captures audio from the selected microphone with Core Audio.
2. Converts the signal to mono, 48 kHz audio when required.
3. Processes each 10 ms frame with RNNoise.
4. Applies voice enhancement, including filtering, adaptive suppression,
   dereverb-lite, EQ, automatic gain, compression, and limiting.
5. Sends the result to ClearTone Virtual Microphone when virtual routing is on.
6. Makes the cleaned signal available to conferencing, streaming, recording, and
   communication apps.

When virtual routing is enabled, ClearTone selects its virtual microphone as the
macOS default input. Turning routing off or quitting normally restores the physical
input.

## Features

| Feature | Description |
| --- | --- |
| **Real-time noise reduction** | RNNoise processes 480-sample frames at 48 kHz for low-latency voice cleanup. |
| **Voice enhancement** | High-pass filtering, adaptive speech protection, dereverb-lite, voice EQ, automatic gain, compression, and limiting. |
| **Voice presets** | Natural, Clear, and Broadcast profiles provide different levels of polish without manual DSP configuration. |
| **Adjustable denoise strength** | A 0–100% control balances natural voice detail against stronger background-noise removal. |
| **Virtual Microphone toggle** | Enables or disables system-wide cleaned-audio routing from one place. |
| **Bundled driver installer** | Detects a missing driver and provides an administrator-approved macOS installation flow. |
| **Flexible microphone selection** | Follows the macOS default input automatically or stays locked to a chosen physical microphone. |
| **Live audio diagnostics** | Reports input and output level, measured noise reduction, latency, processed frames, dropped frames, and output queue depth. |
| **Resource monitoring** | Displays application CPU, resident memory, GPU activity, and process count. |
| **Dashboard and menu bar controls** | Provides a full control center and a compact tray popup with the same essential audio controls. |
| **Tray-only mode** | Releases the main renderer when it is not needed to lower background memory usage. |
| **Local processing** | Keeps microphone audio on-device with no upload, account, or remote inference service. |
| **Accessible controls** | Includes keyboard navigation, visible focus states, semantic status updates, descriptive labels, and reduced background animation. |
| **Native macOS engine** | Uses Swift, Core Audio, and release builds matched to arm64 or x64 Macs. |

## Architecture

ClearTone separates the control interface from the real-time audio path. A native
Swift process handles audio work, while Electron and React provide the dashboard,
menu bar UI, settings, and lifecycle management.

```text
Control plane

React UI ── contextBridge ── Electron main ── JSON lines ── Swift engine
   ▲                              │                                │
   └──────── typed snapshots ─────┴────────────────────────────────┘

Audio plane

Physical microphone
        │
        ▼
Core Audio capture and sample-rate conversion
        │
        ▼
RNNoise ──► voice enhancement ──► reusable output buffer pool
                                           │
                                           ▼
                         ClearTone Virtual Microphone driver
                                           │
                                           ▼
                           Zoom, Meet, Discord, OBS, and others
```

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Renderer | React 19, TypeScript, Tailwind CSS, Radix UI | Dashboard, tray controls, accessibility, live status, and metrics. |
| Desktop shell | Electron 43 | Window and tray lifecycle, settings, secure renderer bridge, process monitoring, and native-engine supervision. |
| Shared contracts | TypeScript package | Commands, acknowledgements, settings, snapshots, and metric types shared across app boundaries. |
| Native engine | Swift 6.2, AVAudioEngine, Core Audio | Device discovery, microphone capture, format conversion, processing coordination, and virtual output. |
| Noise reduction | RNNoise C library | Neural noise suppression on 10 ms audio frames. |
| Voice finishing | Native Swift DSP | Filtering, adaptive suppression, dereverb-lite, EQ, gain control, compression, and limiting. |
| Virtual device | Core Audio Audio Server Plug-in | Exposes the processed output as a microphone that macOS applications can select. |
| Transport | Newline-delimited JSON over stdin/stdout | Keeps UI and native audio failures isolated while providing typed commands and snapshots. |
| Build system | Swift Package Manager, electron-vite, electron-builder, Xcode | Builds the engine, universal driver installer, application bundle, and DMG artifacts. |

The engine reuses audio and conversion buffers in its real-time path. Device scans
occur only when needed, metrics are rate-limited, and hidden renderers are released
to reduce CPU wakeups and memory pressure without changing audio quality.

## Benefits

| Benefit | Why It Matters |
| --- | --- |
| **Clearer speech** | Reduces steady noise, keyboard sounds, fan noise, and other distractions while preserving active speech. |
| **One setup for multiple apps** | Configure the microphone once in ClearTone, then use the virtual microphone across supported macOS apps. |
| **Private by design** | Audio is processed locally and is not sent to a server. |
| **Consistent voice profile** | Uses the same denoise strength and voice preset across calls, streams, and recordings. |
| **Visible system health** | Live latency, drop, queue, CPU, memory, and GPU metrics make performance issues easier to identify. |
| **Low idle overhead** | Tray-only mode, renderer cleanup, rate-limited polling, and delayed DSP memory cleanup reduce background resource usage. |
| **Failure isolation** | The native audio engine runs separately from the Electron UI and can be supervised or restarted independently. |
| **Fast access** | Essential controls remain available from the macOS menu bar. |
| **Extensible processing pipeline** | Typed boundaries and separate DSP modules make future models or voice processors easier to add. |

## Use Cases

| Use case | Typical noise or problem | How ClearTone helps |
| --- | --- | --- |
| **Remote meetings** | Fans, air conditioning, nearby conversations, and keyboard noise. | Provides a consistent cleaned microphone to Zoom, Meet, Teams, and similar apps. |
| **Streaming and gaming** | Mechanical keyboards, computer fans, controller noise, and room ambience. | Improves voice communication and stream audio before it reaches OBS or chat apps. |
| **Podcasting and voice-over** | Untreated rooms, light echo, HVAC hum, and inconsistent voice level. | Applies denoise and voice finishing before recording. |
| **Online teaching and support** | Household activity, pets, doorbells, and background speech. | Keeps spoken instructions easier to understand. |
| **Mobile or shared workspaces** | Cafe noise, coworking chatter, and changing microphone devices. | Follows the system input and maintains the selected voice profile. |
| **Product demos and screen recordings** | Laptop fan noise, typing, and inconsistent microphone distance. | Produces a more controlled narration track in recording software. |
| **Accessibility and speech communication** | Environmental noise that makes speech harder to distinguish. | Improves voice-to-background contrast for listeners. |

---

## Development

### Prerequisites

- macOS 14+
- Xcode 26+ / Swift 6.2+ (for Swift engine)
- Node.js 22+
- npm 10+

### Quick Start

```bash
# Install dependencies
npm install

# Build Swift engine
cd native/swift-engine && swift build && cd ../..

# Start dev server
npm run dev
```

### Project Structure

```
TC-ClearTone/
├── apps/                          # Electron app
│   └── src/
│       ├── main/                  # Main process (window, tray, IPC)
│       ├── preload/               # contextBridge API
│       └── renderer/              # React UI
│           └── src/
│               ├── views/         # AppView, TrayView
│               ├── components/    # UI components
│               ├── hooks/         # useEngineSnapshot, useThemePreference
│               └── utils/         # Formatters, state helpers
├── native/swift-engine/           # Swift native engine
│   ├── Package.swift              # SPM manifest
│   └── Sources/
│       ├── CRNNoise/              # RNNoise C library
│       └── ClearToneEngine/       # Swift engine modules
├── native/virtual-microphone-driver/ # Universal Core Audio HAL driver
├── packages/contracts/            # Shared TypeScript types
│   └── src/index.ts               # EngineSnapshot, EngineCommand, etc.
└── docs/
    ├── plan/                      # PRD, ADR, Roadmap, Decisions
    ├── research/                  # RNNoise, Core Audio, latency, etc.
    └── superpowers/specs/         # Design specs
```

### Available Commands

```bash
npm run dev          # Start Electron dev server with hot reload
npm run build        # Build for distribution
npm run build:driver # Build the universal HAL driver and installer package
npm run dist:mac     # Build a macOS DMG (signed when credentials are available)
npm run check        # Lint, typecheck, test, and production build
```

The production build compiles the Swift engine and the universal virtual microphone
driver in release mode, then copies both into app resources before packaging.

For macOS packaging, place `_dev-id-apple.p12` in the project root and run
`npm run dist:mac`. ClearTone imports that certificate into an isolated temporary
keychain, signs the app, and removes the keychain after the build. For a
password-protected certificate, the command prompts securely in an interactive
terminal; set `CSC_KEY_PASSWORD` instead for CI or other non-interactive builds. You
can set `CSC_LINK` explicitly to override root certificate detection. Certificate
files are ignored by Git and are never bundled with the app. When no certificate is
available, packaging produces an unsigned development build. An Apple Development
identity can sign local test builds; public releases still require a Developer ID
Application identity so they can be notarized and distributed outside the App Store.

The GitHub release workflow builds on native `macos-26-intel` and `macos-26`
runners so the bundled Swift engine matches the x64 or arm64 DMG. Configure these
repository secrets for signed releases:

- `CSC_LINK`: base64-encoded Developer ID Application `.p12` certificate.
- `CSC_KEY_PASSWORD`: password used when exporting the certificate.

A manually dispatched workflow can create unsigned test DMGs without those secrets.
A published GitHub Release requires `CSC_LINK` to prevent accidentally distributing
an unsigned application.

To notarize, configure either App Store Connect API credentials
(`APPLE_API_KEY`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`) or the Apple ID
notarization credentials supported by electron-builder.

For a distributable driver installer, import the matching certificates into the
build keychain and set `CLEARTONE_DRIVER_SIGN_IDENTITY` to a Developer ID Application
identity and `CLEARTONE_INSTALLER_SIGN_IDENTITY` to a Developer ID Installer identity.
Without them, `npm run build:driver` creates an ad-hoc-signed development driver and
an unsigned local installer package.

### Virtual Microphone

ClearTone bundles its own Audio Server Driver Plug-in. If it is not installed, the
Virtual Microphone card shows **Install Driver** instead of allowing an invalid
toggle action. The button invokes the bundled installer through a standard macOS
administrator prompt and installs the driver in `/Library/Audio/Plug-Ins/HAL`.
ClearTone polls Core Audio and makes the toggle available as soon as the device is
detected. A logout or restart may be required on macOS versions that do not reload
the plug-in immediately.

When enabled, ClearTone binds capture to the selected physical microphone, writes
RNNoise output to the driver's output stream, and changes the macOS default input
to the driver's input stream. Turning it off or quitting normally restores the
physical system input. The device name is `ClearTone Virtual Microphone`; its UID is
`com.typocreative.cleartone.virtual-microphone`.

Apple recommends Audio Server Driver Plug-ins for virtual audio devices;
AudioDriverKit is intended for physical audio hardware. The driver source is based
on Apple's MIT-licensed minimal sample, with its license retained next to the code.

---

## Installation

Download the latest `ClearTone.dmg` from
[GitHub Releases](https://github.com/TypoCreative/ClearTone/releases), open it, and
drag `ClearTone.app` to your `Applications` folder.

### If macOS Blocks the App

Development builds that are not notarized may show a warning. Use one of these methods:

**Option A — Open Anyway from System Settings**

1. Open **System Settings** → **Privacy & Security**
2. Scroll down until you find the message that ClearTone was blocked
3. Click **Open Anyway**
4. Confirm again if prompted

**Option B — Remove Quarantine from Terminal**

If the app is already in `/Applications`:

```bash
sudo xattr -dr com.apple.quarantine /Applications/ClearTone.app
```

Then open `ClearTone.app` again.

### Microphone Permission

The first time you start processing, macOS will ask for microphone access. You must grant it — ClearTone needs mic input to work.

---

## License

MIT
