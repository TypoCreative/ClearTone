# ClearTone V1 Design

## Summary

ClearTone v1 is a native-first macOS desktop app for real-time voice cleanup.
The product uses an Electron desktop shell for interface and app lifecycle, a
Swift engine for low-latency audio work, and a small IPC bridge between them.

This v1 intentionally prioritizes the hardest technical path first:

- microphone capture
- frame processing with RNNoise
- engine lifecycle control
- device selection
- real-time status reporting

The interface follows the style in `DESIGN.md`:

- high-contrast artistic presentation
- `Limelight` for display and body typography
- `JetBrains Mono` for labels and technical readouts
- bold primary and secondary color usage
- compact spacing and rounded surfaces

## Goals

- Prove real-time microphone capture and denoise processing work end-to-end
- Establish a stable Electron to Swift architecture for later product expansion
- Provide a minimal but polished control surface for the audio engine
- Surface permission, device, and engine errors clearly in the UI

## Non-Goals

- Shipping a complete onboarding flow
- Shipping virtual microphone routing in v1
- Shipping packaging, notarization, or installer workflows
- Building a multi-screen settings-heavy product shell
- Adding cloud AI, accounts, or remote services

## Product Shape

v1 is a single-window desktop app with one main workflow:

1. Launch the app
2. Review engine readiness
3. Select a microphone input
4. Start processing
5. Adjust denoise strength
6. Stop processing

The app should feel expressive and creative, but operationally simple. The user
must always know whether the engine is idle, starting, processing, stopping, or
in an error state.

## Architecture

### Electron App

Electron is responsible for:

- window creation
- app lifecycle
- renderer UI
- permission and engine status presentation
- dispatching user actions to the native bridge

The renderer should be organized around a single main control view plus a small
settings/debug section.

### Swift Engine

Swift is responsible for:

- microphone device discovery
- audio session and graph setup
- frame buffering
- RNNoise inference on audio frames
- engine lifecycle start and stop
- streaming engine state and metrics back to Electron

The native engine should be structured as small focused modules:

- `AudioDeviceManager`
- `AudioEngineController`
- `NoiseReductionProcessor`
- `EngineStatePublisher`
- `IPCCommandHandler`

### IPC Bridge

IPC sits between Electron and Swift and exposes a narrow, typed command surface.
The first version should remain intentionally small:

- `getStatus`
- `listInputs`
- `selectInput`
- `startProcessing`
- `stopProcessing`
- `setStrength`

The bridge should also emit asynchronous events for:

- engine state changes
- active input changes
- strength changes
- warnings and errors
- debug metrics

### Shared Contract

Electron and Swift should share a stable contract for:

- device descriptors
- engine state
- processing configuration
- recoverable warnings
- fatal errors

The contract can be represented as JSON-shaped payloads and mirrored in TypeScript
and Swift types. Keep the schema explicit and versionable so later features can
extend it without breaking the renderer.

## UI Design Direction

The UI should follow `DESIGN.md` directly.

### Visual Language

- white surfaces with strong blue and violet accent usage
- large `Limelight` display type for app title and key status moments
- `JetBrains Mono` labels for controls, metrics, and technical state
- compact spacing scale with strong contrast and deliberate blocks of color
- simple rounded corners using the existing small and medium radius tokens

### Main Screen

The primary screen contains:

- hero status card with engine state
- input device picker
- denoise strength slider
- start and stop primary action
- short technical status line

The status card is the centerpiece of the interface and should communicate one
thing clearly at all times: what the engine is doing right now.

### Secondary Panel

The secondary panel remains small in v1 and contains:

- engine version or build string
- debug logging toggle
- launch at login placeholder

This panel should not become a full preferences experience yet.

### Error States

Errors should render inline in the main surface rather than as generic blocking
alerts whenever possible.

Error messaging categories:

- microphone permission missing
- no input devices available
- selected device disconnected
- engine initialization failure
- IPC communication failure

Each error should include a plain-language reason and one actionable next step.

## Runtime Flow

### Launch

1. Electron starts and creates the main window
2. Renderer requests current engine status
3. Swift reports readiness, available inputs, and current configuration
4. Renderer paints the ready or blocked state

### Start Processing

1. User selects an input device
2. User presses start
3. Renderer sends `startProcessing`
4. Swift builds or activates the audio graph
5. RNNoise processing begins on incoming frames
6. Engine emits status and metrics back to Electron
7. Renderer transitions to `processing`

### Adjust Strength

1. User changes the strength slider
2. Renderer sends `setStrength`
3. Swift applies the new parameter without a full engine rebuild when possible
4. Renderer reflects the active value immediately

### Stop Processing

1. User presses stop
2. Renderer sends `stopProcessing`
3. Swift tears down or parks the processing graph cleanly
4. Renderer returns to the ready state

## Error Handling

### Permission Handling

If microphone permission is unavailable, the app should:

- block processing start
- show a dedicated permission error state
- explain that microphone access is required
- guide the user to enable permission in macOS settings

### Device Handling

If no inputs are available or the selected input disappears, the app should:

- show the device problem immediately
- preserve enough state to let the user recover cleanly
- refresh the device list without requiring a full restart where possible

### Engine Failures

If the native engine fails to initialize or run, the app should:

- stop processing attempts
- surface the native error in user-safe wording
- log the deeper diagnostic detail separately
- allow the user to retry after correction

### IPC Failures

If the bridge fails or desynchronizes, the renderer should:

- mark the engine state as unavailable
- disable controls that can no longer succeed
- show a visible error instead of hanging silently

## Testing Strategy

### Swift Tests

- configuration validation tests
- frame pipeline boundary tests
- engine state transition tests
- device selection behavior tests

### Electron Tests

- control rendering tests
- state mapping tests
- error state rendering tests
- command dispatch tests

### Integration Tests

- app boots and requests engine status
- device list renders
- start and stop path works against the native bridge
- status updates render in the main view
- recoverable errors display correctly

## Delivery Boundary For V1

The implementation is complete for this version when all of the following are
true:

- Electron launches a styled desktop window that follows `DESIGN.md`
- Swift enumerates microphone inputs
- the selected input can be processed by the RNNoise pipeline
- the UI can start and stop the engine
- the UI reflects real engine states and failures
- the architecture is clean enough to extend with virtual mic and richer UX later

## Recommended Repository Shape

The repository should evolve into a structure close to this:

```text
apps/
  electron/
    src/
      main/
      preload/
      renderer/
native/
  swift-engine/
    Sources/
    Tests/
packages/
  contracts/
docs/
  superpowers/
    specs/
```

This keeps UI, native engine, and shared contracts clearly separated.

## Open Follow-On Work

After this v1 foundation is stable, the next likely phases are:

- richer onboarding and permission UX
- saved presets and better settings management
- virtual microphone routing
- diagnostics panel
- packaging and distribution readiness
