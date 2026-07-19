# ClearTone Tray UI Update (Dark + Metrics List + Glass)

## Summary

Update the tray popup UI to:

- Always render in dark mode (tray popup only)
- Display metrics in a compact list layout (instead of a grid)
- Match the existing “glassy macOS” aesthetic (frosted, translucent, subtle borders)

This change targets the tray popup renderer entry and tray UI only. The main app window keeps its current theme behavior and any theme toggle UI.

## Goals

- Tray popup always appears in dark theme regardless of stored theme preference.
- Tray metrics are presented as a readable list with right-aligned values.
- Tray container styling matches glassy macOS look (dark, translucent, blurred, subtle border).
- Preserve existing tray interaction model (toggle popup on tray click; hide on blur).

## Non-goals

- Forcing dark mode for the main window.
- Changing the snapshot data contract or adding new metrics to the native engine.
- Redesigning the main app layout.

## UX / UI Design

### Theme behavior (tray only)

- The tray renderer forces dark mode at startup by applying the `dark` class to `document.documentElement`.
- The tray renderer does not read, write, or honor `cleartone-theme` localStorage.

### Tray layout

Continue using the existing structure:

- Header: ClearTone title + status badge (left), Start/Stop toggle (right)
- Controls: device selector + strength slider
- Errors: show error state if present
- Metrics: replace the tray metrics grid with a list

### Metrics list

Tray metrics list rows:

- `In` (Input RMS)
- `Out` (Output RMS)
- `NR` (Noise reduction percent)
- `Lat` (Estimated latency ms)

Row layout:

- Left: short label
- Right: formatted value, monospaced, right-aligned
- Optional: subtle separators or spacing between rows for scanability

### Glassy macOS styling (tray)

Tray “card” and surrounding layout should use:

- Dark translucent background
- `backdrop-blur-xl`
- Thin border with low contrast
- Tight spacing suitable for a tray popup

No new typography decisions beyond the established app defaults:

- UI text uses the primary UI font
- Metric values use monospace

## Technical Design

### Targeted files

- Tray entry: `apps/electron/src/renderer/src/tray.tsx`
  - Force dark class before React render
- Tray UI: `apps/electron/src/renderer/src/views/TrayView.tsx`
  - Replace tray metrics area with list-based layout and glassy container styling adjustments
- Metrics component: `apps/electron/src/renderer/src/components/MetricsGrid.tsx`
  - Either adapt to support a `tray-list` variant or create a dedicated `TrayMetricsList` component for tray-only usage

### Data flow

No changes to IPC or snapshot shape. The tray already receives engine snapshots via the existing `engine:snapshot` pathway and renders from `useEngineSnapshot()`.

## Acceptance Criteria

- Opening the tray popup always renders dark theme, even if the main app is light.
- Tray metrics are shown in a list (one metric per row) with values aligned and readable.
- Tray popup container looks glassy and macOS-like (dark frosted card, subtle border, blur).
- No behavior regressions: tray still toggles reliably and hides on blur.

## Validation

- Manual:
  - Set main app to light mode, then open tray popup and confirm tray is dark.
  - Verify tray metrics update live and are readable at a glance.
  - Confirm glassy styling is visible on both light and dark macOS system backgrounds.
