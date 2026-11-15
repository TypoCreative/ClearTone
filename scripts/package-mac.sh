#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
architecture="${CLEARTONE_TARGET_ARCH:-$(uname -m)}"
[[ "$architecture" == "x86_64" ]] && architecture="x64"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/apps/macos/native/swift-engine/Resources/Info.plist")"
pkg_path="$project_root/dist/ClearTone-$version-mac-$architecture.pkg"
workspace="$(mktemp -d /tmp/cleartone-pkg.XXXXXX)"
package_root="$workspace/package-root"
temporary_keychain=""
original_keychains=()

cleanup() {
  if [[ -n "$temporary_keychain" ]]; then
    if (( ${#original_keychains[@]} > 0 )); then
      security list-keychains -d user -s "${original_keychains[@]}" 2>/dev/null || true
    fi
    security delete-keychain "$temporary_keychain" 2>/dev/null || true
  fi
  rm -rf "$workspace"
}
trap cleanup EXIT

if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" ]]; then
  "$project_root/scripts/notarize-mac.sh" --check
fi

certificate="$project_root/_dev-id-apple.p12"
if [[ -z "${CLEARTONE_APP_SIGN_IDENTITY:-}" && -f "$certificate" ]]; then
  certificate_password="${CLEARTONE_MAC_CERTIFICATE_PASSWORD:-${MACOS_CERTIFICATE_PASSWORD:-${CSC_KEY_PASSWORD:-}}}"
  if [[ -z "$certificate_password" ]]; then
    read -s "certificate_password?Certificate password: "
    echo
  fi
  temporary_keychain="$workspace/cleartone-signing.keychain-db"
  keychain_password="$(uuidgen)"
  while IFS= read -r existing_keychain; do
    existing_keychain="${existing_keychain//\"/}"
    existing_keychain="$(printf '%s' "$existing_keychain" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$existing_keychain" ]] && original_keychains+=("$existing_keychain")
  done < <(security list-keychains -d user)
  security create-keychain -p "$keychain_password" "$temporary_keychain"
  security unlock-keychain -p "$keychain_password" "$temporary_keychain"
  security list-keychains -d user -s "$temporary_keychain" "${original_keychains[@]}"
  security set-keychain-settings -lut 21600 "$temporary_keychain"
  security import "$certificate" -k "$temporary_keychain" -P "$certificate_password" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$temporary_keychain" >/dev/null
  # An Installer identity can be supplied separately or in the application P12.
  installer_certificate="${CLEARTONE_INSTALLER_CERTIFICATE_PATH:-$project_root/_dev-id-installer.p12}"
  if [[ -f "$installer_certificate" ]]; then
    installer_password="${CLEARTONE_INSTALLER_CERTIFICATE_PASSWORD:-$certificate_password}"
    security import "$installer_certificate" -k "$temporary_keychain" -P "$installer_password" -T /usr/bin/productsign -T /usr/bin/pkgbuild
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$temporary_keychain" >/dev/null
  fi
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

if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" && "${CLEARTONE_INSTALLER_SIGN_IDENTITY:-}" != "Developer ID Installer:"* ]]; then
  echo "A Developer ID Installer identity is required for a signed macOS release." >&2
  exit 1
fi

if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" ]]; then
  export CLEARTONE_DRIVER_SIGN_IDENTITY="${CLEARTONE_DRIVER_SIGN_IDENTITY:-$CLEARTONE_APP_SIGN_IDENTITY}"
  if [[ "$CLEARTONE_DRIVER_SIGN_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "The HAL driver also requires a Developer ID Application identity." >&2
    exit 1
  fi
fi

"$project_root/scripts/build-driver.sh"
if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" ]]; then
  # Staple the driver installer before embedding it, so later driver installation
  # also has a ticket when offline.
  "$project_root/scripts/notarize-mac.sh" "$project_root/apps/macos/native/swift-engine/Resources/driver/ClearToneVirtualMicrophone.pkg" --assess
fi
"$project_root/scripts/build-app.sh"
mkdir -p "$package_root/Applications"
COPYFILE_DISABLE=1 cp -R "$project_root/dist/ClearTone.app" "$package_root/Applications/ClearTone.app"
rm -f "$pkg_path"
# Prevent Installer from relocating/upgrading a different copy of ClearTone.
pkgbuild --analyze --root "$package_root" "$workspace/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$workspace/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleHasStrictIdentifier true' "$workspace/components.plist"

package_arguments=(
  --root "$package_root"
  --component-plist "$workspace/components.plist"
  --identifier com.typocreative.cleartone.installer
  --version "$version"
  --install-location /
  --scripts "$project_root/scripts/macos-pkg-scripts"
)
if [[ -n "${CLEARTONE_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  package_arguments+=(--sign "$CLEARTONE_INSTALLER_SIGN_IDENTITY" --timestamp)
fi
pkgbuild "${package_arguments[@]}" "$pkg_path"

pkgutil --payload-files "$pkg_path" | grep -q '^\./Applications/ClearTone.app/Contents/MacOS/ClearTone$'
if [[ -n "${CLEARTONE_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  pkgutil --check-signature "$pkg_path"
else
  echo "Installer package is unsigned. Add a Developer ID Installer identity for public distribution."
fi
if [[ -n "${CLEARTONE_APP_SIGN_IDENTITY:-}" && "$CLEARTONE_APP_SIGN_IDENTITY" != "-" ]]; then
  codesign --verify --deep --strict --verbose=2 "$project_root/dist/ClearTone.app"
fi
if [[ "${CLEARTONE_REQUIRE_DEVELOPER_ID:-0}" == "1" ]]; then
  "$project_root/scripts/notarize-mac.sh" "$pkg_path" --assess
fi
echo "Built $pkg_path"
