# ClearTone

**Professional AI microphone for macOS** — real-time noise cancellation that runs entirely on your Mac.

---

## What It Does

ClearTone cleans microphone audio in real time using AI. With the ClearTone virtual
microphone driver installed, background noise is removed before the signal reaches
Zoom, Discord, OBS, or another app that follows the macOS default input.

**100% private.** Nothing leaves your Mac. No accounts, no cloud, no servers.

---

## Features

| Feature | Detail |
|---------|--------|
| **AI Denoising** | RNNoise neural network from Mozilla/Xiph — 48kHz, 10ms frames |
| **Adjustable strength** | 0–100% slider — subtle cleanup or aggressive noise removal |
| **Measured latency** | Capture-to-processing latency and output queue depth reported live |
| **Dual interface** | Full dashboard + compact tray popup (always one click away) |
| **Device management** | Auto-detect all mics, follow system input, or lock to a specific device |
| **Live metrics** | Input/output RMS, noise reduction %, latency, frames processed |
| **Virtual microphone routing** | Routes cleaned audio to ClearTone Virtual Microphone when its driver is installed |
| **Apple Silicon native** | Compiled for M1/M2/M3/M4 — lightweight (~5% CPU, ~15MB) |
| **Dark/light theme** | Toggle in the dashboard |
| **Tray-only mode** | Run without the main window — stays in your menu bar |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                 macOS Desktop                │
│                                              │
│  ┌─────────────┐         ┌────────────────┐ │
│  │  Electron    │  IPC    │  Swift Engine  │ │
│  │  (React UI)  │◄──────►│  (Core Audio + │ │
│  │              │  JSON   │   RNNoise)     │ │
│  └─────────────┘         └───────┬────────┘ │
│                                   │          │
│                            ┌──────▼────────┐ │
│                            │ Physical Mic  │ │
│                            └──────┬────────┘ │
│                                   │ cleaned  │
│                            ┌──────▼────────┐ │
│                            │ Virtual Mic   │ │
│                            │ (HAL plug-in) │ │
│                            └───────────────┘ │
└─────────────────────────────────────────────┘
```

| Layer | Technology | Role |
|-------|-----------|------|
| UI | React 19 + TypeScript + Tailwind CSS v4 + Radix UI | Dashboard, tray popup, controls |
| Shell | Electron 43 | Window management, tray, app lifecycle |
| IPC | stdin/stdout JSON lines | Typed command protocol |
| Engine | Swift 6.2 + Core Audio | Mic capture, processing graph, device enumeration |
| Virtual device | Core Audio Audio Server Plug-in (HAL) | Loopback output-to-input device for all macOS apps |
| AI | RNNoise v0.2 (C library) | Frame-level denoising (480 samples = 10ms) |
| Build | electron-vite, electron-builder, SPM | Dev server, DMG packaging |

---

## Benefits

| Benefit | What It Means |
|---------|---------------|
| **Sound professional anywhere** | Take calls from cafes, airports, co-working spaces without background noise |
| **100% private** | All processing is on-device. No audio ever leaves your Mac |
| **Works with everything** | Compatible through the ClearTone virtual microphone driver |
| **Observable audio health** | Measured latency, dropped frames, and queue depth make glitches diagnosable |
| **Lightweight** | ~15MB binary, ~5% CPU on M1+. Sips battery |
| **Always accessible** | Menu bar icon. Toggle on/off in one click |
| **Apple Silicon native** | Compiled for arm64. Uses hardware acceleration |
| **Open model** | RNNoise is BSD-licensed. Proven in Mozilla, OBS, Discord |
| **Extensible** | Modular engine. Swap AI models without rewriting the UI |
| **Polished design** | Dark glassy aesthetic, glow effects, professional typography |

---

## Use Cases

| Scenario | Without ClearTone | With ClearTone |
|----------|------------------|----------------|
| Remote work from a cafe | Espresso machine + chatter in every call | Clean, professional voice |
| Gaming / streaming | Keyboard clacks, fan noise, room echo | Crisp comms, better stream quality |
| Podcasting in an untreated room | Reverb, street noise, HVAC hum | Studio-like sound |
| Online teaching | Kids, pets, doorbells | Focus on your voice |
| Voice recording on the go | Wind, traffic, crowd noise | Clean takes anywhere |

---

## Development

### Prerequisites

- macOS 14+
- Xcode 16+ (for Swift engine)
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
npm run dist:mac     # Build a signed macOS DMG
npm run check        # Lint, typecheck, test, and production build
```

The production build compiles the Swift engine and the universal virtual microphone
driver in release mode, then copies both into app resources before packaging.

For macOS packaging, place `_dev-id-apple.p12` in the project root and run
`npm run dist:mac`. ClearTone detects that certificate and passes it to
`electron-builder`. For a password-protected certificate, the command prompts securely
in an interactive terminal; set `CSC_KEY_PASSWORD` instead for CI or other
non-interactive builds. You can set `CSC_LINK` explicitly to override root certificate
detection. Certificate files are ignored by Git and are never bundled with the app.

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

Download the latest `ClearTone.dmg` from [Releases](https://github.com/your-repo/cleartone/releases), open it, and drag `ClearTone.app` to your `Applications` folder.

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
