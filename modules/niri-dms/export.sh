#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/personalization.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plugins.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/kitty.sh"

export_niri_dms() {
  local module_dir source target file temporary touchpad_file binding_file
  module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source="$HOME/.config/niri"
  target="${MYUNIX_NIRI_DMS_CONFIG_TARGET:-$module_dir/config/niri}"
  [[ -f "$source/config.kdl" ]] || {
    info 'No Niri configuration to export'
    return 0
  }

  mkdir -p "$target/dms" "$target/myunix"
  cp -a "$source/config.kdl" "$target/config.kdl"
  # Output modes, scale and positions belong to the current machine. Keep the
  # optional include in config.kdl so Niri/DMS can generate local output data.
  # DMS's input.kdl is generated state and is removed from the public tree;
  # config.kdl keeps its optional include so the managed touchpad fragment can
  # be loaded after DMS's local input preferences.
  rm -f "$target/dms/outputs.kdl" "$target/dms/input.kdl"
  touchpad_file="$source/myunix/touchpad.kdl"
  binding_file="$source/myunix/touchpad-bind.kdl"
  temporary="$(mktemp "$target/config.kdl.myunix.XXXXXX")"
  awk -v has_touchpad="$( [[ -f "$touchpad_file" ]] && printf 1 || printf 0 )" \
    -v has_binding="$( [[ -f "$binding_file" ]] && printf 1 || printf 0 )" '
    /^[[:space:]]*include[[:space:]]+(optional[[:space:]]*=[[:space:]]*true[[:space:]]+)?"dms\/input\.kdl"([[:space:]]|$)/ { next }
    /^[[:space:]]*include[[:space:]]+"myunix\/touchpad\.kdl"([[:space:]]|$)/ { next }
    /^[[:space:]]*include[[:space:]]+optional[[:space:]]*=[[:space:]]*true[[:space:]]+"myunix\/touchpad-bind\.kdl"([[:space:]]|$)/ { next }
    { print }
    END {
      print "include optional=true \"dms/input.kdl\""
      if (has_touchpad == 1) print "include \"myunix/touchpad.kdl\""
      if (has_binding == 1) print "include optional=true \"myunix/touchpad-bind.kdl\""
    }
  ' "$target/config.kdl" > "$temporary"
  mv "$temporary" "$target/config.kdl"
  if [[ -d "$source/dms" ]]; then
    for file in "$source"/dms/*.kdl; do
      case "$(basename "$file")" in
        outputs.kdl|input.kdl) continue ;;
      esac
      [[ -f "$file" ]] || continue
      if [[ "$(basename "$file")" == binds.kdl ]]; then
        temporary="$(mktemp "$target/dms/binds.kdl.myunix.XXXXXX")"
        awk '/^[[:space:]]*Mod\+F8([[:space:]]|$)/ { next } { print }' "$file" > "$temporary"
        mv "$temporary" "$target/dms/binds.kdl"
      else
        cp -a "$file" "$target/dms/$(basename "$file")"
      fi
    done
  fi
  [[ -f "$source/myunix/touchpad.kdl" ]] && cp -a "$source/myunix/touchpad.kdl" "$target/myunix/touchpad.kdl"
  if [[ -f "$source/myunix/touchpad-bind.kdl" ]]; then
    cp -a "$source/myunix/touchpad-bind.kdl" "$target/myunix/touchpad-bind.kdl"
  else
    rm -f "$target/myunix/touchpad-bind.kdl"
  fi
  export_dms_personalization
  export_dms_plugin_lock
  export_dms_plugin_settings
  export_kitty_config
  info 'Niri and DMS configuration exported'
}
