#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/state.sh"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export MYUNIX_STATE_DIR="$tmp/state"

state_mark 'rpm:qq' failed
state_mark 'dnf:git' succeeded
assert_equals 'rpm:qq' "$(state_failed_items)"

state_mark 'rpm:qq' succeeded
assert_equals '' "$(state_failed_items)"

state_mark 'module:input-method' deferred
assert_equals 'module:input-method' "$(state_failed_items)"
