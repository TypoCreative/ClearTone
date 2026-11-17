# macOS distribution

ClearTone 0.3.1 restores DMG distribution. The current account does not have active
Apple Developer Program membership, so the build accepts Apple Development
signing and does not request notarization. It must not be described as verified
by Apple. The previous top-level PKG and its postinstall cleanup are retired.

## Build and release

`npm run build` on macOS uses `_dev-id-apple.p12` or a Keychain identity selected
by `CLEARTONE_APP_SIGN_IDENTITY`. Set `CLEARTONE_MAC_CERTIFICATE_PASSWORD` (also
accepts `MACOS_CERTIFICATE_PASSWORD` or `CSC_KEY_PASSWORD`).

`npm run dist:mac` also supports explicit ad-hoc signing for local checks:

```bash
CLEARTONE_APP_SIGN_IDENTITY=- CLEARTONE_DRIVER_SIGN_IDENTITY=- npm run dist:mac
```

Output: `dist/ClearTone-0.3.2-mac-<arch>.dmg`. It contains only ClearTone.app,
an Applications shortcut and HOW_TO_INSTALL.md. Temporary signing keychains are
stored outside the image staging folder and removed after the build.

GitHub's release-mac-dmg workflow builds arm64 and x64. It uses `MAC_CSC_LINK` and
`MAC_CSC_KEY_PASSWORD`, with legacy `CSC_LINK` / `CSC_KEY_PASSWORD` fallbacks.
Application signature, binary architecture, and mounted DMG contents are checked
before upload. These checks do not imply notarization or Gatekeeper acceptance.

## Installation

See [How to install](HOW_TO_INSTALL_MACOS.md), also included in README and the DMG.
Users can explicitly allow ClearTone through Privacy & Security or remove only
its quarantine attribute in Terminal. No global Gatekeeper setting is changed.
The HAL virtual microphone still uses its embedded driver PKG through Install Driver.

## Future notarized distribution

Removing manual approval requires active Apple Developer Program membership,
Developer ID Application, and Apple notarization. A separately distributed PKG
also needs Developer ID Installer. The current workflow does not provide this.

Sources:
- https://support.apple.com/en-us/102445
- https://developer.apple.com/developer-id/
