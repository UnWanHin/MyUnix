#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_SOURCE_ONLY=1 MYUNIX_TOOLCHAIN_COMPONENTS=cmake,cmake MYUNIX_TOOLCHAIN_SCOPE=user MYUNIX_FIX_TEST_CONFIRM=y bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  installed=0
  command() {
    if [[ "${1:-}" == -v ]]; then
      case "$2" in
        cmake) [[ "$installed" == 1 ]]; return ;;
        conda) return 1 ;;
      esac
    fi
    builtin command "$@"
  }
  install_development_toolchain() {
    [[ "$*" == "user cmake" ]] || return 2
    installed=1
  }
  fix_run_selected development-toolchain
  [[ "$installed" == 1 ]]
'
assert_status 0
assert_output_contains 'repaired and verified'
[[ "$OUTPUT" != *anaconda* && "$OUTPUT" != *conda* ]] || { printf 'Unselected components leaked into the repair\n' >&2; exit 1; }
printf 'PASS: toolchain subset diagnosis/plan/apply/verify\n'
