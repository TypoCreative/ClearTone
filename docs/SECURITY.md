# ClearTone dependency and security review

Reviewed 2026-11-17. This is a scoped source/build review, not a guarantee that the
application contains no security vulnerabilities.

## Dependency inventory

- npm: no external packages; `npm audit` reports zero known vulnerabilities and
  `npm outdated` reports no available package updates.
- SwiftPM: no remote dependencies. Apple frameworks come from the installed SDK.
- Windows: platform SDK libraries and the same vendored RNNoise C code.
- RNNoise: source files matched Xiph upstream commit
  `70f1d256acd4b34a572f999a05c87bf00b67730d` before local hardening.
  No source version bump was needed. Generated model files are retained.
  Upstream: https://github.com/xiph/rnnoise
- CI: checkout v7.0.1, setup-node v7 and action-gh-release v3 resolved to full
  commit IDs, preventing tag movement from silently changing build dependencies.

## Local RNNoise hardening

- Initialize file ownership for buffer models before freeing them.
- Reject missing/empty/oversized model files, null buffers, and allocation failures.
- Preserve the caller's file ownership on model-loading failure.
- Handle weight-list allocation/reallocation failures without losing the old pointer.
- Reject unaligned/truncated records, missing sparse arrays, negative sparse block
  counts/indices, overflowing counts, and invalid sparse output dimensions.

`tests/rnnoise-security.c` covers invalid model APIs, malformed records, sparse
index errors, and ordinary built-in inference. macOS runs it with ASan and UBSan;
Windows CTest runs the same assertions, including in Release builds.

## DMG distribution and verification boundary

ClearTone 0.3.1 returns to drag-and-drop DMG distribution. The current build is
not notarized and can require explicit approval in Privacy & Security. The scoped
Terminal alternative removes only `com.apple.quarantine` from ClearTone.app.
No global Gatekeeper setting is changed. The old top-level PKG postinstall scripts
and mandatory-notarization workflow are retired; they could not make an installer
open before its first Gatekeeper check.

DMG staging contains the app, an Applications shortcut, and the install guide.
Temporary signing keychains remain outside the staged disk image. CI checks the
mounted contents, app signature and binary architecture before upload. Real
microphone permission prompts and manual approval on another Mac remain user checks.
The app's HAL driver still uses an embedded PKG installer.

See [macOS distribution](MACOS_DISTRIBUTION.md) and
[How to install](HOW_TO_INSTALL_MACOS.md).

## macOS runtime review (2026-11-17)

Reviewed capture startup/cancellation, device selection, converter ownership,
RNNoise input handling, virtual-output buffer lifecycle, app termination,
permissions/entitlements, build scripts and CI. The open GitHub issue list was
empty at review time; this review therefore also examined source failure paths.

Changes:

- Ask for microphone permission before treating an empty discovery result as a
  permanent failure. Discover devices again after permission is granted.
- Only select a default UID that is in the currently available physical inputs.
- Keep startup cancellable; the existing generation token invalidates delayed
  retries and permission callbacks after cancellation.
- Restart capture when a configuration notification reports a stopped engine.
- Confine converter/scratch storage to each tap instead of sharing mutable storage
  across capture sessions.
- Drain output work before stopping the player. Ignore completion callbacks from
  retired output-buffer generations and metric updates from retired sessions.
- Replace non-finite capture samples with zero and clamp out-of-range normalized
  PCM before inference, preventing invalid device data from poisoning DSP state.
- Open driver installers only from app bundle resources. The old working-directory
  fallback could select an unrelated installer from the launch directory.
- Stop capture and invalidate pending starts when the app terminates.
- Remove Windows quality/release jobs; retain local Windows source and scripts.

Verification includes Swift regression tests, RNNoise ASan/UBSan checks,
`npm audit --audit-level=low`, and a signed local release-app build. No npm
vulnerabilities were reported. This does not establish that all native code is
free from vulnerabilities; the HAL driver is not covered by the RNNoise sanitizer
harness. Permission prompts, sleep/wake, Bluetooth/USB reconnection and playback
in conferencing apps require interactive hardware testing. The packaged app
remains unnotarized; this review does not change its distribution trust status.
