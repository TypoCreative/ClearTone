# ClearTone

**Professional AI microphone for macOS** — real-time noise cancellation that runs entirely on your Mac.

---

## What It Does

ClearTone cleans your microphone audio in real time using AI. Background noise — keyboard clicks, fans, cafe chatter, traffic, pets — is removed before your voice reaches Zoom, Discord, OBS, or any other app.

**100% private.** Nothing leaves your Mac. No accounts, no cloud, no servers.

---

## Features

| Feature | Detail |
|---------|--------|
| **AI Denoising** | RNNoise neural network from Mozilla/Xiph — 48kHz, 10ms frames |
| **Adjustable strength** | 0–100% slider — subtle cleanup or aggressive noise removal |
| **Low latency** | <20ms end-to-end — imperceptible in real-time |
| **Dual interface** | Full dashboard + compact tray popup (always one click away) |
| **Device management** | Auto-detect all mics, follow system input, or lock to a specific device |
| **Live metrics** | Input/output RMS, noise reduction %, latency, frames processed |
| **Universal** | Works with Zoom, Meet, Teams, Discord, OBS, QuickTime, GarageBand — any app |
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
│                            │  Microphone    │ │
│                            │  (Core Audio)  │ │
│                            └───────────────┘ │
└─────────────────────────────────────────────┘
```

| Layer | Technology | Role |
|-------|-----------|------|
| UI | React 19 + TypeScript + Tailwind CSS v4 + Radix UI | Dashboard, tray popup, controls |
| Shell | Electron 43 | Window management, tray, app lifecycle |
| IPC | stdin/stdout JSON lines | Typed command protocol |
| Engine | Swift 6.2 + Core Audio | Mic capture, processing graph, device enumeration |
| AI | RNNoise v0.2 (C library) | Frame-level denoising (480 samples = 10ms) |
| Build | electron-vite, electron-builder, SPM | Dev server, DMG packaging |

---

## Benefits

| Benefit | What It Means |
|---------|---------------|
| **Sound professional anywhere** | Take calls from cafes, airports, co-working spaces without background noise |
| **100% private** | All processing is on-device. No audio ever leaves your Mac |
| **Works with everything** | Compatible with any app that uses a microphone |
| **No perceptible delay** | <20ms latency — you speak, they hear you instantly |
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
npm run dist:mac     # Build a signed macOS DMG
npm run preview      # Preview production build
```

For macOS packaging, place `_dev-id-apple.p12` in the project root and run
`npm run dist:mac`. ClearTone detects that certificate and passes it to
`electron-builder`. For a password-protected certificate, the command prompts securely
in an interactive terminal; set `CSC_KEY_PASSWORD` instead for CI or other
non-interactive builds. You can set `CSC_LINK` explicitly to override root certificate
detection. Certificate files are ignored by Git and are never bundled with the app.

---

## Installation

Download the latest `ClearTone.dmg` from [Releases](https://github.com/your-repo/cleartone/releases), open it, and drag `ClearTone.app` to your `Applications` folder.

### If macOS Blocks the App

Since ClearTone is not yet notarized, macOS may show a warning. Use one of these methods:

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
