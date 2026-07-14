#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/gnome/install.sh"

tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
export MYUNIX_STATE_DIR="$tmp/state"
export MYUNIX_GNOME_DIR="$tmp/config"
mkdir -p "$MYUNIX_GNOME_DIR"
printf '[custom-keybindings]\n' > "$MYUNIX_GNOME_DIR/media-keys.ini"
dconf() { [[ "$1" == dump ]] && printf '[old]\n' || cat >/dev/null; }

run import_gnome
assert_status 0
assert_output_contains 'GNOME settings restored'
[[ -f "$tmp/state/backups/gnome/media-keys.ini" ]]
