#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

install_rpm_record() {
  local id=$1 name=$2 url=$3 expected_sha=$4 selection=$5 verify_command=$6 verify_argument=$7
  local tmp actual_sha package
  [[ "$url" =~ ^https:// ]] || die "RPM URL for $name must use HTTPS"
  [[ "$expected_sha" =~ ^[[:xdigit:]]{64}$ ]] || die "RPM checksum for $name is invalid"
  [[ "$verify_command" == rpm ]] || die "Unsupported RPM verifier for $name"

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
