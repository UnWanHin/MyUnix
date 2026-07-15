#!/usr/bin/env bash
set -Eeuo pipefail

input_method_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

input_method_app_profiles_path() {
  printf '%s\n' "${MYUNIX_INPUT_METHOD_APP_PROFILES:-$(input_method_dir)/app-profiles.tsv}"
}

input_method_system_applications_dir() {
  printf '%s\n' "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
}

input_method_user_applications_dir() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
}

input_method_launcher_backup_dir() {
  if [[ -z "${MYUNIX_INPUT_METHOD_LAUNCHER_BACKUP_DIR:-}" ]]; then
    MYUNIX_INPUT_METHOD_LAUNCHER_BACKUP_DIR="$HOME/.local/state/myunix/backups/input-method/$(date +%Y%m%d-%H%M%S)/desktop-launchers"
  fi
  printf '%s\n' "$MYUNIX_INPUT_METHOD_LAUNCHER_BACKUP_DIR"
}

backup_input_method_launcher() {
  local launcher=$1 backup
  [[ -e "$launcher" ]] || return 0
  backup="$(input_method_launcher_backup_dir)/$(basename "$launcher")"
  [[ -e "$backup" ]] && return 0
  mkdir -p "$(dirname "$backup")"
  cp -a "$launcher" "$backup"
}

render_input_method_launcher() {
  local source_launcher=$1 target_launcher=$2 profile=$3 temporary prefix electron_flag
  case "$profile" in
    qt-fcitx)
      prefix='env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx QT_IM_MODULES=fcitx '
      electron_flag=0
      ;;
    electron-wayland-ime)
      prefix='env XMODIFIERS=@im=fcitx ELECTRON_OZONE_PLATFORM_HINT=auto '
      electron_flag=1
      ;;
    *) die "Unknown input-method application profile: $profile" ;;
  esac

  temporary="$(mktemp "${target_launcher}.myunix.XXXXXX")"
  awk -v prefix="$prefix" -v electron_flag="$electron_flag" '
    /^Exec=/ {
      command_line = substr($0, 6)
      if (electron_flag) {
        if (match(command_line, /%[fFuUdDnNickvm]/)) {
          command_line = substr(command_line, 1, RSTART - 1) "--enable-wayland-ime " substr(command_line, RSTART)
        } else {
          command_line = command_line " --enable-wayland-ime"
        }
      }
      print "Exec=" prefix command_line
      next
    }
    { print }
  ' "$source_launcher" > "$temporary"
  mv "$temporary" "$target_launcher"
}

install_input_method_app_overrides() {
  local profiles system_dir target_dir id desktop_file profile source_launcher target_launcher temporary
  profiles="$(input_method_app_profiles_path)"
  [[ -f "$profiles" ]] || die "Missing input-method application profiles: $profiles"
  system_dir="$(input_method_system_applications_dir)"
  target_dir="$(input_method_user_applications_dir)"

  while IFS='|' read -r id desktop_file profile; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    source_launcher="$system_dir/$desktop_file"
    [[ -f "$source_launcher" ]] || continue
    target_launcher="$target_dir/$desktop_file"
    mkdir -p "$target_dir"
    temporary="$(mktemp "${target_launcher}.myunix.XXXXXX")"
    render_input_method_launcher "$source_launcher" "$temporary" "$profile"
    if [[ -f "$target_launcher" ]] && cmp -s "$temporary" "$target_launcher"; then
      rm -f "$temporary"
      continue
    fi
    backup_input_method_launcher "$target_launcher"
    mv "$temporary" "$target_launcher"
    info "Installed input-method launcher override for $id"
  done < "$profiles"
}

import_fcitx5_public_config() {
  local source target backup_dir file
  source="${MYUNIX_FCITX_CONFIG_SOURCE:-$(input_method_dir)/config/fcitx5}"
  [[ -d "$source" ]] || return 0

  target="$HOME/.config/fcitx5"
  backup_dir="$HOME/.local/state/myunix/backups/input-method/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$target"
  for file in config profile; do
    [[ -f "$source/$file" ]] || continue
    if [[ -e "$target/$file" ]]; then
      mkdir -p "$backup_dir"
      cp -a "$target/$file" "$backup_dir/$file"
    fi
    cp -a "$source/$file" "$target/$file"
  done
}

install_input_methods() {
  install_dnf_manifest "$(input_method_dir)/packages.txt"
  import_fcitx5_public_config
  install_input_method_app_overrides
  info 'Input method packages installed. Log out and back in before configuring GNOME or Niri input sources.'
}
