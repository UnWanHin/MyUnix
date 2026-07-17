#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

run env HOME="$temporary/portable-user" MYUNIX_TEST_MODE=fedora \
  MYUNIX_TIME_SYNC_DIR="$PROJECT_ROOT/modules/time-sync" bash -c '
  sudo() { printf "sudo:%s\n" "$*"; "$@"; }
  dnf() { printf "dnf:%s\n" "$*"; }
  systemctl() { printf "systemctl:%s\n" "$*"; }
  chronyc() { printf "chronyc:%s\n" "$*"; }
  timedatectl() { printf "timedatectl:%s\n" "$*"; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/time-sync/install.sh"
  install_time_sync
'
assert_status 0
assert_output_contains 'dnf:install -y chrony'
assert_output_contains 'systemctl:enable --now chronyd.service'
assert_output_contains 'chronyc:waitsync 10 0.1'
assert_output_contains 'chronyc:makestep'
assert_output_contains 'timedatectl:set-local-rtc 0'
[[ "$OUTPUT" != *hiraeth* ]] || {
  printf '%s\n' 'Time-sync output must not depend on a local user name' >&2
  exit 1
}

run env MYUNIX_TEST_MODE=fedora MYUNIX_TIME_SYNC_WAIT_ATTEMPTS=0 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/modules/time-sync/install.sh"
  install_time_sync
'
assert_status 2
assert_output_contains 'MYUNIX_TIME_SYNC_WAIT_ATTEMPTS must be a positive integer'
