#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/bootstrap/install.sh"

rpm() { printf '42\n'; }
sudo() { printf '%s\n' "$*"; }
export MYUNIX_TEST_MODE=fedora

run install_bootstrap
assert_status 0
assert_output_contains 'dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-42.noarch.rpm'
assert_output_contains 'rpmfusion-nonfree-release-42.noarch.rpm'
