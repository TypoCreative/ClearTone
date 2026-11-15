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

The Windows application outputs through WASAPI. It does not pretend to expose
a first-party virtual microphone. Production kernel endpoints require WDK work and
Microsoft-approved signing; users who need call-app routing select an existing
virtual audio cable as ClearTone's playback endpoint.

## Signing policy

Quality CI verifies its temporary `ClearTone.exe` is `NotSigned`, keeping pull
requests independent of secrets. Release CI requires Authenticode application
signing and verifies status `Valid` before packaging. The release ZIP is attached
directly to the GitHub Release so Actions artifact quota cannot block publishing.
Microsoft driver signing is still out of scope because ClearTone does not ship a
Windows kernel driver.

Both release workflows call `npm run build`. The OS-aware Node entry point uses
the root `_dev-id-apple.p12` on macOS, requests a hidden password for local builds,
and delegates to native platform tools. GitHub reconstructs that ignored file from
the base64 `CSC_LINK` secret and removes it with an `always()` cleanup step. macOS
accepts the current Apple Development identity locally and in GitHub so both paths
behave consistently. These builds are not notarized and require manual
approval, documented in README, release notes and the DMG install guide. macOS
releases use DMG drag-and-drop installation again; there is no top-level PKG or
postinstall quarantine cleanup. The HAL driver retains its embedded PKG.
