#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/manifest.sh"
source "$PROJECT_ROOT/modules/dnf/install.sh"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
printf 'git\nwget\n' > "$tmp/packages.txt"
sudo() { printf '%s\n' "$*"; }

run install_dnf_manifest "$tmp/packages.txt"
assert_status 0
assert_output_contains 'dnf install -y git wget'

printf 'vlc\nffmpeg\n' > "$tmp/optional.txt"
set +e
OUTPUT="$(printf 'y\nn\n' | install_optional_dnf_manifest "$tmp/optional.txt" 2>&1)"
STATUS=$?
set -e
assert_status 0
assert_output_contains 'dnf install -y vlc'
assert_output_contains 'Skip ffmpeg'
