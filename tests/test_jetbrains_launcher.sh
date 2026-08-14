#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

temporary_home="$temporary_dir/home"
toolbox_scripts="$temporary_home/.local/share/JetBrains/Toolbox/scripts"
state_home="$temporary_dir/state"
project_dir="$temporary_dir/project"
launch_log="$temporary_dir/launch.log"
functions_file="$PROJECT_ROOT/modules/shell-config/config/sysrc.d/functions.rc"
aliases_file="$PROJECT_ROOT/modules/shell-config/config/sysrc.d/aliases.rc"

mkdir -p "$toolbox_scripts" "$project_dir"

make_launcher() {
  local name=$1 launcher="$toolbox_scripts/$1"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s:%s\\n' '$name' \"\$1\" >> \"\$JET_TEST_LOG\"" > "$launcher"
  chmod +x "$launcher"
}

run_jet() {
  local input=$1
  run env \
    HOME="$temporary_home" \
    XDG_STATE_HOME="$state_home" \
    JETBRAINS_TOOLBOX_SCRIPTS="$toolbox_scripts" \
    JET_TEST_LOG="$launch_log" \
    bash -o pipefail -c '
      source "$1"
      source "$2"
      alias jetcode
      printf "%s" "$3" | jet "$4"
      status=$?
      wait
      exit "$status"
    ' bash "$functions_file" "$aliases_file" "$input" "$project_dir"
}

make_launcher clion
make_launcher pycharm

run_jet $'2\n'
assert_status 0
assert_equals "pycharm:$project_dir" "$(tail -n 1 "$launch_log")"

state_key="$(printf %s "$project_dir" | sha256sum | awk '{print $1}')"
state_file="$state_home/myunix/jetbrains/last/$state_key"
assert_equals "$toolbox_scripts/pycharm" "$(cat "$state_file")"

make_launcher idea
run_jet $'\n'
assert_status 0
assert_output_contains '1. pycharm (last)'
assert_output_contains 'idea'
assert_equals "pycharm:$project_dir" "$(tail -n 1 "$launch_log")"

rm -f "$toolbox_scripts/pycharm"
launch_count_before="$(wc -l < "$launch_log")"
run_jet $'\n'
[[ "$STATUS" != 0 ]] || {
  printf '%s\n' 'Expected blank selection to fail without a valid remembered IDE' >&2
  exit 1
}
assert_output_contains 'Choose a number'
assert_equals "$launch_count_before" "$(wc -l < "$launch_log")"
assert_equals "$toolbox_scripts/pycharm" "$(cat "$state_file")"

run_jet $'9\n'
[[ "$STATUS" != 0 ]] || {
  printf '%s\n' 'Expected an invalid selection to fail' >&2
  exit 1
}
assert_output_contains 'Invalid selection'
assert_equals "$launch_count_before" "$(wc -l < "$launch_log")"
assert_equals "$toolbox_scripts/pycharm" "$(cat "$state_file")"
