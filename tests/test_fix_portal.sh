#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

for scenario in mixed-backup unchanged backup-failure replacement-failure package-failure nonfile-target; do
  [[ -z "${TEST_CASE:-}" || "$TEST_CASE" == "$scenario" ]] || continue
  home="$temporary_dir/$scenario"
  mkdir -p "$home/.local/bin" "$home/.local/share/applications" "$home/.config/autostart"
  printf 'custom helper\n' > "$home/.local/bin/myunix-portal-login"
  cp "$home/.local/bin/myunix-portal-login" "$home/helper.before"
  run env HOME="$home" XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    MYUNIX_SOURCE_ONLY=1 SCENARIO="$scenario" bash -c '
    source "'"$PROJECT_ROOT"'/scripts/myunix"
    case "$SCENARIO" in
      mixed-backup)
        # One missing file must not lose a customized, already present sibling.
        test ! -e "$HOME/.local/share/applications/myunix-portal-login.desktop"
        install_portal_login_user_files
        shopt -s nullglob
        backups=("$HOME/.local/state/myunix/backups/portal-login/"*/myunix-portal-login)
        test "${#backups[@]}" = 1
        cmp "$HOME/helper.before" "${backups[0]}"
        cmp "$(portal_login_dir)/config/bin/myunix-portal-login" "$HOME/.local/bin/myunix-portal-login"
        test -f "$HOME/.local/share/applications/myunix-portal-login.desktop"
        test -f "$HOME/.config/autostart/myunix-nm-applet.desktop"
        install_portal_login_user_files
        backups=("$HOME/.local/state/myunix/backups/portal-login/"*/myunix-portal-login)
        test "${#backups[@]}" = 1
        ;;
      unchanged)
        install_portal_login_user_files
        before="$(stat -c "%i:%Y:%Z" "$HOME/.local/bin/myunix-portal-login")"
        install() { printf "unexpected install\n"; return 41; }
        chmod() { printf "unexpected chmod\n"; return 42; }
        install_portal_login_user_files
        test "$before" = "$(stat -c "%i:%Y:%Z" "$HOME/.local/bin/myunix-portal-login")"
        ;;
      backup-failure)
        cp() { return 43; }
        if install_portal_login_user_files; then exit 1; else result=$?; fi
        test "$result" = 43
        cmp "$HOME/helper.before" "$HOME/.local/bin/myunix-portal-login"
        test ! -e "$HOME/.local/share/applications/myunix-portal-login.desktop"
        ;;
      replacement-failure)
        mv() { return 44; }
        if install_portal_login_user_files; then exit 1; else result=$?; fi
        test "$result" = 44
        cmp "$HOME/helper.before" "$HOME/.local/bin/myunix-portal-login"
        test ! -e "$HOME/.local/share/applications/myunix-portal-login.desktop"
        ;;
      package-failure)
        is_fedora() { :; }
        install_dnf_manifest() { return 45; }
        if install_portal_login; then exit 1; else result=$?; fi
        test "$result" = 45
        cmp "$HOME/helper.before" "$HOME/.local/bin/myunix-portal-login"
        test ! -e "$HOME/.local/share/applications/myunix-portal-login.desktop"
        ;;
      nonfile-target)
        rm "$HOME/.local/bin/myunix-portal-login"
        mkdir "$HOME/.local/bin/myunix-portal-login"
        printf "unrelated fixture\n" > "$HOME/.local/bin/myunix-portal-login/private-data"
        if install_portal_login_user_files; then exit 1; fi
        test -d "$HOME/.local/bin/myunix-portal-login"
        test ! -e "$HOME/.local/state/myunix/backups/portal-login"
        ;;
    esac
  '
  assert_status 0
  printf 'PASS: Portal repair %s\n' "$scenario"
done
