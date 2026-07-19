# ClearTone Tray Update: Single Popup Gray-Glassy UI

## Summary

Update the tray experience to use only one custom popup surface and redesign the tray popup so it is easier to read, easier to use, and visually cooler.

## Goals

- Only one tray popup appears when the tray is clicked.
- Remove the confusing native context menu popup from the main tray interaction.
- Use a gray glassy background instead of pure black.
- Make the primary Start/Stop action more readable and more clearly dominant.
- Keep metrics as a list and add light gray separator lines between rows.
- Improve hierarchy, spacing, and contrast so the popup is easier to understand at a glance.

## Non-goals

- Redesigning the main app window.
- Changing engine behavior or snapshot data.

## Interaction Design

### Single popup behavior

- Left click opens the custom tray popup.
- Right click should no longer open a second native context menu popup.
- Secondary actions such as `Show ClearTone` and `Quit` move into the custom tray popup UI so there is still only one visible surface.

## Visual Design

### Background

- The tray popup uses a soft gray glassy shell rather than a pure black flat background.
- The shell should feel futuristic and polished, with subtle blur and soft low-contrast borders.

### Primary action

- The Start/Stop button becomes the clearest primary action in the popup.
- Use stronger contrast, slightly larger visual weight, and clearer readable text.

### Metrics list

- Metrics remain a vertical list.
- Each metric row has a thin light gray separator line for readability.
- Labels should be muted but readable; values should stand out more clearly.

### General readability

- Improve spacing between header, controls, metrics, and footer actions.
- Keep typography simple and high-contrast.
- Maintain a cool futuristic look without sacrificing usability.

## Implementation Notes

- Main process: stop showing the native tray context menu on right click.
- Preload and renderer: add actions for `Show ClearTone` and `Quit` inside the custom popup if needed.
- Renderer tray view: reintroduce a structured layout with a gray glassy surface and readable CTA.
- Metrics renderer: add divider lines and clearer hierarchy for tray rows.

## Acceptance Criteria

- Clicking the tray results in only one popup surface.
- The popup background feels gray and glassy, not black and flat.
- The Start/Stop action is easy to find and easy to read.
- Metrics are displayed as a list with light gray separators.
- The popup feels more understandable and more polished overall.
