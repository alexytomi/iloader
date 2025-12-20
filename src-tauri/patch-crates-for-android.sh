#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
echo "This script should only be ran inside a termux environment!"
echo "WARNING: will DELETE the path 'vendor' in the current working directory in 5 seconds from NOW!"
sleep 5
rm -rf vendor
git restore Cargo.toml
cargo clean
cargo vendor
echo "" >> Cargo.toml
echo '[patch.crates-io]' >> Cargo.toml

crates_to_patch=(
  softbuffer
  tao
  tauri-macros
  tauri-plugin-dialog
  tauri-plugin-fs
  tauri-plugin-opener
  tauri-runtime-wry
  tauri-runtime
  tauri-utils
  tauri
  tauri-plugin
  wry
  muda
  rfd
)

git add -A && git commit -m "add vendored folders" && git tag -d unpatched
git tag unpatched
for crate in "${crates_to_patch[@]}"; do
    echo "termuxifying '$crate'..."
    find "vendor/$crate" -type f | \
        xargs -n 1 sed -i \
        -e 's|"android"|"disabling_this_because_it_is_for_building_an_apk"|g' \
        -e 's|"linux"|"android"|g' \
        -e "s|libxkbcommon.so.0|libxkbcommon.so|g" \
        -e "s|libxkbcommon-x11.so.0|libxkbcommon-x11.so|g" \
        -e "s|libxcb.so.1|libxcb.so|g" \
        -e "s|/tmp|/data/data/com.termux/files/usr/tmp|g"

    echo "$crate = { path = \"./vendor/$crate\" }" >> Cargo.toml
    git add -A && git commit -m "automated termux patch for $crate"
done
git format-patch unpatched -o patches
