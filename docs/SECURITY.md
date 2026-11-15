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

## Installer safeguards and verification boundary

The PKG installs `/Applications/ClearTone.app` on the selected volume. App bundle
relocation is disabled. Preinstall rejects symlink destinations; postinstall checks
the bundle identifier and code signature before removing only `com.apple.quarantine`.
Failures propagate to Installer. No global Gatekeeper setting is changed.

Local verification uses an ad-hoc app signature and unsigned PKG. Installing with
administrator privileges, signing with distribution identities, notarization,
Windows execution, and testing downloaded installers on another Mac remain separate
verification steps. Quarantine removal cannot make an untrusted downloaded PKG
pass Gatekeeper before its installation scripts can run.

Apple distribution requirements:
https://developer.apple.com/developer-id/
https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

## Public installer correction

The public build now requires Developer ID Application and Developer ID Installer,
notarizes/staples the embedded driver PKG and final app PKG, and requires Gatekeeper
acceptance before upload. Apple Development is rejected for public builds.
`tests/test_macos_distribution.py` exercises failure gates with stubbed Apple tools;
real notarization remains unverified until distribution credentials are configured.
See `MACOS_DISTRIBUTION.md` for setup and the limitations of existing v0.3.0 assets.
