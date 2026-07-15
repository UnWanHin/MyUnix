#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
mkdir -p "$temporary_dir/home/.config/sysrc.d"
printf '%s\n' 'old sysrc' > "$temporary_dir/home/.config/.sysrc"
printf '%s\n' 'old bash' > "$temporary_dir/home/.bashrc"
printf '%s\n' 'old zsh' > "$temporary_dir/home/.zshrc"

run env HOME="$temporary_dir/home" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/shell-config/install.sh'; install_shell_config; install_shell_config; cat \"\$HOME/.config/.sysrc\""
assert_status 0
assert_output_contains 'sysrc.d/*.rc'
assert_equals 1 "$(grep -c '^# >>> MyUnix shared shell configuration >>>$' "$temporary_dir/home/.bashrc")"
assert_equals 1 "$(grep -c '^# >>> MyUnix shared shell configuration >>>$' "$temporary_dir/home/.zshrc")"
grep -Fqx '[ -r "$HOME/.config/.sysrc" ] && . "$HOME/.config/.sysrc"' "$temporary_dir/home/.bashrc"
grep -Fqx '[ -r "$HOME/.config/.sysrc" ] && . "$HOME/.config/.sysrc"' "$temporary_dir/home/.zshrc"
find "$temporary_dir/home/.local/state/myunix/backups/shell-config" -name .sysrc -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing .sysrc backup' >&2
  exit 1
}

for fragment in env.rc aliases.rc functions.rc; do
  [[ -f "$temporary_dir/home/.config/sysrc.d/$fragment" ]] || {
    printf 'Expected imported fragment: %s\n' "$fragment" >&2
    exit 1
  }
done

printf '%s\n' 'export MYUNIX_SYSRC_TEST=loaded' > "$temporary_dir/home/.config/sysrc.d/env.rc"
run env HOME="$temporary_dir/home" XDG_CONFIG_HOME="$temporary_dir/other-config" bash -c '. "$HOME/.config/.sysrc"; printf %s "${MYUNIX_SYSRC_TEST:-missing}"'
assert_status 0
assert_equals loaded "$OUTPUT"

printf '%s\n' '# exported environment' > "$temporary_dir/home/.config/sysrc.d/env.rc"
printf '%s\n' '# do not export me' > "$temporary_dir/home/.config/sysrc.d/unmanaged.rc"
run env HOME="$temporary_dir/home" MYUNIX_SHELL_CONFIG_SOURCE="$temporary_dir/exported" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/shell-config/install.sh'; source '$PROJECT_ROOT/modules/shell-config/export.sh'; export_shell_config"
assert_status 0
assert_equals '# exported environment' "$(cat "$temporary_dir/exported/sysrc.d/env.rc")"
[[ ! -e "$temporary_dir/exported/sysrc.d/unmanaged.rc" ]] || {
  printf '%s\n' 'Unexpected export of unmanaged fragment' >&2
  exit 1
}

run env HOME="$temporary_dir/home" MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$temporary_dir/state" "$PROJECT_ROOT/scripts/myunix" install --module shell-config
assert_status 0
