#!/usr/bin/env bash
set -Eeuo pipefail

dms_plugin_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

dms_plugin_lock_source() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_LOCK_FILE:-$(dms_plugin_module_dir)/config/dms/plugins.lock.json}"
}

dms_plugin_lock_target() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_LOCK_TARGET:-$(dms_plugin_module_dir)/config/dms/plugins.lock.json}"
}

dms_plugin_settings_file() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_SETTINGS_FILE:-$HOME/.config/DankMaterialShell/plugin_settings.json}"
}

dms_plugin_settings_source() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_SETTINGS_SOURCE:-$(dms_plugin_module_dir)/config/dms/plugin-settings.json}"
}

dms_plugin_settings_target() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_SETTINGS_TARGET:-$(dms_plugin_module_dir)/config/dms/plugin-settings.json}"
}

validate_dms_public_plugin_settings() {
  local source=$1
  jq -e '
    type == "object"
    and (keys | all(. == "dankActions"))
    and ((.dankActions | type) == "object")
  ' "$source" >/dev/null
}

export_dms_plugin_lock() {
  local target temporary
  target="$(dms_plugin_lock_target)"
  command -v dms >/dev/null || {
    info 'No DMS command available; skipping plugin lock export'
    return 0
  }
  mkdir -p "$(dirname "$target")"
  temporary="$(mktemp "$(dirname "$target")/.plugins.lock.myunix.XXXXXX")"
  rm -f "$temporary"
  dms plugins lock --output "$temporary"
  require_command jq
  jq -e '.lockfileVersion == 1 and (.plugins | type == "object")' "$temporary" >/dev/null || die 'DMS generated an invalid plugin lock file'
  install -m 0644 "$temporary" "$target"
  rm -f "$temporary"
  info 'DMS plugin lock exported'
}

restore_niri_dms_plugin_lock() {
  local source
  source="$(dms_plugin_lock_source)"
  [[ -f "$source" ]] || return 0
  require_command dms
  require_command jq
  jq -e '.lockfileVersion == 1 and (.plugins | type == "object")' "$source" >/dev/null || die "Invalid DMS plugin lock: $source"
  network_run dnf 'Restoring DMS plugin revisions' dms plugins restore "$source"
}

export_dms_plugin_settings() {
  local settings target temporary
  settings="$(dms_plugin_settings_file)"
  target="$(dms_plugin_settings_target)"
  [[ -f "$settings" ]] || {
    rm -f "$target"
    info 'No DMS public plugin settings to export'
    return 0
  }
  require_command jq
  mkdir -p "$(dirname "$target")"
  temporary="$(mktemp "$(dirname "$target")/.plugin-settings.myunix.XXXXXX")"
  jq 'if (.dankActions | type) == "object" then {dankActions} else {} end' "$settings" > "$temporary"
  if [[ "$(jq 'length' "$temporary")" == 0 ]]; then
    rm -f "$temporary" "$target"
    info 'No DMS public plugin settings to export'
    return 0
  fi
  validate_dms_public_plugin_settings "$temporary" || die 'Invalid public DMS plugin settings'
  install -m 0644 "$temporary" "$target"
  rm -f "$temporary"
  info 'DMS public plugin settings exported'
}

import_dms_plugin_settings() {
  local settings source temporary backup_dir
  settings="$(dms_plugin_settings_file)"
  source="$(dms_plugin_settings_source)"
  [[ -f "$source" ]] || return 0
  require_command jq
  validate_dms_public_plugin_settings "$source" || die "Invalid public DMS plugin settings: $source"
  if [[ ! -f "$settings" ]]; then
    install -d -m 0700 "$(dirname "$settings")"
    printf '%s\n' '{}' | install -m 0600 /dev/stdin "$settings"
  fi
  temporary="$(mktemp "${settings}.myunix.XXXXXX")"
  jq --slurpfile public "$source" '. * $public[0]' "$settings" > "$temporary"
  if cmp -s "$settings" "$temporary"; then
    rm -f "$temporary"
    return 0
  fi
  backup_dir="${MYUNIX_DMS_BACKUP_DIR:-$HOME/.local/state/myunix/backups/niri-dms/$(date +%Y%m%d-%H%M%S)}"
  mkdir -p "$backup_dir"
  cp -a "$settings" "$backup_dir/DankMaterialShell-plugin-settings.json"
  install -m 0600 "$temporary" "$settings"
  rm -f "$temporary"
}
