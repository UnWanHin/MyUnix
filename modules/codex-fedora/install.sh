#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

codex_fedora_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

install_codex_fedora() {
  local package_name=${MYUNIX_CODEX_NPM_PACKAGE:-@openai/codex}
  is_fedora || die 'Fedora is required'
  install_dnf_manifest "$(codex_fedora_dir)/packages.txt"
  require_command npm
  network_run npm 'Installing official Fedora Codex npm package' \
    sudo npm install --global --no-audit --no-fund "$package_name"
  require_command codex
  codex --version >/dev/null
  info "Fedora Codex CLI installed: $package_name"
}
