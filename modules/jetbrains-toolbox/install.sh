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

install_jetbrains_toolbox() {
  local archive temporary extracted source_root target marker bin_link
  require_command tar
  require_command curl
  archive="${MYUNIX_JETBRAINS_TOOLBOX_ARCHIVE:-}"
  temporary="$(mktemp -d)"
  trap 'rm -rf -- "$temporary"' RETURN
  if [[ -z "$archive" ]]; then
    archive="$temporary/jetbrains-toolbox.tar.gz"
    network_run download 'Downloading JetBrains Toolbox' curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$(jetbrains_toolbox_url)" || return 1
  fi
  [[ -f "$archive" ]] || die "JetBrains Toolbox archive not found: $archive"
  jetbrains_toolbox_archive_is_safe "$archive"
  extracted="$temporary/extracted"
  mkdir -p "$extracted"
  tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extracted"
  source_root="$(find "$extracted" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$source_root" && -x "$source_root/jetbrains-toolbox" ]] || die 'JetBrains Toolbox archive has no expected executable'
  target="$(jetbrains_toolbox_root)"
  marker="$target/.myunix-managed"
  if [[ -e "$target" && ! -f "$marker" ]]; then
    die "Refusing to replace unmanaged JetBrains Toolbox directory: $target"
  fi
  mkdir -p "$target"
  cp -a "$source_root"/. "$target"/
  printf '%s\n' 'Managed by MyUnix; source: JetBrains Toolbox official download.' > "$marker"
  chmod 0755 "$target/jetbrains-toolbox"
  bin_link="${MYUNIX_JETBRAINS_TOOLBOX_BIN:-$HOME/.local/bin/jetbrains-toolbox}"
  mkdir -p "$(dirname "$bin_link")"
  ln -sfn "$target/jetbrains-toolbox" "$bin_link"
  info "JetBrains Toolbox installed at $target"
}
