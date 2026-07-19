# ClearTone Tray Popup Design

## Summary

This design upgrades ClearTone from a tray menu only experience to a tray icon
plus mini popup control surface.

The popup is intended to provide a faster and more useful interaction model than
a plain tray list. Instead of relying only on menu items, the user can click the
tray icon and open a small floating control window for quick actions.

## Goals

- Replace tray-only interaction with a more useful mini popup design
- Make the tray interaction faster and easier to understand
- Provide quick access to the most important controls without opening the full app
- Keep the popup synchronized with the main window and shared engine state

## Non-Goals

- Replacing the full desktop window entirely
- Rebuilding the full dashboard inside the popup
- Adding advanced diagnostics or large metrics views inside the popup

## Popup Purpose

The tray popup is a compact control surface for frequent actions.

It should be used for:

- turning processing on
- turning processing off
- selecting the active device
- adjusting denoise strength
- checking short status text

The full desktop window still exists for broader control, richer layout, and
larger metrics visibility.

## Popup Content

The popup contains:

- `Start`
- `Stop`
- device selector
- denoise strength slider
- short status text

The popup should not include the full metrics row or all extended app content.
It should stay small and focused.

## Popup Layout

The popup should be arranged for fast scanning and minimal friction.

Recommended structure:

- header with app name and short status
- compact action row for `Start` and `Stop`
- device selector below actions
- denoise strength slider below device selector

The overall visual layout should feel like a miniature quick-control panel.

## Popup Styling

The popup should follow the approved ClearTone redesign direction:

- simpler, more useful presentation
- `Comic Sans MS` across the interface
- use the existing ClearTone color palette
- maintain strong readability and spacing

The popup should feel visually related to the main app, but lighter and more
compact.

## Tray Interaction Model

### Tray Click

Clicking the tray icon should open the popup.

If the popup is already visible, clicking the tray icon may hide it.

### Outside Click

If practical in the implementation, clicking outside the popup should dismiss
the popup to preserve a quick utility feel.

### Fallback Menu

The tray should still support a minimal context menu for actions that make sense
outside the popup.

Keep:

- `Show ClearTone`
- `Quit`

Optional fallback controls can remain available if implementation needs them,
but the primary quick-control path should be the popup.

## Main Window Relationship

The main ClearTone window remains the full application surface.

The tray popup does not replace it.

The main window should still be used for:

- larger layout
- broader visibility of state
- future richer metrics and settings

## Shared State Rules

The tray popup, tray behavior, and main window must all use the same engine
state.

That means:

- popup reflects the active engine phase
- popup reflects the selected input
- popup reflects the current denoise strength
- popup actions update the full app state
- changes from the main window update the popup

No separate popup-only state model should be introduced for these controls.

## Interaction Rules

### Start And Stop

- `Start` is disabled when already processing or starting
- `Stop` is enabled only while starting or processing
- status text should always explain the current state clearly

### Device Selector

- if no devices are available, show a clear empty state
- selected device must stay synchronized with the main window

### Strength Slider

- slider value always reflects current denoise strength
- changes update the same engine command surface already used in the app

## Electron Shape

### Tray

The tray remains a standard Electron `Tray` instance using the approved
tray-safe icon.

### Popup Window

The popup should be implemented as a separate small `BrowserWindow`.

Recommended traits:

- frameless
- compact
- utility-style
- not shown in task switching as a full independent app window if avoidable

### Positioning

The popup should appear near the tray icon or in a natural tray-adjacent
position on macOS.

Precise positioning can be adapted to Electron and operating system behavior,
but the user experience goal is a tray-attached feel.

## Renderer Shape

The popup renderer should be a compact view rather than a duplicate of the full
main page.

It may reuse shared state and IPC, but it should have its own small layout
focused on quick actions.

## Acceptance Criteria

This tray popup feature is complete when:

- clicking the tray icon opens a mini popup instead of relying only on a list
- the popup shows `Start`, `Stop`, device select, denoise strength, and status
- the popup uses the approved ClearTone visual direction
- popup state stays synchronized with the main window and engine
- `Show ClearTone` and `Quit` remain available from tray behavior

## Follow-On Work

Possible later improvements:

- optional compact metrics inside the popup
- outside-click dismissal refinements
- better popup animation and transition polish
- tray status color or label refinements
