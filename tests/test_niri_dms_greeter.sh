#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

rollback_script="$PROJECT_ROOT/modules/niri-dms-greeter/rollback.sh"
backup_dir="$(mktemp -d)"

run env MYUNIX_GREETER_BACKUP="$backup_dir" bash -c '
  sudo() { printf "sudo=%s\n" "$*"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$rollback_script"'"
  rollback_niri_dms_greeter "$MYUNIX_GREETER_BACKUP"
'
assert_status 0
assert_output_contains 'sudo=systemctl disable --now greetd'
assert_output_contains 'sudo=systemctl set-default graphical.target'
assert_output_contains 'sudo=systemctl enable --now gdm'
assert_output_contains 'GDM restored.'
