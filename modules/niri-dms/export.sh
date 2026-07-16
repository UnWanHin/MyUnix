#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/personalization.sh"

export_niri_dms() {
  local module_dir source target file
  module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source="$HOME/.config/niri"
  target="${MYUNIX_NIRI_DMS_CONFIG_TARGET:-$module_dir/config/niri}"
  [[ -f "$source/config.kdl" ]] || {
    info 'No Niri configuration to export'
    return 0
  }

  mkdir -p "$target/dms" "$target/myunix"
  cp -a "$source/config.kdl" "$target/config.kdl"
  if [[ -d "$source/dms" ]]; then
    for file in "$source"/dms/*.kdl; do
      [[ -f "$file" ]] && cp -a "$file" "$target/dms/$(basename "$file")"
    done
  fi
  [[ -f "$source/myunix/touchpad.kdl" ]] && cp -a "$source/myunix/touchpad.kdl" "$target/myunix/touchpad.kdl"
  if [[ -f "$source/myunix/touchpad-bind.kdl" ]]; then
    cp -a "$source/myunix/touchpad-bind.kdl" "$target/myunix/touchpad-bind.kdl"
  else
    rm -f "$target/myunix/touchpad-bind.kdl"
  fi
  export_dms_personalization
  info 'Niri and DMS configuration exported'
}
