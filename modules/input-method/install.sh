#!/usr/bin/env bash
set -Eeuo pipefail

input_method_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

input_method_packages_path() {
  printf '%s\n' "${MYUNIX_INPUT_METHOD_PACKAGES:-$(input_method_dir)/packages.tsv}"
}

input_method_validate_selection() {
  local selection=$1 label=$2
  [[ "$selection" == 0 || "$selection" == 1 ]] || die "Invalid ${label} selection: ${selection}"
}

input_method_resolve_packages() {
  local cangjie=$1 pinyin=$2 manifest group package
  local -A enabled=([base]=1 [cangjie]="$cangjie" [pinyin]="$pinyin") seen=()
  input_method_validate_selection "$cangjie" cangjie
  input_method_validate_selection "$pinyin" pinyin
  manifest="$(input_method_packages_path)"
  [[ -f "$manifest" ]] || die "Missing input-method package registry: $manifest"

  while IFS='|' read -r group package; do
    [[ -z "$group" || "$group" == \#* ]] && continue
    [[ -n "${enabled[$group]:-}" ]] || die "Unknown input-method package group: $group"
    [[ "${enabled[$group]}" == 1 && -n "$package" ]] || continue
    [[ -n "${seen[$package]:-}" ]] && continue
    seen[$package]=1
    printf '%s\n' "$package"
  done < "$manifest"
}

input_method_render_fcitx_profile() {
  local target=$1 cangjie=$2 pinyin=$3 item=1
  input_method_validate_selection "$cangjie" cangjie
  input_method_validate_selection "$pinyin" pinyin
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=keyboard-us

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=
EOF
  if [[ "$cangjie" == 1 ]]; then
    cat >> "$target" <<EOF

[Groups/0/Items/${item}]
# Name
Name=cangjie5
# Layout
Layout=
EOF
    item=$((item + 1))
  fi
  if [[ "$pinyin" == 1 ]]; then
    cat >> "$target" <<EOF

[Groups/0/Items/${item}]
# Name
Name=pinyin
# Layout
Layout=
EOF
  fi
  cat >> "$target" <<'EOF'

[GroupOrder]
0=Default
EOF
}

input_method_app_profiles_path() {
  printf '%s\n' "${MYUNIX_INPUT_METHOD_APP_PROFILES:-$(input_method_dir)/app-profiles.tsv}"
}

input_method_system_applications_dir() {
  printf '%s\n' "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
}

input_method_flatpak_user_applications_dir() {
  printf '%s\n' "${MYUNIX_FLATPAK_USER_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications}"
}

input_method_flatpak_system_applications_dir() {
  if [[ -n "${MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR:-}" ]]; then
    printf '%s\n' "$MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR"
  else
    printf '%s\n' /var/lib/flatpak/exports/share/applications
    printf '%s\n' /usr/share/flatpak/exports/share/applications
  fi
}

input_method_launcher_source_dirs() {
  case "${1:-}" in
    system)
      input_method_system_applications_dir
      ;;
    flatpak)
      input_method_flatpak_user_applications_dir
      input_method_flatpak_system_applications_dir
      ;;
    *)
      die "Unknown input-method launcher source: $1"
      ;;
  esac
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
  local wanted_id=${1:-} profiles target_dir id desktop_file profile source_kind source_dir source_launcher target_launcher temporary
  local -A seen_desktop_files=()
  profiles="$(input_method_app_profiles_path)"
  [[ -f "$profiles" ]] || die "Missing input-method application profiles: $profiles"
  target_dir="$(input_method_user_applications_dir)"

  while IFS='|' read -r id desktop_file profile source_kind; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    [[ -z "$wanted_id" || "$id" == "$wanted_id" ]] || continue
    source_kind=${source_kind:-system}
    while IFS= read -r source_dir; do
      [[ -n "$source_dir" ]] || continue
      source_launcher="$source_dir/$desktop_file"
      [[ -f "$source_launcher" ]] || continue
      [[ -n "${seen_desktop_files[$desktop_file]:-}" ]] && continue
      seen_desktop_files[$desktop_file]=1
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
    done < <(input_method_launcher_source_dirs "$source_kind")
  done < "$profiles"
}

input_method_installed_launcher_variants() {
  local wanted_id=$1 profiles id desktop_file profile source_kind source_dir source_launcher
  local -A seen_desktop_files=()
  profiles="$(input_method_app_profiles_path)"
  [[ -f "$profiles" ]] || die "Missing input-method application profiles: $profiles"

  while IFS='|' read -r id desktop_file profile source_kind; do
    [[ -z "$id" || "$id" == \#* || "$id" != "$wanted_id" ]] && continue
    source_kind=${source_kind:-system}
    while IFS= read -r source_dir; do
      [[ -n "$source_dir" ]] || continue
      source_launcher="$source_dir/$desktop_file"
      [[ -f "$source_launcher" ]] || continue
      [[ -n "${seen_desktop_files[$desktop_file]:-}" ]] && continue
      seen_desktop_files[$desktop_file]=1
      printf '%s|%s|%s\n' "$desktop_file" "$source_launcher" "$profile"
    done < <(input_method_launcher_source_dirs "$source_kind")
  done < "$profiles"
}

import_fcitx5_public_config() {
  local cangjie=${1:-1} pinyin=${2:-1} source target backup_dir file
  source="${MYUNIX_FCITX_CONFIG_SOURCE:-$(input_method_dir)/config/fcitx5}"
  [[ -d "$source" ]] || return 0

  target="$HOME/.config/fcitx5"
  backup_dir="$HOME/.local/state/myunix/backups/input-method/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$target"
  for file in config profile; do
    [[ -f "$source/$file" || "$file" == profile ]] || continue
    if [[ -e "$target/$file" ]]; then
      mkdir -p "$backup_dir"
      cp -a "$target/$file" "$backup_dir/$file"
    fi
    if [[ "$file" == profile ]]; then
      input_method_render_fcitx_profile "$target/$file" "$cangjie" "$pinyin"
    else
      cp -a "$source/$file" "$target/$file"
    fi
  done
}

install_input_methods() {
  local cangjie=${1:-1} pinyin=${2:-1} application=${3:-} manifest
  manifest="$(mktemp)"
  if ! input_method_resolve_packages "$cangjie" "$pinyin" > "$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  info 'Installing input-method packages'
  if ! install_dnf_manifest "$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  info 'Writing public Fcitx5 configuration'
  if ! import_fcitx5_public_config "$cangjie" "$pinyin"; then
    rm -f "$manifest"
    return 1
  fi
  if ! install_input_method_app_overrides "$application"; then
    rm -f "$manifest"
    return 1
  fi
  rm -f "$manifest"
  info 'Input method packages installed. Log out and back in before using GNOME or Niri input sources.'
}
