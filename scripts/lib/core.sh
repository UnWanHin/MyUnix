#!/usr/bin/env bash
set -Eeuo pipefail

readonly MYUNIX_ROOT="${MYUNIX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

state_dir() {
  printf '%s\n' "${MYUNIX_STATE_DIR:-$HOME/.local/state/myunix}"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

info() {
  printf '%s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

is_fedora() {
  case "${MYUNIX_TEST_MODE:-}" in
    fedora) return 0 ;;
    nonfedora) return 1 ;;
  esac

  [[ -r /etc/fedora-release ]]
}
