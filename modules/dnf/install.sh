#!/usr/bin/env bash
set -Eeuo pipefail

manifest_packages() {
  local manifest=$1 line
  validate_dnf_manifest "$manifest" || die "Invalid DNF manifest: $manifest"

  while IFS= read -r line || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    printf '%s\n' "$line"
  done < "$manifest"
}

verify_dnf_manifest_available() {
  local manifest=$1 package missing=0

  while IFS= read -r package; do
    dnf repoquery --available --quiet "$package" >/dev/null 2>&1 || {
      printf 'Missing DNF package from enabled repositories: %s\n' "$package" >&2
      missing=1
    }
  done < <(manifest_packages "$manifest")

  return "$missing"
}

install_dnf_manifest() {
  local manifest=$1 package
  local -a packages=()

  while IFS= read -r package; do
    packages+=("$package")
  done < <(manifest_packages "$manifest")

  ((${#packages[@]})) || return 0
  sudo dnf install -y "${packages[@]}"
}

install_optional_dnf_manifest() {
  local manifest=$1 line reply
  validate_dnf_manifest "$manifest" || die "Invalid DNF manifest: $manifest"

  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    read -r -p "Install ${line}? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      sudo dnf install -y "$line"
    else
      info "Skip $line"
    fi
  done 3< "$manifest"
}
