# ClearTone Tray UI Update: Dynamic Auto-Resize & Cyber-Minimal Design

## Summary

Update the tray popup UI to automatically resize based on its content (dynamic auto-resize) and apply a "Cyber-Minimal" futuristic design that strictly follows the "no box" and "full black background" constraints.

## Goals

1.  **Auto-Resize:** The Electron `BrowserWindow` for the tray must dynamically adjust its height to exactly fit the React rendered content.
2.  **Futuristic Cyber-Minimal UI:**
    - Strict full black background (`bg-black`).
    - No rounded corners on the outer window (though the OS might enforce slight rounding, our CSS will use `rounded-none`).
    - No "cards" or "boxes" wrapping the sections.
    - Flat layout with cyber/HUD aesthetics: monospace typography, thin neon (cyan) separator lines, and high-contrast glowing text for metrics and status.

## Non-goals

- Refactoring the native Swift engine.
- Changing the layout or theme of the main application window.

## Architecture & Data Flow (Auto-Resize)

To achieve dynamic resizing, we need to establish a new IPC communication channel from the renderer to the main process:

1.  **Main Process (`apps/electron/src/main/index.ts`):**
    - Add an IPC handler for `tray:resize`.
    - When invoked, get the `popupWindow` and call `popupWindow.setContentSize(width, height)`. We will keep the width static (e.g., 340px) and only change the height.
2.  **Preload (`apps/electron/src/preload/index.ts`):**
    - Expose a new function `resizeTray: (height: number) => Promise<void>` in the `clearTone` API.
3.  **Renderer (`apps/electron/src/renderer/src/views/TrayView.tsx`):**
    - Attach a `ref` to the root `<main>` element.
    - Use `ResizeObserver` (within a `useEffect` or `useLayoutEffect`) to monitor the `offsetHeight` of the `<main>` element.
    - When the height changes, call `window.clearTone.resizeTray(height)`.

## UX / UI Design (Cyber-Minimal)

The tray will be a single flat column with distinct, unboxed sections separated by thin glowing lines.

### Container

- Background: `bg-black`.
- Radius: `rounded-none`.
- Padding: `p-4` or `p-3`.
- Text: Default to white/slate.

### Header

- Title: "ClearTone" (perhaps uppercase, tracking wide).
- Status Indicator: A simple glowing dot (cyan for processing, red for error, slate for idle) and minimal uppercase text.
- Toggle Button: A flat, text-based or minimal icon button. No heavy borders.

### Separators

- Thin horizontal lines between sections: `border-b border-cyan-500/20` or similar.

### Controls

- Device Selector & Strength Slider: Render directly on the black background. Remove any wrapping `<Card>` or background colors. Inputs should have minimal underlines or thin borders.

### Metrics

- Layout: List format (already implemented).
- Typography: Label in slate/gray uppercase. Value in bright cyan monospace tabular numbers.
- No background or borders around individual metrics.

## Acceptance Criteria

- Tray window height perfectly matches the UI content (no empty black space at the bottom).
- If an error appears (adding a new section), the window height grows automatically to accommodate it.
- UI is strictly black background, no boxes/cards, with futuristic cyan accents.
- Existing tray functionalities (start/stop, select device, slider) work normally.

## Validation

1.  Open tray popup. Verify it is exactly the height of the content.
2.  Trigger a state change that alters height (e.g., simulate an error or wait for one). Verify the window resizes smoothly without scrollbars.
3.  Verify the visual design meets the "no box, full black, future" criteria.
