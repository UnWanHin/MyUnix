#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

run env MYUNIX_UI_TEST_MODE=0 bash -c "
  source '$PROJECT_ROOT/scripts/lib/core.sh'
  source '$PROJECT_ROOT/scripts/lib/ui.sh'
  source '$PROJECT_ROOT/modules/fix/install.sh'
  run_fix
"
assert_status 2
assert_output_contains 'Interactive repair requires a terminal'

run env MYUNIX_FIX_TEST_CONFIRM=n FIX_MARKER="$temporary_dir/cancelled" bash -c '
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/scripts/lib/ui.sh"
  source "'$PROJECT_ROOT'/modules/fix/install.sh"
  fix_repair_category() { printf "%s\n" "Fixture category"; }
  fix_repair_label() { printf "%s\n" "Fixture repair"; }
  fix_diagnose_fixture() {
    printf "%s\n" "fixture is out of date"
    return 1
  }
  fix_plan_fixture() { printf "%s\n" "write the fixture marker"; }
  fix_apply_fixture() { : > "$FIX_MARKER"; }
  fix_verify_fixture() { test -e "$FIX_MARKER"; }
  fix_run_selected fixture
  test ! -e "$FIX_MARKER"
'
assert_status 0
assert_output_contains 'cancelled'

run env MYUNIX_FIX_TEST_CONFIRM=y FIX_MARKER="$temporary_dir/applied" bash -c '
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/scripts/lib/ui.sh"
  source "'$PROJECT_ROOT'/modules/fix/install.sh"
  fix_repair_category() { printf "%s\n" "Fixture category"; }
  fix_repair_label() { printf "%s\n" "Fixture repair"; }
  fix_diagnose_fixture() {
    printf "%s\n" "fixture is out of date"
    return 1
  }
  fix_plan_fixture() { printf "%s\n" "write the fixture marker"; }
  fix_apply_fixture() { : > "$FIX_MARKER"; }
  fix_verify_fixture() { test -e "$FIX_MARKER"; }
  fix_run_selected fixture
  test -e "$FIX_MARKER"
'
assert_status 0
assert_output_contains 'repaired and verified'

run env MYUNIX_FIX_TEST_CONFIRM=n bash -c '
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/scripts/lib/ui.sh"
  source "'$PROJECT_ROOT'/modules/fix/install.sh"
  fix_repair_category() { printf "%s\n" "Fixture category"; }
  fix_repair_label() { printf "%s\n" "Fixture repair"; }
  fix_diagnose_fixture() { printf "%s\n" "all managed files are present"; }
  fix_plan_fixture() { printf "%s\n" "must not be shown for a clean diagnosis"; }
  fix_apply_fixture() { printf "%s\n" "must not be called" >&2; return 1; }
  fix_verify_fixture() { printf "%s\n" "must not be called" >&2; return 1; }
  fix_run_selected fixture
'
assert_status 0
assert_output_contains 'diagnosis clean; no change needed'

run env MYUNIX_SOURCE_ONLY=1 bash -c "
  source '$PROJECT_ROOT/scripts/myunix'
  declare -F run_fix >/dev/null
"
assert_status 0
