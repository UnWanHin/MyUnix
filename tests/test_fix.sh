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

run env MYUNIX_SOURCE_ONLY=1 MYUNIX_UI_TEST_MODE=1 MYUNIX_FIX_TEST_CONFIRM=y FIX_MARKER="$temporary_dir/cli-applied" bash -c '
  source "'$PROJECT_ROOT'/scripts/myunix"
  fixture_category="${FIX_CATEGORY_LABELS[0]}"
  fix_register_repair fixture "$fixture_category" "Fixture repair"
  fix_choose_category() { printf "%s\n" "$fixture_category"; }
  fix_choose_repair() {
    [[ "$1" == "$fixture_category" ]] || return 1
    printf "%s\n" fixture
  }
  fix_diagnose_fixture() {
    printf "%s\n" "fixture is out of date"
    return 1
  }
  fix_plan_fixture() { printf "%s\n" "write the fixture marker"; }
  fix_apply_fixture() { : > "$FIX_MARKER"; }
  fix_verify_fixture() { test -e "$FIX_MARKER"; }
  run_fix
  test -e "$FIX_MARKER"
'
assert_status 0
assert_output_contains 'repaired and verified'

run env MYUNIX_UI_TEST_MODE=0 "$PROJECT_ROOT/scripts/myunix" fix
assert_status 2
assert_output_contains 'Interactive repair requires a terminal'

run "$PROJECT_ROOT/scripts/myunix" fix --all
assert_status 2
assert_output_contains 'Usage: myunix fix'

run "$PROJECT_ROOT/scripts/myunix" fix unexpected
assert_status 2
assert_output_contains 'Usage: myunix fix'

run bash -c '
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/scripts/lib/ui.sh"
  source "'$PROJECT_ROOT'/modules/fix/install.sh"
  fix_register_repair invalid "Unknown category" "Invalid repair"
'
assert_status 2
assert_output_contains 'Invalid repair category'

repair_home="$temporary_dir/repair-home"
codex_trace="$temporary_dir/codex.trace"
mkdir -p "$repair_home"

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 bash -c "
  source '$PROJECT_ROOT/scripts/myunix'
  expected='codex-fedora
development-toolchain
flclash-launcher
portal-login
wechat-cangjie'
  actual=\"\$(fix_repair_ids | sort)\"
  test \"\$actual\" = \"\$expected\"
  while IFS= read -r repair_id; do
    suffix=\"\${repair_id//-/_}\"
    declare -F \"fix_diagnose_\$suffix\" >/dev/null
    declare -F \"fix_plan_\$suffix\" >/dev/null
    declare -F \"fix_apply_\$suffix\" >/dev/null
    declare -F \"fix_verify_\$suffix\" >/dev/null
  done <<< \"\$actual\"
  ! fix_diagnose_wechat_cangjie
  test ! -e \"\$HOME/.config/fcitx5/profile\"
  test ! -e \"\$HOME/.local/share/applications/wechat.desktop\"
"
assert_status 0

flatpak_repair_dir="$temporary_dir/flatpak-repair"
mkdir -p "$flatpak_repair_dir/user-export" "$flatpak_repair_dir/system-export"
printf '%s\n' \
  '[Desktop Entry]' \
  'Name=WeChat' \
  'Exec=/app/bin/wechat %U' \
  'Type=Application' \
  > "$flatpak_repair_dir/user-export/com.tencent.WeChat.desktop"
run env \
  HOME="$repair_home" \
  XDG_DATA_HOME="$repair_home/.local/share" \
  MYUNIX_SYSTEM_APPLICATIONS_DIR="$flatpak_repair_dir/no-rpm" \
  MYUNIX_FLATPAK_USER_APPLICATIONS_DIR="$flatpak_repair_dir/user-export" \
  MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR="$flatpak_repair_dir/system-export" \
  MYUNIX_FIX_TEST_CONFIRM=y \
  MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 bash -c '
    source "'$PROJECT_ROOT'/scripts/myunix"
    fcitx5() { :; }
    rpm() {
      [[ "${1:-}" == -q && ( "${2:-}" == fcitx5-chinese-addons || "${2:-}" == fcitx5-table-extra ) ]]
    }
    mkdir -p "$HOME/.config/fcitx5"
    install_input_methods() {
      mkdir -p "$HOME/.config/fcitx5"
      printf "%s\\n" Name=cangjie5 > "$HOME/.config/fcitx5/profile"
    }
    ! fix_diagnose_wechat_cangjie
    fix_run_selected wechat-cangjie
    test -f "$HOME/.local/share/applications/com.tencent.WeChat.desktop"
    grep -Fqx "Exec=env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx QT_IM_MODULES=fcitx /app/bin/wechat %U" "$HOME/.local/share/applications/com.tencent.WeChat.desktop"
    fix_verify_wechat_cangjie
  '
assert_status 0
assert_output_contains 'repaired and verified'

run env \
  HOME="$repair_home" \
  XDG_DATA_HOME="$repair_home/.local/share" \
  MYUNIX_SYSTEM_APPLICATIONS_DIR="$flatpak_repair_dir/no-rpm" \
  MYUNIX_FLATPAK_USER_APPLICATIONS_DIR="$flatpak_repair_dir/user-export" \
  MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR="$flatpak_repair_dir/system-export" \
  MYUNIX_NIRI_CONFIG="$flatpak_repair_dir/missing-niri-config" \
  MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 bash -c '
    source "'$PROJECT_ROOT'/scripts/myunix"
    fcitx5() { :; }
    rpm() {
      [[ "${1:-}" == -q && ( "${2:-}" == fcitx5-chinese-addons || "${2:-}" == fcitx5-table-extra ) ]]
    }
    output="$(fix_diagnose_wechat_cangjie || true)"
    [[ "$output" != *Niri* ]]
    [[ "$output" != *niri* ]]
  '
assert_status 0

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 MYUNIX_FIX_TEST_CONFIRM=n bash -c '
  source "'$PROJECT_ROOT'/scripts/myunix"
  fix_run_selected wechat-cangjie
'
assert_status 0
assert_output_contains 'Plan:'
assert_output_contains 'cancelled'

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_SOURCE_ONLY=1 bash -c '
  source "'$PROJECT_ROOT'/scripts/lib/core.sh"
  source "'$PROJECT_ROOT'/modules/rpm/install.sh"
  install_flclash_desktop_entry
  launcher="${XDG_DATA_HOME:-$HOME/.local/share}/applications/flclash.desktop"
  grep -Fqx "Name=FlClash" "$launcher"
  grep -Fqx "Exec=FlClash %U" "$launcher"
  test ! -e "$HOME/.config/FlClash"
'
assert_status 0

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 bash -c '
  source "'$PROJECT_ROOT'/scripts/myunix"
  calls=()
  install_input_methods() { calls+=(input-methods); }
  install_input_method_app_overrides() { calls+=(app-overrides); }
  install_portal_login() { calls+=(portal-login); }
  install_codex_fedora() { calls+=(codex-fedora); }
  install_development_toolchain() { calls+=(development-toolchain); }
  fix_apply_wechat_cangjie
  test "${calls[*]}" = "input-methods app-overrides"
'
assert_status 0

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 bash -c '
  source "'$PROJECT_ROOT'/scripts/myunix"
  calls=()
  rpm() { [[ "${1:-}" == -q && "${2:-}" == FlClash ]]; }
  install_flclash_desktop_entry() {
    calls+=(flclash-desktop)
    mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    : > "${XDG_DATA_HOME:-$HOME/.local/share}/applications/flclash.desktop"
  }
  install_rpm_record() { calls+=(rpm-reinstall); return 99; }
  fix_apply_flclash_launcher
  test "${calls[*]}" = "flclash-desktop"
  test -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/flclash.desktop"
  test ! -e "$HOME/.config/FlClash"
'
assert_status 0

run env HOME="$repair_home" XDG_DATA_HOME="$repair_home/.local/share" MYUNIX_TEST_MODE=fedora MYUNIX_SOURCE_ONLY=1 CODEX_TRACE="$codex_trace" bash -c '
  source "'$PROJECT_ROOT'/scripts/myunix"
  node() { :; }
  npm() { :; }
  codex() { [[ "${1:-}" != *auth* ]]; }
  install_codex_fedora() { printf "%s\n" codex-installer; }
  mkdir -p "$HOME/.codex"
  printf "%s\n" '{"sentinel":"do-not-read"}' > "$HOME/.codex/auth.json"
  exec 9>"$CODEX_TRACE"
  export BASH_XTRACEFD=9
  set -x
  fix_diagnose_codex_fedora
  fix_apply_codex_fedora
  set +x
  ! grep -Fq ".codex/auth.json" "$CODEX_TRACE"
'
assert_status 0
