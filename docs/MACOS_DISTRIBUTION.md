# macOS distribution setup

The v0.3.0 downloaded PKG is blocked before Installer runs because it was unsigned
and not notarized. Its nested application used Apple Development. Postinstall
quarantine cleanup cannot run until macOS allows the installer to open.

## Required credentials

An active Apple Developer Program account must supply:

1. **Developer ID Application**, including its private key, to sign the app and HAL driver.
2. **Developer ID Installer**, including its private key, to sign both PKGs.
3. Apple notarization credentials: a stored `notarytool` Keychain profile locally,
   or an App Store Connect API key authorized for notarization in CI.

Apple Development cannot replace either Developer ID certificate. Do not put
passwords, P12 files or P8 keys in source control or chat.

## Local public build

Export the identities to `_dev-id-apple.p12` and `_dev-id-installer.p12`, or select
already installed Keychain identities with `CLEARTONE_APP_SIGN_IDENTITY` and
`CLEARTONE_INSTALLER_SIGN_IDENTITY`. The driver defaults to the app identity.
If importing P12s, set `CLEARTONE_MAC_CERTIFICATE_PASSWORD` and optionally
`CLEARTONE_INSTALLER_CERTIFICATE_PASSWORD` in your local process environment.

Store notarization credentials interactively using Apple's tool:

```bash
xcrun notarytool store-credentials ClearToneNotary
CLEARTONE_NOTARY_PROFILE=ClearToneNotary npm run build
```

Alternatively supply `CLEARTONE_NOTARY_KEY_PATH` and `CLEARTONE_NOTARY_KEY_ID`;
team API keys also require `CLEARTONE_NOTARY_ISSUER_ID`.

## GitHub Actions secrets

| Secret | Value |
| --- | --- |
| `MAC_CSC_LINK` | Base64 Developer ID Application P12 (may also contain Installer identity) |
| `MAC_CSC_KEY_PASSWORD` | P12 password |
| `MAC_INSTALLER_CSC_LINK` | Optional separate base64 Developer ID Installer P12 |
| `MAC_INSTALLER_CSC_KEY_PASSWORD` | Separate Installer P12 password; defaults to app P12 password |
| `MAC_NOTARY_KEY_BASE64` | Base64 App Store Connect P8 private key |
| `MAC_NOTARY_KEY_ID` | API key ID |
| `MAC_NOTARY_ISSUER_ID` | Issuer ID for team keys; omit for individual keys |

Run the workflow on the updated branch for validation before publishing a new
release. The existing v0.3.0 tag continues to reference its original workflow;
rerunning it does not use these fixes. Do not move an already published tag.

## Publication checks

The build notarizes and staples the nested driver installer before embedding it
in ClearTone.app. The final PKG is signed and submitted separately. Only an
`Accepted` response can proceed to stapling. Rejection, timeout, signature failure,
missing credentials or Gatekeeper rejection fails the build and prevents upload.

```bash
pkgutil --check-signature dist/ClearTone-0.3.0-mac-arm64.pkg
xcrun stapler validate dist/ClearTone-0.3.0-mac-arm64.pkg
spctl --assess --type install --verbose=2 dist/ClearTone-0.3.0-mac-arm64.pkg
```

An unsigned local test build is still available through `npm run dist:mac` with
`CLEARTONE_APP_SIGN_IDENTITY=- CLEARTONE_DRIVER_SIGN_IDENTITY=-`. This does not
produce a trusted downloadable installer. No global Gatekeeper setting is changed.

## Current verification boundary

Release gate tests exercise accepted/rejected/timed-out notarization responses
using stubs; they do not claim real Apple acceptance. Live signing, submission,
stapling and downloaded-installer testing require the credentials above. The local
Keychain currently contains only Apple Development; GitHub has only the app P12
secrets, without notarization credentials.

Sources:
- https://developer.apple.com/developer-id/
- https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
