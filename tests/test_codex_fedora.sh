#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_TEST_MODE=fedora bash -c '
  sudo() { printf "%s\n" "$*"; }
  timeout() { shift 2; "$@"; }
  npm() { printf "npm %s\n" "$*"; }
  codex() { [[ "$1" == --version ]]; }
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/scripts/lib/manifest.sh"
  source "'$PROJECT_ROOT'/scripts/lib/network.sh"
  source "'$PROJECT_ROOT'/modules/codex-fedora/install.sh"
  install_dnf_manifest() { printf "dnf manifest %s\n" "$1"; }
  install_codex_fedora
'
assert_status 0
assert_output_contains 'dnf manifest'
assert_output_contains 'npm install --global --no-audit --no-fund @openai/codex'
assert_output_contains 'Fedora Codex CLI installed'

run grep -F 'codex-fedora) install_codex_fedora' "$PROJECT_ROOT/scripts/myunix"
assert_status 0

run grep -F '"$ROOT/modules/codex-fedora/packages.txt"' "$PROJECT_ROOT/scripts/myunix"
assert_status 0
