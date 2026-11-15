#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
driver_project="$project_root/apps/macos/native/virtual-microphone-driver"
resources_directory="$project_root/apps/macos/native/swift-engine/Resources/driver"
workspace="$(mktemp -d /tmp/cleartone-driver.XXXXXX)"
derived_data="$workspace/DerivedData"
package_root="$workspace/package-root"
driver_name="ClearToneVirtualMicrophone.driver"
built_driver="$derived_data/Build/Products/Release/$driver_name"
staged_driver="$package_root/Library/Audio/Plug-Ins/HAL/$driver_name"
resource_package="$resources_directory/ClearToneVirtualMicrophone.pkg"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$driver_project/ClearToneVirtualMicrophone-Info.plist")"

cleanup() { rm -rf "$workspace"; }
trap cleanup EXIT

xcodebuild -project "$driver_project/ClearToneVirtualMicrophone.xcodeproj" -scheme ClearToneVirtualMicrophone -configuration Release -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build
xattr -cr "$built_driver"
driver_identity="${CLEARTONE_DRIVER_SIGN_IDENTITY:--}"
if [[ "$driver_identity" == "-" ]]; then
  codesign --force --sign - "$built_driver"
else
  codesign --force --timestamp --options runtime --sign "$driver_identity" "$built_driver"
fi

mkdir -p "${staged_driver:h}" "$resources_directory"
cp -R "$built_driver" "$staged_driver"
rm -f "$resource_package"
package_arguments=(--root "$package_root" --identifier com.typocreative.cleartone.virtual-microphone.installer --version "$version" --install-location / --scripts "$driver_project/Scripts")
if [[ -n "${CLEARTONE_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  package_arguments+=(--sign "$CLEARTONE_INSTALLER_SIGN_IDENTITY" --timestamp)
fi
pkgbuild "${package_arguments[@]}" "$resource_package"
if [[ -n "${CLEARTONE_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  pkgutil --check-signature "$resource_package"
fi
chmod 644 "$resource_package"
echo "Built $resource_package"
