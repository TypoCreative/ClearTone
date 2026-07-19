# ClearTone UI Redesign And Tray Design

## Summary

This design updates the current ClearTone desktop UI to be easier to
understand, easier to use, and more utility-focused.

The new direction removes the current multi-panel artistic presentation and
replaces it with a simpler dashboard layout:

- one top row for primary controls and settings
- one bottom row for engine metrics
- a system tray menu for fast on or off control and device selection

This redesign also changes the app typography to `Comic Sans MS` everywhere in
the interface, based on the approved user request.

## Goals

- Make the desktop UI more useful and immediately understandable
- Reduce decorative layout complexity and focus on task clarity
- Support quick control from the system tray without opening the main window
- Keep the main controls aligned to the user's requested two-row structure
- Keep the main window and tray state synchronized through the same engine state

## Non-Goals

- Redesigning the Swift engine or native processing pipeline
- Expanding into a multi-page preferences application
- Adding onboarding, tutorials, or setup wizards
- Adding advanced tray diagnostics or waveform visualizations

## Approved Structure

### Top Row

The top row is split into two parts.

#### Left Side

The left side contains only the main processing actions:

- large `Start` button
- large `Stop` button
- short engine status text

This area must feel obvious at a glance. The user should not need to search for
the primary action.

#### Right Side

The right side is a vertical column with:

- `Select Device`
- `Denoise Strength`

The control column should be compact and easy to scan. It should not compete
with the start and stop actions visually.

### Bottom Row

The second row is a full-width metrics section.

It displays:

- engine phase or status
- microphone permission state
- processed frames
- input level
- estimated latency

Metrics should be presented as simple labeled values. This row should feel like
a readable status strip rather than a decorative analytics dashboard.

## Visual Direction

### Typography

The entire interface uses `Comic Sans MS`.

This includes:

- headings
- labels
- buttons
- dropdowns
- metrics
- helper text

If `Comic Sans MS` is not available, the fallback should be a common sans-serif
font, but the intended primary face is `Comic Sans MS`.

### Style Tone

The UI should still respect the color palette from `DESIGN.md`, but the overall
composition should be simpler and more functional.

Use:

- primary blue for main actions
- secondary purple for emphasis and subtle accents
- green for active or healthy processing state
- orange for warnings
- red for errors
- white or near-white surfaces for clarity

The redesign should feel like a useful desktop tool first and a stylized visual
system second.

### Layout Feel

The current hero-style presentation should be reduced.

The new layout should:

- remove unnecessary promotional copy
- reduce oversized decorative sections
- increase readability of controls
- use larger spacing between the main action area, settings column, and metrics
- keep corners and shadows soft but restrained

## Renderer Design

### Main Header

The main header becomes lighter and clearer.

It contains:

- app name
- short status sentence

It should not dominate the window. The main focus must be the functional
controls below it.

### Primary Action Panel

The left section of the top row contains:

- `Start`
- `Stop`
- a short current status message
- inline error feedback if present

The buttons should be visually large, clear, and easy to click.

### Settings Column

The right section of the top row contains:

- input device selector
- denoise strength slider

The selector and slider should be stacked vertically with clear labels and
enough spacing to avoid confusion.

### Metrics Row

The bottom row spans the available width and shows all key engine metrics in one
horizontal group.

Each metric block should contain:

- label
- value

This row should be easy to scan quickly during live use.

## Tray Design

### Tray Purpose

The tray exists to make ClearTone useful even when the main window is hidden.

It is intended for:

- quick start
- quick stop
- quick device selection
- bringing the app window back into view

### Tray Menu

The tray menu should include:

- current status item showing `On` or `Off`
- `Start`
- `Stop`
- `Select Device` submenu
- `Show ClearTone`
- `Quit`

### Device Submenu

The tray device submenu should list all known microphone inputs.

The currently selected device should be visible in the tray menu state.

Choosing a device from the tray should:

- update the shared app state
- update the renderer selection if the window is open
- affect the next processing start or the active engine selection logic if
  supported

### Tray And Window Sync

The tray and renderer must both reflect the same engine snapshot.

That means:

- tray status changes when engine phase changes
- renderer updates when tray actions trigger start or stop
- selected input remains consistent between tray and window

## Interaction Rules

### Start And Stop

- `Start` is disabled while starting or already processing
- `Stop` is enabled only when processing is active or transitioning
- status text must always explain the current engine state

### Device Selection

- if no input devices are available, the selector shows a clear empty state
- if a selected device disappears, the app should show a useful error or status
- tray and window should both recover cleanly after device refresh

### Strength Adjustment

- the slider always shows the active denoise strength
- the value should be visually obvious
- changing the slider updates the engine through the existing bridge

## Error Handling

Errors should be shown clearly near the main controls instead of in distant or
decorative panels.

Priority errors include:

- microphone permission denied
- no microphone devices
- selected device disconnected
- native engine unavailable
- bridge connection failure

The tray should also remain safe when errors happen:

- disable invalid actions when needed
- preserve `Show ClearTone` and `Quit`

## Implementation Shape

### Renderer Changes

The current renderer should be restructured into:

- simpler header
- top row split layout
- bottom metrics row

The previous third utility panel should be removed from the main composition.

### Electron Main Changes

Electron main should create and manage a tray instance.

It must:

- build a menu from current engine state
- expose quick start and stop actions
- expose device selection submenu items
- show the main window on demand
- quit the app cleanly

### Shared State

No separate state model should be introduced for tray behavior.

Tray state should derive from the same engine snapshot already used by the
renderer and IPC handlers.

## Acceptance Criteria

This redesign is complete when:

- the app uses `Comic Sans MS` across the interface
- the main window follows the approved two-row layout
- the top row places `Start` and `Stop` on the left
- the top row places `Select Device` and `Denoise Strength` in a right column
- the bottom row shows engine metrics across the width
- the tray supports start, stop, device selection, show window, and quit
- tray and renderer stay synchronized with the same engine state

## Follow-On Work

After this redesign ships, the next likely UX improvements are:

- optional compact mode
- richer tray status labels
- better permission guidance
- preset profiles for common environments
