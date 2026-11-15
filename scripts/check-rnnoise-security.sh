#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
source_root="$project_root/apps/macos/native/swift-engine/Sources/CRNNoise"
workspace="$(mktemp -d /tmp/cleartone-security.XXXXXX)"
trap 'rm -rf "$workspace"' EXIT
sources=(denoise kiss_fft pitch celt_lpc rnn nnet nnet_default rnnoise_tables rnnoise_data parse_lpcnet_weights)
files=()
for source in "${sources[@]}"; do files+=("$source_root/$source.c"); done
clang -std=c11 -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer \
  -DRNNOISE_BUILD -I"$source_root" -I"$source_root/include" \
  "$project_root/tests/rnnoise-security.c" "${files[@]}" -lm -o "$workspace/security-tests"
"$workspace/security-tests"
