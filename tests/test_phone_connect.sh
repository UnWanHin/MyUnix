#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
mkdir -p "$temporary_dir/home/.config/niri"
printf '%s\n' 'include optional=true "dms/binds.kdl"' > "$temporary_dir/home/.config/niri/config.kdl"

run env HOME="$temporary_dir/home" MYUNIX_PHONE_CONNECT_DRY_RUN=1 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/phone-connect/install.sh'; import_kdeconnect_niri_fragment; ensure_kdeconnect_niri_include; ensure_kdeconnect_niri_include"
assert_status 0
assert_equals 1 "$(grep -c '^include optional=true "myunix/kdeconnect.kdl"$' "$temporary_dir/home/.config/niri/config.kdl")"
grep -Fqx 'spawn-at-startup "kdeconnectd"' "$temporary_dir/home/.config/niri/myunix/kdeconnect.kdl"

run env MYUNIX_PHONE_CONNECT_DRY_RUN=1 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/phone-connect/install.sh'; configure_kdeconnect_firewall"
assert_status 0
assert_output_contains 'Firewall changes skipped'

assert_equals 1 "$(grep -c '^include optional=true "myunix/kdeconnect.kdl"$' "$PROJECT_ROOT/modules/niri-dms/config/niri/config.kdl")"

run env HOME="$temporary_dir/home" MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$temporary_dir/state" MYUNIX_PHONE_CONNECT_SKIP_PACKAGES=1 MYUNIX_PHONE_CONNECT_SKIP_VERIFY=1 MYUNIX_PHONE_CONNECT_DRY_RUN=1 "$PROJECT_ROOT/scripts/myunix" install --module phone-connect
assert_status 0

run env HOME="$temporary_dir/home" MYUNIX_PHONE_CONNECT_CONFIG_SOURCE="$temporary_dir/exported" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/phone-connect/install.sh'; source '$PROJECT_ROOT/modules/phone-connect/export.sh'; export_phone_connect"
assert_status 0
assert_equals 'spawn-at-startup "kdeconnectd"' "$(tail -n 1 "$temporary_dir/exported/niri/myunix/kdeconnect.kdl")"
[[ ! -e "$temporary_dir/exported/kdeconnect" ]] || {
  printf '%s\n' 'Unexpected KDE Connect state export' >&2
  exit 1
}
