#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/install.sh"

export_zsh_personalization() {
  local source target
  source="$HOME/.p10k.zsh"
  target="$(zsh_p10k_source)"
  [[ -f "$source" ]] || {
    info 'No Powerlevel10k configuration to export'
    return 0
  }
  mkdir -p "$(dirname "$target")"
  cp -a "$source" "$target"
  info 'Powerlevel10k configuration exported for review'
}
