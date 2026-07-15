#!/usr/bin/env bash
set -Eeuo pipefail

portal_login_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

portal_login_install_file() {
  local source_file=$1 target_file=$2 mode=$3
  [[ -f "$source_file" ]] || die "Missing portal-login source file: $source_file"
  if [[ -f "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    chmod "$mode" "$target_file"
    return 0
  fi
  mkdir -p "$(dirname "$target_file")"
  install -m "$mode" "$source_file" "$target_file"
}

install_portal_login_user_files() {
  local module_dir
  module_dir="$(portal_login_dir)"
  portal_login_install_file \
    "$module_dir/config/bin/myunix-portal-login" \
    "${MYUNIX_PORTAL_LOGIN_BIN_DIR:-$HOME/.local/bin}/myunix-portal-login" \
    755
  portal_login_install_file \
    "$module_dir/config/applications/myunix-portal-login.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/myunix-portal-login.desktop" \
    644
  portal_login_install_file \
    "$module_dir/config/autostart/myunix-nm-applet.desktop" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/myunix-nm-applet.desktop" \
    644
}

install_portal_login() {
  is_fedora || die 'Fedora is required'
  install_dnf_manifest "$(portal_login_dir)/packages.txt"
  install_portal_login_user_files
  require_command nm-applet
  info 'Portal Login installed. In DMS, use Mod+Space and search for Wi-Fi Login when a network needs web sign-in.'
}
