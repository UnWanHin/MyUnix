#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

run env MYUNIX_TEST_MODE=fedora "$PROJECT_ROOT/scripts/myunix" install --module unknown
assert_status 2
assert_output_contains 'Unknown module: unknown'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_UI_TEST_MODE=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  ui_choose_many() {
    if [[ "$1" == "Choose input methods" ]]; then
      printf "0\\n1\\n"
    fi
  }
  run_module() {
    if [[ "$1" == input-method ]]; then
      printf "input:%s:%s\\n" "$MYUNIX_INPUT_CANGJIE" "$MYUNIX_INPUT_PINYIN"
    fi
    return 0
  }
  run_custom_install
'
assert_status 0
assert_output_contains 'input:1:0'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_UI_TEST_MODE=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  ui_choose_many() {
    case "$1" in
      "Choose input methods") printf "0\\n" ;;
      "Optional desktop modules") printf "0\\n" ;;
      "Niri + DMS personalization") printf "0\\n" ;;
    esac
  }
  run_module() {
    [[ "$1" == niri-dms ]] && printf "niri-dms:%s\\n" "$MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE"
    return 0
  }
  run_custom_install
'
assert_status 0
assert_output_contains 'niri-dms:1'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  run_module() {
    printf "module:%s\\n" "$1"
    if [[ "$1" == input-method ]]; then
      printf "input:%s:%s\\n" "$MYUNIX_INPUT_CANGJIE" "$MYUNIX_INPUT_PINYIN"
    fi
    return 0
  }
  run_all_install
'
assert_status 0
assert_output_contains 'input:1:1'
assert_output_contains 'module:steam'
assert_output_contains 'module:time-sync'

run env MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$temporary/state" bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  install_time_sync() { printf "time-sync dispatched\n"; }
  run_module time-sync
'
assert_status 0
assert_output_contains 'time-sync dispatched'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_UI_TEST_MODE=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  ui_choose_many() {
    case "$1" in
      "Choose input methods") printf "0\\n" ;;
      "Optional desktop applications") printf "0\\n" ;;
    esac
  }
  run_module() { printf "module:%s\\n" "$1"; return 0; }
  run_custom_install
'
assert_status 0
assert_output_contains 'module:steam'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_UI_TEST_MODE=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  ui_choose_many() {
    case "$1" in
      "Choose input methods") printf "0\n" ;;
      "Optional modules") printf "0\n" ;;
      "Development toolchain components") printf "1\n2\n6\n" ;;
    esac
  }
  ui_choose_one() { printf "1\n"; }
  run_module() {
    if [[ "$1" == development-toolchain ]]; then
      printf "toolchain:%s:%s\n" "$MYUNIX_TOOLCHAIN_SCOPE" "$MYUNIX_TOOLCHAIN_COMPONENTS"
    fi
    return 0
  }
  run_custom_install
'
assert_status 0
assert_output_contains 'toolchain:user:jdk,cmake,anaconda'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_UI_TEST_MODE=1 MYUNIX_UI_NO_RENDER=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  first_calls=0
  run_module() {
    if [[ "$1" == first ]]; then
      first_calls=$((first_calls + 1))
      ((first_calls > 1))
      return
    fi
    return 0
  }
  ui_choose_failure_action() { printf "retry\n"; }
  run_selected_modules first second
  printf "first_calls=%s\n" "$first_calls"
'
assert_status 0
assert_output_contains '[1/2] first'
assert_output_contains 'first_calls=2'
assert_output_contains 'Installation summary: succeeded=2 skipped=0 failed=0 deferred=0'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_UI_TEST_MODE=1 MYUNIX_UI_NO_RENDER=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  second_calls=0
  run_module() { [[ "$1" == first ]] && return 1; second_calls=$((second_calls + 1)); }
  state_mark() { printf "state:%s:%s\n" "$1" "$2"; }
  ui_choose_failure_action() { printf "skip\n"; }
  run_selected_modules first second || status=$?
  printf "second_calls=%s status=%s\n" "$second_calls" "$status"
'
assert_status 0
assert_output_contains 'state:module:first:deferred'
assert_output_contains 'second_calls=1 status=1'
assert_output_contains 'Installation summary: succeeded=1 skipped=0 failed=0 deferred=1'

run bash -c '
  export MYUNIX_SOURCE_ONLY=1 MYUNIX_UI_TEST_MODE=1 MYUNIX_UI_NO_RENDER=1
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  calls=0
  run_module() { calls=$((calls + 1)); return 1; }
  ui_choose_failure_action() { printf "stop\n"; }
  run_selected_modules first second || status=$?
  printf "calls=%s status=%s\n" "$calls" "$status"
'
assert_status 0
assert_output_contains 'calls=1 status=1'
