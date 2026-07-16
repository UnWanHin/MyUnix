#!/usr/bin/env bash
set -Eeuo pipefail

dms_personalization_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

dms_settings_file() {
  printf '%s\n' "${MYUNIX_DMS_SETTINGS_FILE:-$HOME/.config/DankMaterialShell/settings.json}"
}

dms_personalization_policy_file() {
  printf '%s\n' "$(dms_personalization_module_dir)/personalization-categories.json"
}

dms_personalization_target_dir() {
  printf '%s\n' "${MYUNIX_DMS_PERSONALIZATION_TARGET:-$(dms_personalization_module_dir)/config/dms}"
}

dms_personalization_source_dir() {
  printf '%s\n' "${MYUNIX_DMS_PERSONALIZATION_SOURCE:-$(dms_personalization_module_dir)/config/dms}"
}

dms_personalization_categories() {
  jq -r 'keys[]' "$(dms_personalization_policy_file)"
}

dms_validate_personalization_category() {
  local category_file=$1 category=$2 policy
  policy="$(dms_personalization_policy_file)"
  jq -e --arg category "$category" --slurpfile policy "$policy" '
    type == "object"
    and (keys as $keys | $policy[0][$category] as $allowed |
         all($keys[]; . as $key | ($allowed | index($key) != null)))
  ' "$category_file" >/dev/null
}

export_dms_personalization() {
  local settings target policy category
  settings="$(dms_settings_file)"
  target="$(dms_personalization_target_dir)"
  policy="$(dms_personalization_policy_file)"
  [[ -f "$settings" ]] || {
    info 'No DMS settings to export'
    return 0
  }
  require_command jq
  mkdir -p "$target"
  while IFS= read -r category; do
    jq --arg category "$category" --slurpfile policy "$policy" '
      $policy[0][$category] as $allowed |
      with_entries(select(.key as $key | $allowed | index($key)))
    ' "$settings" > "$target/$category.json"
  done < <(dms_personalization_categories)
  info 'DMS personalization exported'
}

import_dms_personalization() {
  local settings source category category_file temporary backup_dir backup_created=0
  settings="$(dms_settings_file)"
  source="$(dms_personalization_source_dir)"
  [[ -f "$settings" && -d "$source" ]] || return 0
  require_command jq
  while IFS= read -r category; do
    category_file="$source/$category.json"
    [[ -f "$category_file" ]] || continue
    dms_validate_personalization_category "$category_file" "$category" \
      || die "Invalid DMS personalization category: $category_file"
    temporary="$(mktemp "${settings}.myunix.XXXXXX")"
    jq --slurpfile category "$category_file" '. * $category[0]' "$settings" > "$temporary"
    if cmp -s "$settings" "$temporary"; then
      rm -f "$temporary"
      continue
    fi
    if ((backup_created == 0)); then
      backup_dir="${MYUNIX_DMS_BACKUP_DIR:-$HOME/.local/state/myunix/backups/niri-dms/$(date +%Y%m%d-%H%M%S)}"
      mkdir -p "$backup_dir"
      cp -a "$settings" "$backup_dir/DankMaterialShell-settings.json"
      backup_created=1
    fi
    install -m 0600 "$temporary" "$settings"
    rm -f "$temporary"
  done < <(dms_personalization_categories)
}
