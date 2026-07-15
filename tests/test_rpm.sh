#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/rpm/install.sh"

payload='package payload'
checksum="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
wget() {
  local output
  while (($#)); do
    [[ "$1" == -O ]] && { output=$2; shift 2; continue; }
    shift
  done
  printf '%s' "$payload" > "$output"
}
sudo() { printf '%s\n' "$*"; }
rpm() { printf '%s\n' "$*"; }
timeout() { shift 2; "$@"; }

run install_rpm_record qq QQ https://example.test/qq.rpm "$checksum" optional rpm qq
assert_status 0
assert_output_contains 'dnf install -y'
assert_output_contains '-q qq'

run install_rpm_record qq QQ https://example.test/qq.rpm "${checksum/a/b}" optional rpm qq
assert_status 1
assert_output_contains 'Checksum mismatch for QQ'
