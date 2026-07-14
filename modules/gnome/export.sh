#!/usr/bin/env bash
set -Eeuo pipefail

export_gnome() {
  local directory
  directory="${MYUNIX_GNOME_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dconf}"
  require_command dconf
  mkdir -p "$directory"
  dconf dump '/org/gnome/settings-daemon/plugins/media-keys/' > "$directory/media-keys.ini"
  info "GNOME hotkeys exported to $directory/media-keys.ini"
}
