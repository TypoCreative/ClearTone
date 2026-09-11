#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
architecture="${CLEARTONE_TARGET_ARCH:-$(uname -m)}"
[[ "$architecture" == "x86_64" ]] && architecture="x64"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/apps/macos/native/swift-engine/Resources/Info.plist")"
dmg_path="$project_root/dist/ClearTone-$version-mac-$architecture.dmg"
staging="$(mktemp -d /tmp/cleartone-dmg.XXXXXX)"
temporary_keychain=""

cleanup() {
  rm -rf "$staging"
  if [[ -n "$temporary_keychain" ]]; then
    security delete-keychain "$temporary_keychain" 2>/dev/null || true
  fi
}
trap cleanup EXIT

certificate="$project_root/_dev-id-apple.p12"
if [[ -z "${CLEARTONE_APP_SIGN_IDENTITY:-}" && -f "$certificate" ]]; then
  read -s "certificate_password?Certificate password: "
  echo
  temporary_keychain="$(mktemp -u /tmp/cleartone-signing.XXXXXX).keychain-db"
  keychain_password="$(uuidgen)"
  security create-keychain -p "$keychain_password" "$temporary_keychain"
  security unlock-keychain -p "$keychain_password" "$temporary_keychain"
  security set-keychain-settings -lut 21600 "$temporary_keychain"
  security import "$certificate" -k "$temporary_keychain" -P "$certificate_password" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$temporary_keychain"
  identities="$(security find-identity -v -p codesigning "$temporary_keychain" | sed -n 's/.*"\(.*\)"/\1/p')"
  identity="$(printf '%s\n' "$identities" | grep '^Developer ID Application:' | head -n 1 || true)"
  [[ -z "$identity" ]] && identity="$(printf '%s\n' "$identities" | head -n 1)"
  if [[ -z "$identity" ]]; then
    echo "The .p12 does not contain a valid code-signing identity with its private key." >&2
    exit 1
  fi
  export CLEARTONE_APP_SIGN_IDENTITY="$identity"
  export CLEARTONE_DRIVER_SIGN_IDENTITY="$identity"
fi

"$project_root/scripts/build-driver.sh"
"$project_root/scripts/build-app.sh"
cp -R "$project_root/dist/ClearTone.app" "$staging/ClearTone.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg_path"
hdiutil create -volname ClearTone -srcfolder "$staging" -ov -format UDZO "$dmg_path"
echo "Built $dmg_path"
