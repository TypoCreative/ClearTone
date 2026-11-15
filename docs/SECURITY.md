# ClearTone dependency and security review

Reviewed 2026-11-15. This is a scoped source/build review, not a guarantee that the
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
