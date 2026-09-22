#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

install_rpm_record() {
  local id=$1 name=$2 url=$3 expected_sha=$4 selection=$5 verify_command=$6 verify_argument=$7
  local tmp actual_sha package
  [[ "$url" =~ ^https:// ]] || die "RPM URL for $name must use HTTPS"
  [[ "$expected_sha" =~ ^[[:xdigit:]]{64}$ ]] || die "RPM checksum for $name is invalid"
  [[ "$verify_command" == rpm ]] || die "Unsupported RPM verifier for $name"
  if "$verify_command" -q "$verify_argument" >/dev/null 2>&1; then
    info "$name already installed; skipping download"
    return 0
  fi

  tmp="$(mktemp -d)"
  package="$tmp/$id.rpm"
  if ! network_run download "Downloading $name" wget --https-only --quiet --show-progress -O "$package" "$url"; then
    rm -rf -- "$tmp"
    return 1
  fi
  actual_sha="$(sha256sum "$package" | awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    printf 'Checksum mismatch for %s\n' "$name" >&2
    rm -rf -- "$tmp"
    return 1
  fi
  if ! network_run dnf "Installing $name RPM" sudo dnf install -y "$package"; then
    rm -rf -- "$tmp"
    return 1
  fi
  rm -rf -- "$tmp"
  "$verify_command" -q "$verify_argument"
}

prompt_optional_app() {
  local id=$1 name=$2 reply
  read -r -p "Install ${name}? [y/N] " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

flclash_desktop_entry_path() {
  printf '%s\n' "${MYUNIX_FLCLASH_DESKTOP_ENTRY:-${XDG_DATA_HOME:-$HOME/.local/share}/applications/flclash.desktop}"
}

flclash_desktop_entry_exists() {
  local user_entry system_entry
  user_entry="$(flclash_desktop_entry_path)"
  [[ -f "$user_entry" ]] && return 0
  for system_entry in \
    "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}/flclash.desktop" \
    "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}/FlClash.desktop"; do
    [[ -f "$system_entry" ]] && return 0
  done
  return 1
}

install_flclash_desktop_entry() {
  local target executable
  target="$(flclash_desktop_entry_path)"
  executable="${MYUNIX_FLCLASH_EXECUTABLE:-FlClash}"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<EOF
[Desktop Entry]
Name=FlClash
Comment=Cross-platform proxy client
Exec=$executable %U
Icon=FlClash
Terminal=false
Type=Application
Categories=Network;
StartupNotify=true
EOF
  chmod 0644 "$target"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$(dirname "$target")"
  fi
  info "Registered FlClash desktop entry: $target"
}
