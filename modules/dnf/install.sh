#!/usr/bin/env bash
set -Eeuo pipefail

install_dnf_manifest() {
  local manifest=$1 line
  local -a packages=()
  validate_dnf_manifest "$manifest" || die "Invalid DNF manifest: $manifest"

  while IFS= read -r line || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    packages+=("$line")
  done < "$manifest"

  ((${#packages[@]})) || return 0
  sudo dnf install -y "${packages[@]}"
}
