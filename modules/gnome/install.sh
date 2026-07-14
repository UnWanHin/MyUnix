#!/usr/bin/env bash
set -Eeuo pipefail

readonly GNOME_MEDIA_KEYS='/org/gnome/settings-daemon/plugins/media-keys/'

gnome_config_dir() {
  printf '%s\n' "${MYUNIX_GNOME_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dconf}"
}

import_gnome() {
  local config backup
  config="$(gnome_config_dir)/media-keys.ini"
  [[ -r "$config" ]] || { info 'No GNOME hotkey export found; skipping'; return 0; }
  require_command dconf
  backup="$(state_dir)/backups/gnome/media-keys.ini"
  mkdir -p "$(dirname "$backup")"
  dconf dump "$GNOME_MEDIA_KEYS" > "$backup"
  dconf load "$GNOME_MEDIA_KEYS" < "$config"
  info 'GNOME settings restored'
}
