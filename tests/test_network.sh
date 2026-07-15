#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_NETWORK_ATTEMPTS=3 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  calls=0
  sleep() { :; }
  timeout() { shift 2; "$@"; }
  eventually_succeeds() { calls=$((calls + 1)); ((calls >= 3)); }
  network_run dnf "DNF test" eventually_succeeds
  printf "calls=%s\n" "$calls"
'
assert_status 0
assert_output_contains 'DNF test — attempt 1/3'
assert_output_contains 'calls=3'

run env MYUNIX_NETWORK_ATTEMPTS=2 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  calls=0
  sleep() { :; }
  timeout() { shift 2; "$@"; }
  always_fails() { calls=$((calls + 1)); return 7; }
  network_run dnf "Failure test" always_fails || status=$?
  printf "calls=%s status=%s\n" "$calls" "$status"
  exit 0
'
assert_status 0
assert_output_contains 'calls=2 status=7'

run bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  sleep() { :; }
  timeout() { printf "timeout=%s,%s\n" "$1" "$2"; shift 2; "$@"; }
  succeeds() { return 0; }
  MYUNIX_DNF_TIMEOUT_SECONDS=12 network_run dnf "DNF timeout" succeeds
  MYUNIX_DOWNLOAD_TIMEOUT_SECONDS=34 network_run download "Download timeout" succeeds
'
assert_status 0
assert_output_contains 'timeout=--foreground,12s'
assert_output_contains 'timeout=--foreground,34s'
