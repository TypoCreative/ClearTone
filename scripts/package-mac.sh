#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
architecture="${CLEARTONE_TARGET_ARCH:-$(uname -m)}"
[[ "$architecture" == "x86_64" ]] && architecture="x64"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/apps/macos/native/swift-engine/Resources/Info.plist")"
dmg_path="$project_root/dist/ClearTone-$version-mac-$architecture.dmg"
staging="$(mktemp -d /tmp/cleartone-dmg.XXXXXX)"
temporary_keychain=""
original_keychains=()

cleanup() {
  if [[ -n "$temporary_keychain" ]]; then
    if (( ${#original_keychains[@]} > 0 )); then
      security list-keychains -d user -s "${original_keychains[@]}" 2>/dev/null || true
    fi
    security delete-keychain "$temporary_keychain" 2>/dev/null || true
  fi
  rm -rf "$staging"
}
trap cleanup EXIT

certificate="$project_root/_dev-id-apple.p12"
if [[ -z "${CLEARTONE_APP_SIGN_IDENTITY:-}" && -f "$certificate" ]]; then
  certificate_password="${CLEARTONE_MAC_CERTIFICATE_PASSWORD:-${CSC_KEY_PASSWORD:-}}"
  if [[ -z "$certificate_password" ]]; then
    read -s "certificate_password?Certificate password: "
    echo
  fi
  temporary_keychain="$staging/cleartone-signing.keychain-db"
  keychain_password="$(uuidgen)"
  while IFS= read -r existing_keychain; do
    existing_keychain="${existing_keychain//\"/}"
    existing_keychain="$(printf '%s' "$existing_keychain" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$existing_keychain" ]] && original_keychains+=("$existing_keychain")
  done < <(security list-keychains -d user)
  security create-keychain -p "$keychain_password" "$temporary_keychain"
  security unlock-keychain -p "$keychain_password" "$temporary_keychain"
  security set-keychain-settings -lut 21600 "$temporary_keychain"
  security import "$certificate" -k "$temporary_keychain" -P "$certificate_password" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$temporary_keychain" >/dev/null
  identities="$(security find-identity -v -p codesigning "$temporary_keychain" | sed -n 's/.*"\(.*\)"/\1/p')"
  identity="$(printf '%s\n' "$identities" | grep '^Developer ID Application:' | head -n 1 || true)"
  if [[ -z "$identity" && "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" != "1" ]]; then
    identity="$(printf '%s\n' "$identities" | head -n 1)"
  fi
  if [[ -z "$identity" ]]; then
    echo "The .p12 does not contain a valid Developer ID Application identity with its private key." >&2
    exit 1
  fi
  if [[ "$identity" == Apple\ Development:* ]]; then
    echo "Using Apple Development identity for a local signed build. This artifact is not for public distribution."
  fi
  export CLEARTONE_APP_SIGN_IDENTITY="$identity"
  export CLEARTONE_DRIVER_SIGN_IDENTITY="$identity"

  installer_identity="$(security find-identity -v -p basic "$temporary_keychain" | sed -n 's/.*"\(Developer ID Installer:.*\)"/\1/p' | head -n 1 || true)"
  if [[ -n "$installer_identity" ]]; then
    export CLEARTONE_INSTALLER_SIGN_IDENTITY="$installer_identity"
  fi
fi

if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" && "${CLEARTONE_APP_SIGN_IDENTITY:-}" != "Developer ID Application:"* ]]; then
  echo "A Developer ID Application identity is required for a signed macOS release." >&2
  exit 1
fi

"$project_root/scripts/build-driver.sh"
"$project_root/scripts/build-app.sh"
cp -R "$project_root/dist/ClearTone.app" "$staging/ClearTone.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg_path"
hdiutil create -volname ClearTone -srcfolder "$staging" -ov -format UDZO "$dmg_path"
if [[ -n "${CLEARTONE_APP_SIGN_IDENTITY:-}" && "$CLEARTONE_APP_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$CLEARTONE_APP_SIGN_IDENTITY" "$dmg_path"
  codesign --verify --strict --verbose=2 "$dmg_path"
  codesign --verify --deep --strict --verbose=2 "$project_root/dist/ClearTone.app"
fi
echo "Built $dmg_path"
