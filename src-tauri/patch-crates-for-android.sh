cargo clean
cargo vendor vendor/

# We patch idevice because it hardcodes usbmuxd socket at /var/run/usbmuxd
# To do this we cargo vendor to fetch it and then patch it then modify Cargo.toml to use our patched version
# Since we have to preserve the features block of idevice in the original Cargo.toml, we patch Cargo.toml for idevice here
sed -i 's|idevice = { version = "[^"]*"\(.*\)}|idevice = { path = "./vendor/idevice"\1}|g' Cargo.toml
# We skip patching it again because it will become a duplicate in Cargo.toml
crates_to_skip_cargo_toml=(
  idevice
)

echo "" >>Cargo.toml
echo '[patch.crates-io]' >>Cargo.toml
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
  reqwest
  rustls-platform-verifier
  idevice
)
# # If there is an issue with the automated patching, uncomment these to make it save the patches in src-tauri/patches. You can simply git am this dir.
git add -A && git commit -m "add vendored folders" && git tag -d unpatched
git tag unpatched
for crate in "${crates_to_patch[@]}"; do
  echo "termuxifying '$crate'..."
  find "vendor/$crate" -type f |
    xargs -n 1 sed -i \
      -e 's|"android"|"disabling_this_because_it_is_for_building_an_apk"|g' \
      -e "s|ANDROID|DISABLING_THIS_BECAUSE_IT_IS_FOR_BUILDING_AN_APK|g" \
      -e 's|"linux"|"android"|g' \
      -e "s|libxkbcommon.so.0|libxkbcommon.so|g" \
      -e "s|libxkbcommon-x11.so.0|libxkbcommon-x11.so|g" \
      -e "s|libxcb.so.1|libxcb.so|g" \
      -e "s|/tmp/|$TERMUX_PREFIX/tmp/|g" \
      -e "s|/var/|$TERMUX_PREFIX/var/|g"

  if [[ " ${crates_to_skip_cargo_toml[*]} " == *" $crate "* ]]; then
    echo "skipping Cargo.toml entry of '$crate'..."
    continue
  fi
  echo "adding Cargo.toml entrg of '$crate'..."
  echo "$crate = { path = \"./vendor/$crate\" }" >>Cargo.toml

  git add -A && git commit -m "automated termux patch for $crate"
done
git format-patch unpatched -o patches

# Generates the dist folder. Required else build fails.
npm install && npm run build
cargo build --bins --target aarch64-linux-android
