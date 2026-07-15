#!/usr/bin/env bash
set -Eeuo pipefail

readonly KDECONNECT_NIRI_INCLUDE='include optional=true "myunix/kdeconnect.kdl"'

phone_connect_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

phone_connect_config_source() {
  printf '%s\n' "${MYUNIX_PHONE_CONNECT_CONFIG_SOURCE:-$(phone_connect_dir)/config}"
}

phone_connect_niri_dir() {
  printf '%s\n' "${MYUNIX_NIRI_CONFIG_DIR:-$HOME/.config/niri}"
}

phone_connect_backup_dir() {
  if [[ -z "${MYUNIX_PHONE_CONNECT_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_PHONE_CONNECT_ACTIVE_BACKUP_DIR="${MYUNIX_PHONE_CONNECT_BACKUP_DIR:-$HOME/.local/state/myunix/backups/phone-connect/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_PHONE_CONNECT_ACTIVE_BACKUP_DIR"
}

backup_phone_connect_file() {
  local source_file=$1 relative_path=$2 backup_file
  [[ -e "$source_file" ]] || return 0
  backup_file="$(phone_connect_backup_dir)/$relative_path"
  [[ -e "$backup_file" ]] && return 0
  mkdir -p "$(dirname "$backup_file")"
  cp -a "$source_file" "$backup_file"
}

import_kdeconnect_niri_fragment() {
  local source_file target_file
  source_file="$(phone_connect_config_source)/niri/myunix/kdeconnect.kdl"
  target_file="$(phone_connect_niri_dir)/myunix/kdeconnect.kdl"
  [[ -f "$source_file" ]] || die "Missing KDE Connect Niri fragment: $source_file"
  if [[ -f "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    return 0
  fi
  backup_phone_connect_file "$target_file" 'niri/myunix/kdeconnect.kdl'
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
}

ensure_kdeconnect_niri_include() {
  local config temporary_file
  config="${MYUNIX_NIRI_CONFIG:-$(phone_connect_niri_dir)/config.kdl}"
  [[ -f "$config" ]] || {
    info "Niri config not found at $config; start Niri once, then rerun this module to add KDE Connect startup."
    return 0
  }

  temporary_file="$(mktemp "${config}.myunix.XXXXXX")"
  awk -v include_line="$KDECONNECT_NIRI_INCLUDE" '$0 != include_line { print }' "$config" > "$temporary_file"
  printf '%s\n' "$KDECONNECT_NIRI_INCLUDE" >> "$temporary_file"
  if cmp -s "$temporary_file" "$config"; then
    rm -f "$temporary_file"
    return 0
  fi

  backup_phone_connect_file "$config" 'niri/config.kdl'
  mv "$temporary_file" "$config"
}

phone_connect_wants_nautilus() {
  case "${MYUNIX_PHONE_CONNECT_NAUTILUS:-}" in
    1|yes|true) return 0 ;;
    0|no|false) return 1 ;;
  esac
  [[ "${MYUNIX_INSTALL_MODE:-}" == guided && -t 0 ]] || return 1
  local reply
  read -r -p 'Install KDE Connect integration for Nautilus? [y/N] ' reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

configure_kdeconnect_firewall() {
  if ! command -v firewall-cmd >/dev/null 2>&1 || ! firewall-cmd --state >/dev/null 2>&1; then
    info 'Firewall changes skipped: firewalld is not active.'
    return 0
  fi

  if [[ "${MYUNIX_CONFIRM_KDECONNECT_FIREWALL:-}" != allow ]]; then
    if [[ -t 0 ]]; then
      local reply
      read -r -p 'Open KDE Connect LAN ports 1714-1764 for TCP and UDP? [y/N] ' reply
      [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || {
        info 'Firewall changes skipped. Pairing may require allowing KDE Connect LAN ports.'
        return 0
      }
    else
      info 'Firewall changes skipped. Set MYUNIX_CONFIRM_KDECONNECT_FIREWALL=allow to permit KDE Connect LAN ports.'
      return 0
    fi
  fi

  if [[ "${MYUNIX_PHONE_CONNECT_DRY_RUN:-}" == 1 ]]; then
    info 'Would open KDE Connect TCP/UDP ports 1714-1764 and reload firewalld.'
    return 0
  fi

  sudo firewall-cmd --permanent --add-port=1714-1764/tcp
  sudo firewall-cmd --permanent --add-port=1714-1764/udp
  sudo firewall-cmd --reload
}

install_phone_connect() {
  is_fedora || die 'Fedora is required'
  if [[ "${MYUNIX_PHONE_CONNECT_SKIP_PACKAGES:-}" != 1 ]]; then
    install_dnf_manifest "$(phone_connect_dir)/packages.txt"
    phone_connect_wants_nautilus && sudo dnf install -y kde-connect-nautilus
  fi
  import_kdeconnect_niri_fragment
  ensure_kdeconnect_niri_include
  configure_kdeconnect_firewall
  if [[ "${MYUNIX_PHONE_CONNECT_SKIP_VERIFY:-}" != 1 ]]; then
    require_command kdeconnectd
    require_command kdeconnect-cli
  fi
  info 'KDE Connect configured. Log out and back into Niri, then pair the KDE Connect app on your phone over the same local network.'
}
