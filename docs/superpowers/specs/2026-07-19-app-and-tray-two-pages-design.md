# ClearTone — App & Tray Two Pages (Same Functions) Design

## Summary

ClearTone will provide two distinct renderer pages with the same engine controls and data:

- Full App page: utility dashboard (two-row layout).
- Tray Popup page: custom-designed compact popover window (not a system menu), opened from the macOS tray icon.

Both pages share the same state, commands, and metrics feed from the native engine via the existing preload bridge. Only layout and visual density differ.

## Goals

- Provide two distinct UIs:
  - Full App page optimized for at-a-glance control + monitoring.
  - Tray Popup page optimized for quick actions + compact monitoring.
- Keep identical functionality between App and Tray:
  - Start/Stop processing
  - Select input device or follow system input
  - Change denoise strength
  - Display engine metrics and current status
- Ensure tray popup behaves like a custom popover:
  - Auto-close on blur (click outside).

## Non-Goals

- Separate renderer bundles or separate build pipelines for tray vs app.
- Introducing a routing library (keep current hash-switch approach).
- Reworking native engine processing logic beyond what is needed to expose the required metrics.

## User Experience

### Full App Page

- Layout: two-row utility dashboard
  - Row 1 (controls):
    - Left: Start/Stop
    - Right: Device selector + Strength slider
  - Row 2 (monitoring): engine metrics panel
- Typography: Comic Sans MS across the entire application.

### Tray Popup Page

- Layout: compact vertical popover card
  - Primary Start/Stop control (most prominent)
  - Device selector
  - Strength slider
  - Mini metrics grid (compact)
- Auto-close: yes (hide on blur).
- No separate “Engine ON/OFF” text header; rely on the Start/Stop state and button labeling.

### Tray Popup Metrics (selected)

Show the following four metrics in the tray popup:

- Input RMS
- Output RMS
- Noise Reduction %
- Latency (ms)

## Architecture

### Renderer Page Selection

- Keep a single renderer bundle and select the UI variant via hash:
  - `#tray-popup` renders Tray Popup page.
  - Any other hash (or none) renders Full App page.
- Electron main already loads the popup window with `#tray-popup`; no main-process routing changes required.

### Component Breakdown

Split the existing monolithic renderer component into:

- `App.tsx`: top-level switch (hash → view)
- `views/AppView.tsx`: full app layout only
- `views/TrayView.tsx`: tray layout only

Shared building blocks (used by both views):

- `hooks/useEngineSnapshot.ts` (or equivalent): subscribes to `window.clearTone.getStatus()` + `window.clearTone.onSnapshot(...)` and exposes snapshot + loading flags.
- `components/EngineControls.tsx`: Start/Stop, Device selector, Strength slider.
- `components/EngineMetrics.tsx`: metrics rendering with layout variants (`dense` for tray, `standard` for app).

### Data Flow (Shared for App + Tray)

- Renderer requests initial state: `window.clearTone.getStatus()`.
- Renderer subscribes to updates: `window.clearTone.onSnapshot(handler)`.
- User actions send commands:
  - `startProcessing`, `stopProcessing`
  - `selectInput` / `followSystemInput`
  - `setStrength`

Main process continues to forward engine snapshots to both windows (main window and tray popup window).

## Contract Changes (Metrics)

Current contracts only include:

- `framesProcessed`
- `inputLevel`
- `estimatedLatencyMs`

To support tray popup metrics, extend the shared contracts to include:

- `inputRms` (or rename `inputLevel` to `inputRms`, but avoid breaking changes by adding fields)
- `outputRms`
- `noiseReductionPercent`
- Keep `estimatedLatencyMs`

This requires updating:

- TypeScript contracts (`packages/contracts`)
- Native engine snapshot payload to include the new metrics
- Renderer metric formatting and display mapping

## Styling Requirements

- Comic Sans MS remains the primary font across both pages.
- Tray popup styling:
  - compact spacing and smaller typography scale
  - optimized for a small frameless window
  - no scrollbars in typical states

## Error States

- If permissions are denied/restricted: disable Start; show a clear status message.
- If no input devices exist: disable Start; show “No microphone available”.
- If the engine reports `lastError`: show error card in both UIs (tray version can be more compact but must still be readable).

## Verification Checklist

- Tray popup renders Tray UI when opened from tray icon (hash `#tray-popup`).
- Main app window renders App UI (no tray-specific elements).
- Actions behave identically in both pages:
  - Start/Stop works
  - Device selection and follow-system works
  - Strength updates update processing behavior
- Metrics update continuously in both pages.
- Tray popup auto-closes when focus is lost.

