#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/personalization.sh"

fedora_release() { printf '%s\n' "${MYUNIX_FEDORA_RELEASE:-$(rpm -E %fedora)}"; }

niri_dms_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

dms_plugin_metadata_dir() {
  printf '%s\n' "${MYUNIX_DMS_PLUGIN_METADATA_DIR:-$HOME/.config/DankMaterialShell/plugins}"
}

require_dms_supported_fedora() {
  local release
  release="$(fedora_release)"
  [[ "$release" == 43 || "$release" == 44 ]] || die 'DMS is supported only on Fedora 43 or 44'
}

install_niri_dms_touchpad_toggle() {
  local module_dir source target
  module_dir="$(niri_dms_dir)"
  source="$module_dir/bin/niri-touchpad-toggle"
  target="${MYUNIX_NIRI_DMS_BIN_DIR:-$HOME/.local/bin}/niri-touchpad-toggle"
  [[ -f "$source" ]] || die "Missing Niri touchpad toggle helper: $source"
  mkdir -p "$(dirname "$target")"
  cp -a "$source" "$target"
  chmod 0755 "$target"
}

configure_niri_dms_touchpad_toggle_binding() {
  local config_dir binding_file temporary
  case "${MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE:-}" in
    '') return 0 ;;
    0|1) ;;
    *) die 'MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE must be 0 or 1' ;;
  esac

  config_dir="${MYUNIX_NIRI_CONFIG_DIR:-$HOME/.config/niri}"
  binding_file="$config_dir/myunix/touchpad-bind.kdl"
  if [[ "$MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE" == 0 ]]; then
    rm -f "$binding_file"
    return 0
  fi

  mkdir -p "$(dirname "$binding_file")"
  temporary="$(mktemp "${binding_file}.myunix.XXXXXX")"
  printf '%s\n' \
    '// Managed by MyUnix custom Niri + DMS personalization.' \
    'binds {' \
    '    Mod+F8 hotkey-overlay-title="Toggle Touchpad" { spawn "sh" "-lc" "$HOME/.local/bin/niri-touchpad-toggle"; }' \
    '}' > "$temporary"
  mv "$temporary" "$binding_file"
}

install_niri_dms_plugins() {
  local manifest=${1:-"$(niri_dms_dir)/plugins.txt"} plugin metadata_dir
  [[ "${MYUNIX_NIRI_DMS_SKIP_PLUGINS:-}" == 1 ]] && return 0
  [[ -r "$manifest" ]] || die "Missing DMS plugin manifest: $manifest"
  require_command dms
  metadata_dir="$(dms_plugin_metadata_dir)"

  while IFS= read -r plugin || [[ -n "$plugin" ]]; do
    is_comment_or_blank "$plugin" && continue
    [[ "$plugin" =~ ^[[:alnum:]_-]+$ ]] || die "Invalid DMS plugin ID: $plugin"
    if [[ -f "$metadata_dir/$plugin.meta" ]]; then
      info "DMS plugin already installed: $plugin"
      continue
    fi
    network_run dnf "Installing DMS plugin: $plugin" dms plugins install "$plugin"
  done < "$manifest"
}

import_niri_dms_config() {
  local module_dir source target backup_dir file
  module_dir="$(niri_dms_dir)"
  source="${MYUNIX_NIRI_DMS_CONFIG_SOURCE:-$module_dir/config/niri}"
  [[ -f "$source/config.kdl" ]] || return 0

  target="${MYUNIX_NIRI_CONFIG_DIR:-$HOME/.config/niri}"
  backup_dir="$HOME/.local/state/myunix/backups/niri-dms/$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$target/config.kdl" || -d "$target/dms" || -f "$target/myunix/touchpad.kdl" ]]; then
    mkdir -p "$backup_dir"
    [[ -e "$target/config.kdl" ]] && cp -a "$target/config.kdl" "$backup_dir/config.kdl"
    [[ -d "$target/dms" ]] && cp -a "$target/dms" "$backup_dir/dms"
    [[ -f "$target/myunix/touchpad.kdl" ]] && cp -a "$target/myunix/touchpad.kdl" "$backup_dir/touchpad.kdl"
  fi

  mkdir -p "$target/dms" "$target/myunix"
  cp -a "$source/config.kdl" "$target/config.kdl"
  if [[ -d "$source/dms" ]]; then
    for file in "$source"/dms/*.kdl; do
      [[ -f "$file" ]] && cp -a "$file" "$target/dms/$(basename "$file")"
    done
  fi
  [[ -f "$source/myunix/touchpad.kdl" ]] && cp -a "$source/myunix/touchpad.kdl" "$target/myunix/touchpad.kdl"
}

configure_niri_fcitx_session() {
  local config temporary
  config="${MYUNIX_NIRI_CONFIG:-${MYUNIX_NIRI_CONFIG_DIR:-$HOME/.config/niri}/config.kdl}"
  [[ -f "$config" ]] || {
    info "Niri config not found at $config; start Niri once, then rerun this module to enable Fcitx5."
    return 0
  }

  temporary="$(mktemp "${config}.myunix.XXXXXX")"
  awk '
    BEGIN { in_environment = 0; environment_seen = 0; startup_written = 0 }
    /^[[:space:]]*environment[[:space:]]*\{[[:space:]]*$/ {
      in_environment = 1
      environment_seen = 1
      print
      next
    }
    in_environment && /^[[:space:]]*}[[:space:]]*$/ {
      print "  XMODIFIERS \"@im=fcitx\""
      print "  QT_IM_MODULE \"fcitx\""
      print "  QT_IM_MODULES \"wayland;fcitx\""
      in_environment = 0
      print
      next
    }
    in_environment && /^[[:space:]]*(XMODIFIERS|GTK_IM_MODULE|QT_IM_MODULE|QT_IM_MODULES)[[:space:]]/ { next }
    /^spawn-at-startup "ibus-daemon" "-drx"$/ { next }
    /^spawn-at-startup "fcitx5" "-d"$/ { startup_written = 1; print; next }
    /^[[:space:]]*hotkey-overlay[[:space:]]*[{]/ && !startup_written {
      print "spawn-at-startup \"fcitx5\" \"-d\""
      startup_written = 1
    }
    { print }
    END {
      if (!environment_seen) exit 2
      if (!startup_written) print "spawn-at-startup \"fcitx5\" \"-d\""
    }
  ' "$config" > "$temporary" || {
    rm -f "$temporary"
    die "Unable to update Niri config: $config"
  }
  mv "$temporary" "$config"
}

install_niri_dms() {
  local module_dir
  is_fedora || die 'Fedora is required'
  require_dms_supported_fedora
  module_dir="$(niri_dms_dir)"
  network_run dnf 'Enabling DankLinux COPR repository' sudo dnf copr enable -y avengemedia/danklinux
  network_run dnf 'Enabling DMS COPR repository' sudo dnf copr enable -y avengemedia/dms
  verify_dnf_manifest_available "$module_dir/packages.txt"
  install_dnf_manifest "$module_dir/packages.txt"
  install_niri_dms_plugins "$module_dir/plugins.txt"
  import_niri_dms_config
  install_niri_dms_touchpad_toggle
  configure_niri_dms_touchpad_toggle_binding
  configure_niri_fcitx_session
  import_dms_personalization
  info 'Niri + DMS installed. Run the input-method module, then log out and select Niri from the login-session chooser.'
}
