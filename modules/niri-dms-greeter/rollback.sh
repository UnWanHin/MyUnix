#!/usr/bin/env bash
set -Eeuo pipefail

rollback_niri_dms_greeter() {
  local backup=$1
  [[ -d "$backup" ]] || die "Missing Greeter backup: $backup"
  sudo systemctl disable --now greetd
  [[ -f "$backup/config.toml" ]] && sudo cp -a "$backup/config.toml" /etc/greetd/config.toml
  sudo systemctl enable --now gdm
  info 'GDM restored. Reboot if a graphical login does not appear immediately.'
}
