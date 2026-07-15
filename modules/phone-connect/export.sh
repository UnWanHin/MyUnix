#!/usr/bin/env bash
set -Eeuo pipefail

export_phone_connect() {
  local source_file target_file
  source_file="$(phone_connect_niri_dir)/myunix/kdeconnect.kdl"
  [[ -f "$source_file" ]] || {
    info 'No public KDE Connect Niri fragment found to export'
    return 0
  }
  target_file="$(phone_connect_config_source)/niri/myunix/kdeconnect.kdl"
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
  info 'KDE Connect Niri fragment exported for review'
}
