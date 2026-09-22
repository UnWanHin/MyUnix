#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT
for scenario in registration stale-entry missing-launcher unmanaged database-failure; do
  [[ -z "${TEST_CASE:-}" || "$TEST_CASE" == "$scenario" ]] || continue
  home="$temporary_dir/$scenario"
  mkdir -p "$home/.local/opt/jetbrains-toolbox" "$home/.local/bin" "$home/.local/share/applications"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/.local/opt/jetbrains-toolbox/jetbrains-toolbox"
  chmod 0755 "$home/.local/opt/jetbrains-toolbox/jetbrains-toolbox"
  touch "$home/.local/opt/jetbrains-toolbox/.myunix-managed"
  printf '<svg/>\n' > "$home/.local/opt/jetbrains-toolbox/toolbox.svg"
  ln -s "$home/.local/opt/jetbrains-toolbox/jetbrains-toolbox" "$home/.local/bin/jetbrains-toolbox"
  run env HOME="$home" XDG_DATA_HOME="$home/.local/share" MYUNIX_SOURCE_ONLY=1 \
    MYUNIX_FIX_TEST_CONFIRM=y SCENARIO="$scenario" bash -c '
    source "'"$PROJECT_ROOT"'/scripts/myunix"
    install_jetbrains_toolbox() { printf "UNEXPECTED INSTALLER\n"; return 99; }
    curl() { printf "UNEXPECTED DOWNLOAD\n"; return 99; }
    entry="$HOME/.local/share/applications/jetbrains-toolbox.desktop"
    case "$SCENARIO" in
      registration|stale-entry)
        if [[ "$SCENARIO" == stale-entry ]]; then
          printf "[Desktop Entry]\nName=User override\nExec=old-command\nIcon=old-icon\n" > "$HOME/original.desktop"
          ln -s "$HOME/original.desktop" "$entry"
        fi
        fix_run_selected jetbrains-toolbox
        grep -Fqx "Exec=$HOME/.local/bin/jetbrains-toolbox %u" "$entry"
        grep -Fqx "Icon=$HOME/.local/opt/jetbrains-toolbox/toolbox.svg" "$entry"
        fix_verify_jetbrains_toolbox
        if [[ "$SCENARIO" == stale-entry ]]; then
          grep -Fqx "Exec=old-command" "$HOME/original.desktop"
          test -n "$(find "$HOME/.local/state/myunix/backups/jetbrains-toolbox" -name jetbrains-toolbox.desktop -print -quit)"
        fi
        ;;
      missing-launcher|unmanaged)
        if [[ "$SCENARIO" == missing-launcher ]]; then
          rm "$HOME/.local/bin/jetbrains-toolbox"
        else
          rm "$HOME/.local/opt/jetbrains-toolbox/.myunix-managed"
        fi
        if fix_apply_jetbrains_toolbox; then exit 1; fi
        test ! -e "$entry"
        ;;
      database-failure)
        update-desktop-database() { return 43; }
        if fix_apply_jetbrains_toolbox; then exit 1; fi
        ;;
    esac
  '
  assert_status 0
  [[ "$OUTPUT" != *UNEXPECTED* ]] || { printf '%s\n' "$OUTPUT" >&2; exit 1; }
  printf 'PASS: Toolbox repair %s\n' "$scenario"
done
