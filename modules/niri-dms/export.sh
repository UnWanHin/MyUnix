#!/usr/bin/env bash
set -Eeuo pipefail

export_niri_dms() {
  local module_dir source target file
  module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source="$HOME/.config/niri"
  target="${MYUNIX_NIRI_DMS_CONFIG_TARGET:-$module_dir/config/niri}"
  [[ -f "$source/config.kdl" ]] || {
    info 'No Niri configuration to export'
    return 0
  }

  mkdir -p "$target/dms"
  cp -a "$source/config.kdl" "$target/config.kdl"
  if [[ -d "$source/dms" ]]; then
    for file in "$source"/dms/*.kdl; do
      [[ -f "$file" ]] && cp -a "$file" "$target/dms/$(basename "$file")"
    done
  fi
  info 'Niri and DMS configuration exported'
}
