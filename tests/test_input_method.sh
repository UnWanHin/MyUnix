#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/manifest.sh"
source "$PROJECT_ROOT/modules/dnf/install.sh"
source "$PROJECT_ROOT/modules/input-method/install.sh"

sudo() { printf '%s\n' "$*"; }
run install_input_methods
assert_status 0
assert_output_contains 'fcitx5-rime'
assert_output_contains 'Log out and back in'
