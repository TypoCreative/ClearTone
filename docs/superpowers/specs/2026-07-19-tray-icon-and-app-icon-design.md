# ClearTone Tray Icon And App Icon Design

## Summary

This design introduces a proper tray icon setup for ClearTone and standardizes
icon usage around a single approved source image:

- source asset: `apps/electron/src/assets/icon_tray_sound.png`
- derived asset: a tray-safe icon generated from the source artwork

The goal is to make the tray icon visible and readable in the macOS menu bar
while keeping one visual identity across tray and app window icon usage.

## Goals

- Make the tray icon visible in the macOS menu bar
- Reuse the provided waveform PNG as the source for all icon usage
- Apply the icon consistently to the app window and tray
- Keep tray behavior aligned with the approved quick-control design

## Non-Goals

- Full packaging icon generation for every distribution target
- Rebranding the waveform artwork itself
- Creating multiple unrelated icon families

## Source Asset

The approved source icon is:

- `apps/electron/src/assets/icon_tray_sound.png`

This file remains the visual source of truth.

## Derived Tray Icon

### Why A Derived Icon Is Needed

The current source artwork is a wide waveform image. It does not naturally fit
the small square or near-square display area used by the macOS tray.

If used directly, the tray icon may:

- appear too small
- lose visibility
- look cropped poorly
- fail to read clearly in the menu bar

### Tray-Safe Derivation Rules

The tray icon should be derived from the same waveform artwork with adjustments
for tray readability:

- fit the waveform into a tray-friendly square canvas
- preserve transparency
- keep the waveform bright and high contrast
- avoid excessive empty horizontal space
- remain recognizable at small size

The derived icon should still feel like the same ClearTone symbol, not a new
brand mark.

## Icon Usage Rules

### Tray Icon

The tray icon must use the derived tray-safe asset.

This derived icon is the default icon for:

- Electron `Tray`

### App And Window Icon

The app window should use the approved source asset family.

For the current implementation stage, the main window icon should use the source
PNG or the closest practical asset derived from it.

This applies to:

- `BrowserWindow` icon configuration

### Future Packaging Direction

If app packaging icons are added later, they should also be generated from the
same source waveform family so the app remains visually consistent.

## Tray Behavior

### Tray Purpose

The tray is a quick-control surface for ClearTone when the main window is hidden
or not in focus.

### Tray Menu

The tray menu should include:

- status item showing `On` or `Off`
- `Start`
- `Stop`
- `Select Device` submenu
- `Show ClearTone`
- `Quit`

### Tray Window Interaction

The tray should be able to restore the main window quickly.

The app should remain useful through the tray even when the window is not
visible.

## Shared State Rules

Tray actions and renderer actions must use the same engine state.

That means:

- tray status updates when engine state changes
- tray device selection updates the main window selection
- starting or stopping from tray updates the renderer immediately

## Implementation Shape

### Assets

The codebase should contain:

- the original source PNG
- one derived tray-safe asset near the source asset

The derived icon file should live alongside the current icon asset so icon usage
is easy to maintain.

### Electron Main

Electron main should:

- load the tray-safe derived icon for `Tray`
- load the source family icon for `BrowserWindow`
- build the tray menu from the current engine snapshot
- keep tray and window actions synchronized

### Menu Refresh

The tray menu should be rebuilt or refreshed whenever relevant engine state
changes:

- engine phase
- selected input
- available device list

## Acceptance Criteria

This icon and tray update is complete when:

- the tray icon is visibly shown in macOS
- the tray icon is derived from `icon_tray_sound.png`
- the main window icon uses the approved icon family
- the tray menu provides start, stop, device selection, show window, and quit
- tray actions and window state remain synchronized

## Follow-On Work

Later icon improvements may include:

- packaged app icon generation for macOS formats
- dark-mode tuned tray variants if needed
- higher-resolution distribution assets from the same waveform family
