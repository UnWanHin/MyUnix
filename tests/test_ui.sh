#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run bash -c '
  export MYUNIX_UI_TEST_MODE=1 MYUNIX_UI_NO_RENDER=1
  source "'"$PROJECT_ROOT"'/scripts/lib/ui.sh"
  queue="$(mktemp)"
  trap "rm -f \"$queue\"" EXIT
  printf "down\nenter\n" > "$queue"
  ui_read_key() { head -n 1 "$queue"; sed -i "1d" "$queue"; }
  ui_choose_one "Install mode" "One-click" "Custom"
'
assert_status 0
assert_equals 1 "$OUTPUT"

run bash -c '
  export MYUNIX_UI_TEST_MODE=1 MYUNIX_UI_NO_RENDER=1
  source "'"$PROJECT_ROOT"'/scripts/lib/ui.sh"
  queue="$(mktemp)"
  trap "rm -f \"$queue\"" EXIT
  printf "space\ndown\nspace\nenter\n" > "$queue"
  ui_read_key() { head -n 1 "$queue"; sed -i "1d" "$queue"; }
  ui_choose_many "Input methods" "0" "English" "Cangjie" "Pinyin"
'
assert_status 0
assert_equals $'0\n1' "$OUTPUT"
