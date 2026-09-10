# Architecture Decisions

## Native application

ClearTone uses SwiftUI and AppKit instead of Electron. UI, settings, lifecycle, and
audio coordination run in one process to reduce memory, CPU wakeups, bundle size,
and helper-process count.

## Local real-time processing

Microphone audio remains on the Mac. RNNoise processes fixed 10 ms frames on a
serial CPU queue. The workload is too small and sequential to justify Metal buffer
transfer and dispatch overhead.

## Core Audio virtual microphone

A HAL Audio Server Plug-in exposes cleaned audio to other applications. Installation
requires explicit administrator approval. The app never reports routing as enabled
when the driver is unavailable.

## Explicit automatic routing

Automatic default-input switching occurs only after the user enables Virtual
Microphone. The preference is stored locally; when enabled on a later launch,
ClearTone restores routing and starts processing. Disabling routing or quitting
normally restores the previous physical input when possible.

## Native presentation

The desktop dashboard and menu-bar popup share one app model. Tray Only uses the
macOS accessory activation policy and closes normal desktop windows while preserving
the menu-bar control.

## Distribution

Development builds use ad-hoc signing. Public distribution requires valid Developer
ID identities, signed installer packaging, and notarization. These are distinct
steps and must not be inferred from a successful local build.
