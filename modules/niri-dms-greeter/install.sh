#!/usr/bin/env bash
set -Eeuo pipefail

greeter_backup_dir() { printf '%s\n' "${MYUNIX_GREETER_BACKUP_DIR:-/var/lib/myunix/backups/niri-dms-greeter/$(date +%Y%m%d-%H%M%S)}"; }

install_niri_dms_greeter() {
  [[ "${MYUNIX_CONFIRM_GREETER:-}" == replace-gdm ]] || die 'Set MYUNIX_CONFIRM_GREETER=replace-gdm to replace GDM'
  require_dms_supported_fedora
  command -v dms >/dev/null || die 'DMS must be installed first'
  local backup
  backup="$(greeter_backup_dir)"
  sudo mkdir -p "$backup"
  sudo sh -c "systemctl is-enabled gdm.service > '$backup/gdm.enabled' || true"
  sudo sh -c "systemctl is-enabled greetd.service > '$backup/greetd.enabled' || true"
  [[ -f /etc/greetd/config.toml ]] && sudo cp -a /etc/greetd/config.toml "$backup/config.toml"
  sudo dms greeter install
  sudo dms greeter status
  sudo dms greeter enable
  sudo dms greeter sync
  info "DankGreeter enabled; GDM backup: $backup"
}
