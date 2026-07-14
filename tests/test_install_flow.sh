#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_TEST_MODE=fedora "$PROJECT_ROOT/scripts/myunix" install --module unknown
assert_status 2
assert_output_contains 'Unknown module: unknown'
