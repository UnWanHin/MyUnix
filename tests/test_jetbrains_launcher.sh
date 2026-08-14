#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

temporary_home="$temporary_dir/home"
toolbox_scripts="$temporary_home/.local/share/JetBrains/Toolbox/scripts"
toolbox_apps="$temporary_home/.local/share/JetBrains/Toolbox/apps"
manual_root="$temporary_dir/manual-jetbrains"
state_home="$temporary_dir/state"
project_dir="$temporary_dir/project"
launch_log="$temporary_dir/launch.log"
functions_file="$PROJECT_ROOT/modules/shell-config/config/sysrc.d/functions.rc"
aliases_file="$PROJECT_ROOT/modules/shell-config/config/sysrc.d/aliases.rc"

mkdir -p "$toolbox_scripts" "$toolbox_apps" "$manual_root" "$project_dir"

make_launcher() {
  local launcher_name=$1 product_name=$2 version=$3
  local app_dir="$toolbox_apps/$launcher_name" launcher="$toolbox_scripts/$launcher_name"
  local binary="$app_dir/bin/$launcher_name"
  mkdir -p "$(dirname "$binary")"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s:%s\\n' '$launcher_name' \"\$1\" >> \"\$JET_TEST_LOG\"" > "$binary"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "\"$binary\" \"\$@\"" > "$launcher"
  printf '%s\n' \
    '{' \
    "  \"name\": \"$product_name\"," \
    "  \"version\": \"$version\"" \
    '}' > "$app_dir/product-info.json"
  chmod +x "$binary" "$launcher"
}

make_manual_launcher() {
  local app_dir="$manual_root/CLion-2025.3.4" binary="$manual_root/CLion-2025.3.4/bin/clion.sh"
  mkdir -p "$(dirname "$binary")"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s:%s\\n' 'clion-old' \"\$1\" >> \"\$JET_TEST_LOG\"" > "$binary"
  printf '%s\n' \
    '{' \
    '  "name": "CLion",' \
    '  "version": "2025.3.4"' \
    '}' > "$app_dir/product-info.json"
  chmod +x "$binary"
}

run_jet() {
  local input=$1
  run env \
    HOME="$temporary_home" \
    XDG_STATE_HOME="$state_home" \
    JETBRAINS_TOOLBOX_SCRIPTS="$toolbox_scripts" \
    MYUNIX_JETBRAINS_PATHS="$manual_root" \
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

make_launcher clion CLion 2026.2.1
make_launcher pycharm PyCharm 2026.2.1

run_jet $'2\n'
assert_status 0
assert_equals "pycharm:$project_dir" "$(tail -n 1 "$launch_log")"

state_key="$(printf %s "$project_dir" | sha256sum | awk '{print $1}')"
state_file="$state_home/myunix/jetbrains/last/$state_key"
assert_equals "$toolbox_scripts/pycharm" "$(cat "$state_file")"

make_launcher idea 'IntelliJ IDEA' 2026.2.1
make_manual_launcher
internal_launcher="$temporary_home/.local/share/JetBrains/Toolbox/apps/CLion/bin/format.sh"
mkdir -p "$(dirname "$internal_launcher")"
printf '%s\n' '#!/usr/bin/env bash' > "$internal_launcher"
chmod +x "$internal_launcher"
run_jet $'\n'
assert_status 0
assert_output_contains '1. PyCharm (2026.2.1) (last)'
assert_output_contains 'IntelliJ IDEA (2026.2.1)'
assert_output_contains 'CLion (2025.3.4)'
[[ "$OUTPUT" != *format* ]] || {
  printf '%s\n' 'Unexpected Toolbox internal launcher in Jet menu' >&2
  exit 1
}
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
