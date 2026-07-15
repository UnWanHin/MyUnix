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
mkdir -p "$temporary_dir/source/dms" "$temporary_dir/home/.config/niri/dms"
printf '%s\n' 'environment {' '}' > "$temporary_dir/source/config.kdl"
printf '%s\n' 'binds {}' > "$temporary_dir/source/dms/binds.kdl"
printf '%s\n' 'old-config' > "$temporary_dir/home/.config/niri/config.kdl"
run env HOME="$temporary_dir/home" MYUNIX_NIRI_DMS_CONFIG_SOURCE="$temporary_dir/source" MYUNIX_NIRI_CONFIG_DIR="$temporary_dir/home/.config/niri" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; import_niri_dms_config; cat \"\$MYUNIX_NIRI_CONFIG_DIR/config.kdl\""
assert_status 0
assert_output_contains 'environment {'
find "$temporary_dir/home/.local/state/myunix/backups/niri-dms" -type f -name config.kdl -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing Niri config backup' >&2
  exit 1
}

temporary_export="$(mktemp -d)"
mkdir -p "$temporary_export/home/.config/niri" "$temporary_export/target"
cp -a "$PROJECT_ROOT/modules/niri-dms/config/niri/." "$temporary_export/home/.config/niri/"
mkdir -p "$temporary_export/home/.config/niri/myunix"
printf '%s\n' 'private phone fragment' > "$temporary_export/home/.config/niri/myunix/kdeconnect.kdl"
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

run env MYUNIX_SOURCE_ONLY=1 bash -c '
  prompt_log="$(mktemp)"
  read() {
    local target="${!#}"
    printf "%s\n" "$*" >> "$prompt_log"
    printf -v "$target" %s n
    return 0
  }
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  run_guided_install
  cat "$prompt_log"
'
assert_status 0
assert_output_contains 'Install bootstrap? [y/N]'
assert_output_contains 'Install input-method? [y/N]'
assert_output_contains 'Install niri-dms? [y/N]'
assert_output_contains 'Install shell-config? [y/N]'
assert_output_contains 'Install phone-connect? [y/N]'
[[ "$OUTPUT" != *'niri-dms-greeter'* ]] || {
  printf '%s\n' 'Greeter must not be offered by guided installation' >&2
  exit 1
}

temporary_plugins="$(mktemp -d)"
mkdir -p "$temporary_plugins/plugins"
run env DMS_PLUGIN_LOG="$temporary_plugins/plugins.log" MYUNIX_DMS_PLUGIN_METADATA_DIR="$temporary_plugins/plugins" bash -c '
  dms() { printf "%s\n" "$*" >> "$DMS_PLUGIN_LOG"; }
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
