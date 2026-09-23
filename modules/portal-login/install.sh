#!/usr/bin/env bash
set -Eeuo pipefail

portal_login_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

portal_login_install_file() {
  local source_file=$1 target_file=$2 mode=$3 temporary backup_dir status
  [[ -f "$source_file" ]] || die "Missing portal-login source file: $source_file"
  if [[ -e "$target_file" && ! -f "$target_file" && ! -L "$target_file" ]]; then
    printf 'ERROR: Portal Login target is not a file: %s\n' "$target_file" >&2
    return 1
  fi
  if [[ -f "$target_file" ]] && cmp -s "$source_file" "$target_file" \
      && [[ "$(stat -Lc '%a' "$target_file")" == "$mode" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$target_file")" || return $?
  temporary="$(mktemp "${target_file}.myunix.XXXXXX")" || return $?
  install -m "$mode" "$source_file" "$temporary" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  if [[ -e "$target_file" || -L "$target_file" ]]; then
    backup_dir="$HOME/.local/state/myunix/backups/portal-login"
    if mkdir -p "$backup_dir" \
        && backup_dir="$(mktemp -d "$backup_dir/$(date +%Y%m%d-%H%M%S).XXXXXX")" \
        && cp -a "$target_file" "$backup_dir/$(basename "$target_file")"; then
      :
    else
      status=$?
      rm -f "$temporary"
      return "$status"
    fi
  fi
  mv -T "$temporary" "$target_file" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
}

install_portal_login_user_files() {
  local module_dir
  module_dir="$(portal_login_dir)"
  portal_login_install_file \
    "$module_dir/config/bin/myunix-portal-login" \
    "${MYUNIX_PORTAL_LOGIN_BIN_DIR:-$HOME/.local/bin}/myunix-portal-login" \
    755 || return $?
  portal_login_install_file \
    "$module_dir/config/applications/myunix-portal-login.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/myunix-portal-login.desktop" \
    644 || return $?
  portal_login_install_file \
    "$module_dir/config/autostart/myunix-nm-applet.desktop" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/myunix-nm-applet.desktop" \
    644
}

install_portal_login() {
  is_fedora || die 'Fedora is required'
  install_dnf_manifest "$(portal_login_dir)/packages.txt" || return $?
  install_portal_login_user_files || return $?
  require_command nm-applet || return $?
  info 'Portal Login installed. In DMS, use Mod+Space and search for Wi-Fi Login when a network needs web sign-in.'
}
