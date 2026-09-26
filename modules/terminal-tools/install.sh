#!/usr/bin/env bash
set -Eeuo pipefail

if ! declare -F require_command >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/core.sh"
fi
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

readonly TERMINAL_TOOLS_LAZYDOCKER_VERSION='0.25.2'
readonly TERMINAL_TOOLS_LAZYDOCKER_URL='https://github.com/jesseduffield/lazydocker/releases/download/v0.25.2/lazydocker_0.25.2_Linux_x86_64.tar.gz'
readonly TERMINAL_TOOLS_LAZYDOCKER_SHA256='0d9dbfc26068b218e7ed84b104748cadc6e3cf733c0afd35465306fb39b9523c'

terminal_tools_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

terminal_tools_lazydocker_target() {
  printf '%s\n' "${MYUNIX_LAZYDOCKER_TARGET:-/usr/local/bin/lazydocker}"
}

install_terminal_tools_lazydocker() (
  local target archive workdir actual_sha
  target="$(terminal_tools_lazydocker_target)"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -x "$target" ]] && "$target" --version 2>&1 | grep -Fq "Version: $TERMINAL_TOOLS_LAZYDOCKER_VERSION"; then
      info "lazydocker $TERMINAL_TOOLS_LAZYDOCKER_VERSION already installed"
      return 0
    fi
    die "Refusing to replace an unmanaged lazydocker executable: $target"
  fi

  require_command curl
  require_command tar
  require_command sha256sum
  workdir="$(mktemp -d)"
  trap 'rm -rf -- "$workdir"' EXIT
  archive="$workdir/lazydocker.tar.gz"
  if ! network_run download "Downloading lazydocker $TERMINAL_TOOLS_LAZYDOCKER_VERSION" \
    curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$TERMINAL_TOOLS_LAZYDOCKER_URL"; then
    return 1
  fi
  actual_sha="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "$actual_sha" != "$TERMINAL_TOOLS_LAZYDOCKER_SHA256" ]]; then
    die "lazydocker checksum mismatch (expected $TERMINAL_TOOLS_LAZYDOCKER_SHA256, got $actual_sha)"
  fi
  mkdir "$workdir/extracted"
  tar --extract --gzip --file "$archive" --directory "$workdir/extracted" \
    --no-same-owner --no-same-permissions lazydocker
  [[ -x "$workdir/extracted/lazydocker" ]] || {
    die 'Official lazydocker archive did not contain an executable lazydocker file'
  }
  sudo install -D -m 0755 "$workdir/extracted/lazydocker" "$target"
  if [[ ! -x "$target" ]] || ! "$target" --version 2>&1 | grep -Fq "Version: $TERMINAL_TOOLS_LAZYDOCKER_VERSION"; then
    die "lazydocker $TERMINAL_TOOLS_LAZYDOCKER_VERSION was not installed at $target"
  fi
  info "Installed lazydocker $TERMINAL_TOOLS_LAZYDOCKER_VERSION at $target"
)

install_terminal_tools() {
  is_fedora || die 'Fedora is required'
  install_dnf_manifest "$(terminal_tools_dir)/packages.txt"
  install_terminal_tools_lazydocker
  info 'Terminal productivity tools installed; open a new Zsh session to load optional integrations.'
}
