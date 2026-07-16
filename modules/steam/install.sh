#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../modules/dnf/install.sh"

steam_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

steam_system_applications_dir() {
  printf '%s\n' "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
}

steam_desktop_target() {
  printf '%s\n' "${MYUNIX_STEAM_DESKTOP_TARGET:-$HOME/.local/share/applications/steam.desktop}"
}

steam_backup_existing_override() {
  local target backup
  target="$(steam_desktop_target)"
  [[ -f "$target" ]] || return 0
  grep -qx 'X-MyUnix-Managed=true' "$target" && return 0

  backup="$HOME/.local/state/myunix/backups/steam/$(date +%Y%m%d-%H%M%S)/steam.desktop"
  mkdir -p "$(dirname "$backup")"
  cp -a "$target" "$backup"
}

install_steam_desktop_override() {
  local source target temporary
  source="$(steam_system_applications_dir)/steam.desktop"
  target="$(steam_desktop_target)"
  [[ -f "$source" ]] || die "Steam desktop entry not found: $source"

  steam_backup_existing_override
  mkdir -p "$(dirname "$target")"
  temporary="$(mktemp "${target}.myunix.XXXXXX")"
  awk '
    /^X-MyUnix-Managed=true$/ { next }
    /^\[Desktop Entry\]$/ {
      print
      print "X-MyUnix-Managed=true"
      next
    }
    /^Exec=\/usr\/bin\/steam([[:space:]]|$)/ {
      sub(/^Exec=\/usr\/bin\/steam/, "Exec=/usr/bin/steam -system-composer")
    }
    { print }
  ' "$source" > "$temporary"
  mv "$temporary" "$target"
}

install_steam() {
  local module_dir
  module_dir="$(steam_module_dir)"
  install_dnf_manifest "$module_dir/packages.txt"
  rpm -q steam
  install_steam_desktop_override
  info 'Steam installed with the Niri-compatible system-composer launcher.'
}
