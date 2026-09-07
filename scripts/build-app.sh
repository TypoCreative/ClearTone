#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
package_path="$project_root/native/swift-engine"
app_path="$project_root/dist/ClearTone.app"
contents="$app_path/Contents"
target_arch="${CLEARTONE_TARGET_ARCH:-}"
swift_arch=""

case "$target_arch" in
  "") ;;
  arm64) swift_arch="arm64" ;;
  x64) swift_arch="x86_64" ;;
  *) echo "Unsupported CLEARTONE_TARGET_ARCH: $target_arch" >&2; exit 1 ;;
esac

cache_root="${TMPDIR:-/tmp}/cleartone-swift-cache"
mkdir -p "$cache_root/clang" "$cache_root/swiftpm"
build_arguments=(build --package-path "$package_path" --disable-sandbox -c release)
if [[ -n "$swift_arch" ]]; then
  build_arguments+=(--arch "$swift_arch")
fi

CLANG_MODULE_CACHE_PATH="$cache_root/clang" SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" swift "${build_arguments[@]}"
binary_directory="$(CLANG_MODULE_CACHE_PATH="$cache_root/clang" SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" swift "${build_arguments[@]}" --show-bin-path)"

rm -rf "$app_path"
mkdir -p "$contents/MacOS" "$contents/Resources/driver"
cp "$binary_directory/ClearTone" "$contents/MacOS/ClearTone"
cp "$package_path/Resources/Info.plist" "$contents/Info.plist"
cp "$package_path/Resources/ClearTone.icns" "$contents/Resources/ClearTone.icns"
if [[ -f "$package_path/Resources/driver/ClearToneVirtualMicrophone.pkg" ]]; then
  cp "$package_path/Resources/driver/ClearToneVirtualMicrophone.pkg" "$contents/Resources/driver/"
fi

xattr -cr "$app_path"
app_identity="${CLEARTONE_APP_SIGN_IDENTITY:--}"
if [[ "$app_identity" == "-" ]]; then
  codesign --force --deep --sign - --entitlements "$package_path/Resources/ClearTone.entitlements" "$app_path"
else
  codesign --force --deep --timestamp --options runtime --sign "$app_identity" --entitlements "$package_path/Resources/ClearTone.entitlements" "$app_path"
fi

codesign --verify --deep --strict "$app_path"
plutil -lint "$contents/Info.plist"
file "$contents/MacOS/ClearTone"
echo "Built $app_path"
