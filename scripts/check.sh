#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cache_root="${TMPDIR:-/tmp}/cleartone-swift-cache"
mkdir -p "$cache_root/clang" "$cache_root/swiftpm"
CLANG_MODULE_CACHE_PATH="$cache_root/clang" SWIFTPM_MODULECACHE_OVERRIDE="$cache_root/swiftpm" swift test --package-path "$project_root/native/swift-engine" --disable-sandbox
"$project_root/scripts/build-app.sh"
