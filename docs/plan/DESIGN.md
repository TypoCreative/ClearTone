# Design System

ClearTone uses native platform controls and the existing ClearTone icon/logo.
Neither platform ships a web renderer or custom-font dependency.

## Shared hierarchy

1. Voice Engine: obvious start/stop action and readable state.
2. Audio Routing: physical/default input → Voice Engine → platform output.
3. Audio Setup: strength and device/profile controls supported by that platform.
4. Live Metrics: compact levels and processing health.

Status must not rely on color alone. Errors remain visible in text, controls keep
keyboard focus, metrics avoid rapid announcements, and decorative visuals are
excluded from accessibility semantics.

## macOS

The current SwiftUI dashboard keeps its two-column glass card layout, system fonts,
VoiceOver labels, scalable controls, and monochrome 16 pt menu-bar symbol in an
18 × 18 pt frame. The original `.icns` remains unchanged.

## Windows

The Windows window uses Segoe UI Variable, a dark low-distraction canvas, native
controls, standard tab navigation, high-DPI awareness, and Windows 11 Mica where
supported. The system-tray icon is a multi-resolution `.ico` generated from the
existing ClearTone PNG; the logo artwork itself is unchanged.
