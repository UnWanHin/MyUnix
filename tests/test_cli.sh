#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_TEST_MODE=nonfedora "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 2
assert_output_contains 'Fedora is required'

run env MYUNIX_TEST_MODE=fedora "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 0
assert_output_contains 'Fedora environment verified'
