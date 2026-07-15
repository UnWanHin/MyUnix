#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_TEST_MODE=fedora bash -c '
  sudo() { printf "%s\n" "$*"; }
  timeout() { shift 2; "$@"; }
  distrobox() { :; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/distrobox/install.sh"
  install_distrobox
'
assert_status 0
assert_output_contains 'dnf install -y distrobox'
assert_output_contains 'Distrobox installed'
