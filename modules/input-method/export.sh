#!/usr/bin/env bash
set -Eeuo pipefail

export_input_methods() {
  local module_dir source target file
  module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source="$HOME/.config/fcitx5"
  target="$module_dir/config/fcitx5"
  mkdir -p "$target"
  for file in config profile; do
    [[ -f "$source/$file" ]] && cp -a "$source/$file" "$target/$file"
  done
  require_command dconf
  dconf dump '/desktop/ibus/' > "$module_dir/config/ibus.ini"
  info 'Input-method configuration exported'
}
