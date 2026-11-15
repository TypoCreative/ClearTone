#!/bin/zsh
set -euo pipefail

app_path="${1:-/Applications/ClearTone.app}"
if [[ ! -d "$app_path" || -L "$app_path" ]]; then
  echo "ClearTone was not found at $app_path" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$bundle_id" == com.typocreative.cleartone ]] || { echo "Not a ClearTone bundle." >&2; exit 1; }
/usr/bin/codesign --verify --deep --strict "$app_path"

if [[ -w "$app_path" ]]; then
  /usr/bin/xattr -dr com.apple.quarantine "$app_path"
else
  /usr/bin/sudo /usr/bin/xattr -dr com.apple.quarantine "$app_path"
fi

echo "Removed quarantine attributes from $app_path"
