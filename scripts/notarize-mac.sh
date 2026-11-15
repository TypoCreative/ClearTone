#!/bin/zsh
set -euo pipefail

# Use a stored Keychain profile locally or an App Store Connect API key in CI.
notary_arguments=()
if [[ -n "${CLEARTONE_NOTARY_PROFILE:-}" ]]; then
  notary_arguments=(--keychain-profile "$CLEARTONE_NOTARY_PROFILE")
elif [[ -n "${CLEARTONE_NOTARY_KEY_PATH:-}" && -f "$CLEARTONE_NOTARY_KEY_PATH" && -n "${CLEARTONE_NOTARY_KEY_ID:-}" ]]; then
  notary_arguments=(--key "$CLEARTONE_NOTARY_KEY_PATH" --key-id "$CLEARTONE_NOTARY_KEY_ID")
  if [[ -n "${CLEARTONE_NOTARY_ISSUER_ID:-}" ]]; then
    notary_arguments+=(--issuer "$CLEARTONE_NOTARY_ISSUER_ID")
  fi
else
  echo "Notarization requires CLEARTONE_NOTARY_PROFILE or CLEARTONE_NOTARY_KEY_PATH and CLEARTONE_NOTARY_KEY_ID (plus CLEARTONE_NOTARY_ISSUER_ID for a team API key)." >&2
  exit 1
fi
[[ "${1:-}" == --check ]] && exit 0
package_path="${1:?Usage: notarize-mac.sh <signed.pkg> [--assess]}"
[[ -f "$package_path" && "$package_path" == *.pkg ]] || exit 1
workspace="$(mktemp -d /tmp/cleartone-notary.XXXXXX)"
trap 'rm -rf "$workspace"' EXIT
pkgutil --check-signature "$package_path"
# A timeout or rejection must never continue to stapling or release upload.
xcrun notarytool submit "$package_path" "${notary_arguments[@]}" \
  --wait --timeout "${CLEARTONE_NOTARY_TIMEOUT:-20m}" --output-format json > "$workspace/result.json"
notary_status="$(plutil -extract status raw -o - "$workspace/result.json")"
if [[ "$notary_status" != Accepted ]]; then
  echo "Apple notarization did not accept this package ($notary_status). Submission details:" >&2
  cat "$workspace/result.json" >&2
  exit 1
fi
xcrun stapler staple "$package_path"
xcrun stapler validate "$package_path"
if [[ "${2:-}" == --assess ]]; then
  /usr/sbin/spctl --assess --type install --verbose=2 "$package_path"
fi
echo "Notarized and stapled $package_path"
