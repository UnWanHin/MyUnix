#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/niri-dms/install.sh"

run env MYUNIX_FEDORA_RELEASE=42 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; require_dms_supported_fedora"
assert_status 2
assert_output_contains 'DMS is supported only on Fedora 43 or 44'

temporary="$(mktemp)"
printf '%s\n' \
  'environment {' \
  '  XDG_CURRENT_DESKTOP "niri"' \
  '  GTK_IM_MODULE "fcitx"' \
  '}' \
  'spawn-at-startup "ibus-daemon" "-drx"' \
  'hotkey-overlay {' \
  '}' > "$temporary"
run env MYUNIX_NIRI_CONFIG="$temporary" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; configure_niri_fcitx_session; configure_niri_fcitx_session; cat \"\$MYUNIX_NIRI_CONFIG\""
assert_status 0
assert_output_contains 'XMODIFIERS "@im=fcitx"'
assert_output_contains 'QT_IM_MODULE "fcitx"'
assert_output_contains 'QT_IM_MODULES "wayland;fcitx"'
assert_output_contains 'spawn-at-startup "fcitx5" "-d"'
[[ "$OUTPUT" != *'GTK_IM_MODULE'* ]] || {
  printf '%s\n' 'Expected Niri Fcitx setup to remove GTK_IM_MODULE' >&2
  exit 1
}
[[ "$OUTPUT" != *'ibus-daemon'* ]] || {
  printf '%s\n' 'Expected Niri Fcitx setup to remove IBus startup' >&2
  exit 1
}

temporary_dir="$(mktemp -d)"
mkdir -p "$temporary_dir/source/dms" "$temporary_dir/source/myunix" "$temporary_dir/home/.config/niri/dms"
printf '%s\n' 'environment {' '}' > "$temporary_dir/source/config.kdl"
printf '%s\n' 'binds {}' > "$temporary_dir/source/dms/binds.kdl"
printf '%s\n' 'input {' '  touchpad {' '  }' '}' > "$temporary_dir/source/myunix/touchpad.kdl"
printf '%s\n' 'old-config' > "$temporary_dir/home/.config/niri/config.kdl"
run env HOME="$temporary_dir/home" MYUNIX_NIRI_DMS_CONFIG_SOURCE="$temporary_dir/source" MYUNIX_NIRI_CONFIG_DIR="$temporary_dir/home/.config/niri" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; import_niri_dms_config; cat \"\$MYUNIX_NIRI_CONFIG_DIR/config.kdl\""
assert_status 0
assert_output_contains 'environment {'
find "$temporary_dir/home/.local/state/myunix/backups/niri-dms" -type f -name config.kdl -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing Niri config backup' >&2
  exit 1
}
[[ -f "$temporary_dir/home/.config/niri/myunix/touchpad.kdl" ]] || {
  printf '%s\n' 'Expected managed touchpad fragment to be imported' >&2
  exit 1
}
run env HOME="$temporary_dir/home" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; install_niri_dms_touchpad_toggle; test -x \"\$HOME/.local/bin/niri-touchpad-toggle\""
assert_status 0

temporary_binding="$(mktemp -d)"
run env HOME="$temporary_binding/home" MYUNIX_NIRI_CONFIG_DIR="$temporary_binding/home/.config/niri" MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE=1 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; configure_niri_dms_touchpad_toggle_binding; cat \"\$MYUNIX_NIRI_CONFIG_DIR/myunix/touchpad-bind.kdl\""
assert_status 0
assert_output_contains 'Mod+F8'
assert_output_contains 'niri-touchpad-toggle'
run env HOME="$temporary_binding/home" MYUNIX_NIRI_CONFIG_DIR="$temporary_binding/home/.config/niri" MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE=0 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; configure_niri_dms_touchpad_toggle_binding; test ! -e \"\$MYUNIX_NIRI_CONFIG_DIR/myunix/touchpad-bind.kdl\""
assert_status 0

temporary_export="$(mktemp -d)"
mkdir -p "$temporary_export/home/.config/niri" "$temporary_export/target"
cp -a "$PROJECT_ROOT/modules/niri-dms/config/niri/." "$temporary_export/home/.config/niri/"
mkdir -p "$temporary_export/home/.config/niri/myunix"
printf '%s\n' 'private phone fragment' > "$temporary_export/home/.config/niri/myunix/kdeconnect.kdl"
printf '%s\n' 'input {' '  touchpad {' '  }' '}' > "$temporary_export/home/.config/niri/myunix/touchpad.kdl"
printf '%s\n' 'binds {' '  Mod+F8 { spawn "niri-touchpad-toggle"; }' '}' > "$temporary_export/home/.config/niri/myunix/touchpad-bind.kdl"
printf '%s\n' 'private backup' > "$temporary_export/home/.config/niri/config.kdl.backup.private"
run env HOME="$temporary_export/home" MYUNIX_NIRI_DMS_CONFIG_TARGET="$temporary_export/target" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/export.sh'; export_niri_dms"
assert_status 0
[[ -f "$temporary_export/target/config.kdl" ]] || {
  printf '%s\n' 'Expected Niri config to be exported to the requested target' >&2
  exit 1
}
[[ -f "$temporary_export/target/dms/binds.kdl" ]] || {
  printf '%s\n' 'Expected DMS shortcuts to be exported to the requested target' >&2
  exit 1
}
[[ -f "$temporary_export/target/dms/alttab.kdl" ]] || {
  printf '%s\n' 'Expected generated DMS Alt-Tab configuration to be exported' >&2
  exit 1
}
[[ ! -e "$temporary_export/target/config.kdl.backup.private" ]] || {
  printf '%s\n' 'Unexpected Niri backup export' >&2
  exit 1
}
[[ ! -e "$temporary_export/target/myunix/kdeconnect.kdl" ]] || {
  printf '%s\n' 'Niri/DMS exporter must not export Phone Connect state' >&2
  exit 1
}
[[ -f "$temporary_export/target/myunix/touchpad.kdl" ]] || {
  printf '%s\n' 'Expected managed touchpad fragment to be exported' >&2
  exit 1
}
[[ -f "$temporary_export/target/myunix/touchpad-bind.kdl" ]] || {
  printf '%s\n' 'Expected managed touchpad binding to be exported' >&2
  exit 1
}
rm "$temporary_export/home/.config/niri/myunix/touchpad-bind.kdl"
run env HOME="$temporary_export/home" MYUNIX_NIRI_DMS_CONFIG_TARGET="$temporary_export/target" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/export.sh'; export_niri_dms; test ! -e '$temporary_export/target/myunix/touchpad-bind.kdl'"
assert_status 0

temporary_touchpad="$(mktemp -d)"
touchpad_state="$temporary_touchpad/niri/myunix/touchpad.kdl"
mkdir -p "$(dirname "$touchpad_state")"
printf '%s\n' 'input {' '  touchpad {' '  }' '}' > "$touchpad_state"
run env \
  MYUNIX_NIRI_TOUCHPAD_STATE_FILE="$touchpad_state" \
  MYUNIX_NIRI_TOUCHPAD_SKIP_RELOAD=1 \
  MYUNIX_NOTIFY_SEND=true \
  "$PROJECT_ROOT/modules/niri-dms/bin/niri-touchpad-toggle"
assert_status 0
grep -qx '[[:space:]]*off' "$touchpad_state" || {
  printf '%s\n' 'Expected first touchpad toggle to disable the touchpad' >&2
  exit 1
}
run env \
  MYUNIX_NIRI_TOUCHPAD_STATE_FILE="$touchpad_state" \
  MYUNIX_NIRI_TOUCHPAD_SKIP_RELOAD=1 \
  MYUNIX_NOTIFY_SEND=true \
  "$PROJECT_ROOT/modules/niri-dms/bin/niri-touchpad-toggle"
assert_status 0
! grep -qx '[[:space:]]*off' "$touchpad_state" || {
  printf '%s\n' 'Expected second touchpad toggle to enable the touchpad' >&2
  exit 1
}

[[ -x "$PROJECT_ROOT/modules/niri-dms/bin/niri-touchpad-toggle" ]] || {
  printf '%s\n' 'Expected managed Niri touchpad helper' >&2
  exit 1
}

temporary_personalization="$(mktemp -d)"
settings="$temporary_personalization/settings.json"
category_target="$temporary_personalization/exported"
cat > "$settings" <<'EOF'
{
  "barConfigs": [{"id":"default","autoHide":false}],
  "showDock": true,
  "dockPosition": 0,
  "animationSpeed": 0.8,
  "fontFamily": "Inter Variable",
  "frameOpacity": 0.9,
  "clockFormat": "24h",
  "useAutoLocation": true,
  "wifiNetworkPins": {"private":"network"},
  "launcherLogoCustomPath": "/home/user/private-logo.svg",
  "builtInPluginSettings": {"privatePlugin": true}
}
EOF
run env MYUNIX_DMS_SETTINGS_FILE="$settings" MYUNIX_DMS_PERSONALIZATION_TARGET="$category_target" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/export.sh'; export_dms_personalization; cat '$category_target/bar.json'"
assert_status 0
assert_output_contains '"barConfigs"'
[[ "$OUTPUT" != *'wifiNetworkPins'* && "$OUTPUT" != *'private-logo'* && "$OUTPUT" != *'privatePlugin'* ]] || {
  printf '%s\n' 'DMS personalization export included excluded state' >&2
  exit 1
}

run cat "$category_target/time-weather.json"
assert_status 0
assert_output_contains '"clockFormat": "24h"'
assert_output_contains '"useAutoLocation": true'

cat > "$settings" <<'EOF'
{
  "barConfigs": [{"id":"default","autoHide":true}],
  "clockFormat": "12h",
  "useAutoLocation": false,
  "unknownLocalSetting": "preserve-me"
}
EOF
run env MYUNIX_DMS_SETTINGS_FILE="$settings" MYUNIX_DMS_PERSONALIZATION_SOURCE="$category_target" MYUNIX_DMS_BACKUP_DIR="$temporary_personalization/backups" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; import_dms_personalization; cat '$settings'"
assert_status 0
assert_output_contains '"autoHide": false'
assert_output_contains '"clockFormat": "24h"'
assert_output_contains '"useAutoLocation": true'
assert_output_contains '"unknownLocalSetting": "preserve-me"'
find "$temporary_personalization/backups" -type f -name DankMaterialShell-settings.json -print -quit | grep -q . || {
  printf '%s\n' 'Expected DMS personalization import backup' >&2
  exit 1
}

printf '%s\n' '{"wifiNetworkPins":{"private":"network"}}' > "$category_target/bar.json"
run env MYUNIX_DMS_SETTINGS_FILE="$settings" MYUNIX_DMS_PERSONALIZATION_SOURCE="$category_target" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; import_dms_personalization"
assert_status 2
assert_output_contains 'Invalid DMS personalization category'

for category in appearance bar dock frame time-weather; do
  ! git -C "$PROJECT_ROOT" check-ignore -q "modules/niri-dms/config/dms/$category.json" || {
    printf 'DMS personalization category is ignored: %s\n' "$category" >&2
    exit 1
  }
done

run env MYUNIX_SOURCE_ONLY=1 MYUNIX_UI_TEST_MODE=1 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  ui_choose_many() { printf "0\n"; }
  run_module() { printf "%s\n" "$1"; }
  run_custom_install
'
assert_status 0
assert_output_contains 'bootstrap'
assert_output_contains 'input-method'
[[ "$OUTPUT" != *'niri-dms-greeter'* ]] || {
  printf '%s\n' 'Greeter must not be offered by custom installation' >&2
  exit 1
}

temporary_plugins="$(mktemp -d)"
mkdir -p "$temporary_plugins/plugins"
run env DMS_PLUGIN_LOG="$temporary_plugins/plugins.log" MYUNIX_DMS_PLUGIN_METADATA_DIR="$temporary_plugins/plugins" bash -c '
  dms() { printf "%s\n" "$*" >> "$DMS_PLUGIN_LOG"; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/niri-dms/install.sh"
  install_niri_dms_plugins
  cat "$DMS_PLUGIN_LOG"
'
assert_status 0
assert_output_contains 'plugins install dankActions'
assert_output_contains 'plugins install dankGifSearch'
assert_output_contains 'plugins install dankKDEConnect'

temporary_existing_plugin="$(mktemp -d)"
mkdir -p "$temporary_existing_plugin/plugins"
touch "$temporary_existing_plugin/plugins/dankActions.meta"
run env DMS_PLUGIN_LOG="$temporary_existing_plugin/plugins.log" MYUNIX_DMS_PLUGIN_METADATA_DIR="$temporary_existing_plugin/plugins" bash -c '
  dms() { printf "%s\n" "$*" >> "$DMS_PLUGIN_LOG"; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/niri-dms/install.sh"
  install_niri_dms_plugins
  cat "$DMS_PLUGIN_LOG"
'
assert_status 0
[[ "$OUTPUT" != *'plugins install dankActions'* ]] || {
  printf '%s\n' 'Existing DMS plugins must not be installed again' >&2
  exit 1
}
assert_output_contains 'plugins install dankGifSearch'
assert_output_contains 'plugins install dankKDEConnect'
