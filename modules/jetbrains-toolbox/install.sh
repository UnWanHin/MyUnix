#!/usr/bin/env bash
set -Eeuo pipefail
if ! declare -F require_command >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/core.sh"
fi
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

jetbrains_toolbox_url() {
  printf '%s\n' "${MYUNIX_JETBRAINS_TOOLBOX_URL:-https://data.services.jetbrains.com/products/download?code=TBA&platform=linux}"
}

jetbrains_toolbox_root() {
  printf '%s\n' "${MYUNIX_JETBRAINS_TOOLBOX_ROOT:-$HOME/.local/opt/jetbrains-toolbox}"
}

jetbrains_toolbox_archive_is_safe() {
  local archive=$1 entry
  while IFS= read -r entry; do
    [[ "$entry" != /* && "$entry" != *'../'* && "$entry" != *'/..' && "$entry" != ..* ]] || die 'Refusing unsafe JetBrains Toolbox archive path'
  done < <(tar -tzf "$archive")
}

install_jetbrains_toolbox_desktop_entry() {
  local target=$1 bin_link=$2 desktop_dir desktop_target desktop_source icon_path
  desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  desktop_target="$desktop_dir/jetbrains-toolbox.desktop"
  mkdir -p "$desktop_dir"
  desktop_source="$(find "$target" -type f -name jetbrains-toolbox.desktop -print -quit)"
  icon_path="$(find "$target" -type f \( -name toolbox.svg -o -name toolbox.png \) -print -quit)"
  if [[ -n "$desktop_source" ]]; then
    cp -f "$desktop_source" "$desktop_target"
  else
    {
      printf '%s\n' '[Desktop Entry]' 'Name=JetBrains Toolbox' 'Type=Application'
      printf 'Exec=%s %%u\n' "$bin_link"
      [[ -n "$icon_path" ]] && printf 'Icon=%s\n' "$icon_path"
      printf '%s\n' 'Categories=Development;' 'Terminal=false' 'StartupNotify=true'
    } > "$desktop_target"
  fi
  sed -i -E "s|^Exec=.*|Exec=$bin_link %u|" "$desktop_target"
  if [[ -n "$icon_path" ]]; then
    if grep -q '^Icon=' "$desktop_target"; then
      sed -i -E "s|^Icon=.*|Icon=$icon_path|" "$desktop_target"
    else
      printf 'Icon=%s\n' "$icon_path" >> "$desktop_target"
    fi
  fi
  chmod 0644 "$desktop_target"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  fi
}

install_jetbrains_toolbox() {
  local archive temporary extracted source_binary relative root_name source_root
  local toolbox_binary_rel target marker bin_link target_binary
  require_command tar
  require_command curl
  target="$(jetbrains_toolbox_root)"
  marker="$target/.myunix-managed"
  bin_link="${MYUNIX_JETBRAINS_TOOLBOX_BIN:-$HOME/.local/bin/jetbrains-toolbox}"
  if [[ -e "$target" && ! -f "$marker" ]]; then
    die "Refusing to replace unmanaged JetBrains Toolbox directory: $target"
  fi
  if [[ -f "$marker" && -x "$bin_link" ]]; then
    install_jetbrains_toolbox_desktop_entry "$target" "$bin_link"
    info "JetBrains Toolbox already installed; skipping download"
    return 0
  fi
  archive="${MYUNIX_JETBRAINS_TOOLBOX_ARCHIVE:-}"
  temporary="$(mktemp -d)"
  trap 'rm -rf -- "$temporary"; trap - RETURN' RETURN
  if [[ -z "$archive" ]]; then
    archive="$temporary/jetbrains-toolbox.tar.gz"
    network_run download 'Downloading JetBrains Toolbox' curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$(jetbrains_toolbox_url)" || return 1
  fi
  [[ -f "$archive" ]] || die "JetBrains Toolbox archive not found: $archive"
  jetbrains_toolbox_archive_is_safe "$archive"
  extracted="$temporary/extracted"
  mkdir -p "$extracted"
  tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extracted"
  source_binary="$(find "$extracted" -type f -name jetbrains-toolbox -print -quit)"
  [[ -n "$source_binary" && -x "$source_binary" ]] || die 'JetBrains Toolbox archive has no expected executable'
  relative="${source_binary#"$extracted"/}"
  root_name="${relative%%/*}"
  if [[ "$relative" == "$root_name" ]]; then
    source_root="$extracted"
    toolbox_binary_rel="$relative"
  else
    source_root="$extracted/$root_name"
    toolbox_binary_rel="${relative#"$root_name"/}"
  fi
  mkdir -p "$target"
  cp -a "$source_root"/. "$target"/
  printf '%s\n' 'Managed by MyUnix; source: JetBrains Toolbox official download.' > "$marker"
  target_binary="$target/$toolbox_binary_rel"
  chmod 0755 "$target_binary"
  mkdir -p "$(dirname "$bin_link")"
  ln -sfn "$target_binary" "$bin_link"
  install_jetbrains_toolbox_desktop_entry "$target" "$bin_link"
  info "JetBrains Toolbox installed at $target"
}
