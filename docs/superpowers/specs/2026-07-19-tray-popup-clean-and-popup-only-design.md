# ClearTone — Tray Popup Clean UI + Popup-Only Tray Behavior Design

## Summary

Adjust the tray interaction and tray popup UI to remove the system context menu and deliver a cleaner, more effective custom popover.

## Goals

- Ensure there is only one tray interaction surface:
  - The custom-designed tray popup window
  - No macOS system context menu (no “Status / Show / Quit” menu)
- Improve tray popup UI cleanliness and efficiency:
  - Compact layout, no unnecessary empty space
  - No scrollbars in normal state
  - Single toggle button for Start/Stop
- Keep functionality identical to the main app:
  - Start/Stop processing
  - Device selection / follow system input
  - Strength adjustment
  - Live metrics display

## Non-Goals

- Removing the full app window.
- Introducing a menu-only tray UX.
- Adding advanced settings into the tray popup.

## Tray Interaction Behavior

- Tray icon click behavior:
  - Left-click: toggle the custom tray popup window
  - Right-click: toggle the custom tray popup window
- Remove system context menu entirely:
  - Do not set a tray context menu
  - Do not show a default menu on right-click

## Tray Popup Window

- Size: 360×360
- Behavior:
  - Frameless, always-on-top, skip taskbar
  - Auto-close on blur (click outside)
  - Positioned near tray icon (existing positioning logic)

## Tray Popup UI (Clean Layout)

### Layout

- Header (compact):
  - “ClearTone Mini”
  - Current input name (or “No microphone”)
  - Status shown via color/phase styling (no explicit ON/OFF text)
- Primary control:
  - Single large toggle button
    - Shows “Start” when not processing
    - Shows “Stop” when processing
- Controls:
  - Device selector (includes “Follow system input” option)
  - Strength slider
- Metrics (2×2 grid):
  - Input RMS
  - Output RMS
  - Noise Reduction %
  - Latency (ms)

### Visual Style

- Typography: Comic Sans MS (project standard)
- Spacing:
  - Reduced padding vs full app
  - Tight vertical rhythm and compact metric cards
- Avoid large decorative elements that add height without adding utility.

## Implementation Notes

- Renderer:
  - Continue to use `#tray-popup` to render the tray UI.
  - Replace the dual Start/Stop buttons inside the tray view with a single toggle button.
- Main process:
  - Ensure no context menu is assigned to the tray.
  - Ensure right-click does not invoke a menu.
  - Update popup window dimensions to 360×360.

## Verification Checklist

- Right-clicking the tray icon does not show any system menu.
- Left-click and right-click both toggle the custom tray popup.
- Tray popup window size is 360×360 and has no scrollbars under normal content.
- Tray popup Start/Stop is a single toggle button and controls the engine correctly.
- Device selection and strength changes work from the tray popup.
- Tray popup metrics update live: Input RMS, Output RMS, Noise Reduction %, Latency.

