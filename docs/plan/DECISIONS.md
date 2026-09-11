# Architecture Decisions

## Platform roots

All application-specific source now lives under exactly two platform roots:
`apps/macos` and `apps/windows`. Root scripts remain only as macOS-compatible entry
points so existing contributor commands continue to work.

## Native UI and audio stacks

macOS keeps SwiftUI/AppKit and AVAudioEngine/Core Audio. Windows uses Win32 and
WASAPI rather than Electron, keeping memory, startup overhead, and process count
small. Windows 11 Mica is requested when available and falls back safely on older
supported Windows versions.

## Shared suppression model

Windows CMake compiles the vendored RNNoise source already used by SwiftPM. This
avoids two neural weight copies and keeps the core 10 ms suppression stage aligned.
Platform-specific finishing remains separate until cross-platform listening tests
justify matching it.

## Windows routing boundary

The unsigned Windows release outputs through WASAPI. It does not pretend to expose
a first-party virtual microphone. Production kernel endpoints require WDK work and
Microsoft-approved signing; users who need call-app routing select an existing
virtual audio cable as ClearTone's playback endpoint.

## Signing policy

Windows application code signing and Microsoft driver signing are explicitly out
of scope. CI verifies `ClearTone.exe` is `NotSigned`. macOS signing behavior is
unchanged because removing Windows signing does not authorize weakening macOS
release requirements.
