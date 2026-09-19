#!/usr/bin/env bash
set -Eeuo pipefail

kitty_config_files() {
  printf '%s\n' kitty.conf dank-theme.conf dank-tabs.conf
}

kitty_config_source_dir() {
  printf '%s\n' "${MYUNIX_KITTY_CONFIG_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../config/kitty" && pwd)}"
}

kitty_config_target_dir() {
  printf '%s\n' "${MYUNIX_KITTY_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
}

kitty_config_backup_dir() {
  printf '%s\n' "${MYUNIX_KITTY_BACKUP_DIR:-$HOME/.local/state/myunix/backups/niri-dms/$(date +%Y%m%d-%H%M%S)/kitty}"
}

import_kitty_config() {
  local source_dir target_dir backup_dir file source target backup
  source_dir="$(kitty_config_source_dir)"
  target_dir="$(kitty_config_target_dir)"
  for file in $(kitty_config_files); do
    source="$source_dir/$file"
    target="$target_dir/$file"
    [[ -f "$source" ]] || continue
    if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
      continue
    fi
    if [[ -e "$target" ]]; then
      backup_dir="$(kitty_config_backup_dir)"
      backup="$backup_dir/$file"
      mkdir -p "$backup_dir"
      [[ -e "$backup" ]] || cp -a "$target" "$backup"
    fi
    mkdir -p "$target_dir"
    cp -a "$source" "$target"
  done
}

export_kitty_config() {
  local source_dir target_dir file source target exported=0
  source_dir="$(kitty_config_target_dir)"
  target_dir="$(kitty_config_source_dir)"
  for file in $(kitty_config_files); do
    source="$source_dir/$file"
    target="$target_dir/$file"
    if [[ -f "$source" ]]; then
      mkdir -p "$target_dir"
      cp -a "$source" "$target"
      exported=1
    else
      rm -f "$target"
    fi
  done
  ((exported == 1)) || return 0
  info 'Kitty configuration exported'
}
