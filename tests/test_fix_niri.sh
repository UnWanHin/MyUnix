#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

for scenario in missing-fragment invalid-config invalid-candidate invalid-candidate-symlink custom-path reload-failure fcitx-session; do
  [[ -z "${TEST_CASE:-}" || "$TEST_CASE" == "$scenario" ]] || continue
  home="$temporary_dir/$scenario"
  mkdir -p "$home/.config/niri"
  printf 'environment {\n  XDG_CURRENT_DESKTOP "niri"\n}\n' > "$home/.config/niri/config.kdl"
  run env HOME="$home" XDG_DATA_HOME="$home/.local/share" NIRI_SOCKET=fixture \
    MYUNIX_SOURCE_ONLY=1 SCENARIO="$scenario" bash -c '
    source "'"$PROJECT_ROOT"'/scripts/myunix"
    niri() {
      if [[ "$1" == validate ]]; then
        [[ "$2" == --config && -f "$3" ]] || return 2
        ! grep -Fq "this is not valid KDL" "$3" || return 1
        if [[ "$SCENARIO" == invalid-candidate* && "$3" != "$(fix_niri_config_path)" ]]; then
          printf "candidate rejected\n"
          return 1
        fi
        printf "%s\n" "$3" >> "$HOME/validated-paths"
        return 0
      fi
      [[ "$*" == "msg action load-config-file" ]] || return 2
      [[ "$SCENARIO" != reload-failure ]]
    }
    case "$SCENARIO" in
      missing-fragment)
        printf "include \"myunix/touchpad.kdl\"\ninclude optional=true \"myunix/touchpad-bind.kdl\"\n" >> "$HOME/.config/niri/config.kdl"
        install_niri_dms_touchpad_toggle
        configure_niri_dms_touchpad_toggle_binding
        if fix_diagnose_touchpad_toggle; then exit 1; fi
        fix_apply_touchpad_toggle
        test -s "$HOME/.config/niri/myunix/touchpad.kdl"
        fix_verify_touchpad_toggle
        ;;
      invalid-config|invalid-candidate|invalid-candidate-symlink)
        if [[ "$SCENARIO" == invalid-config ]]; then
          printf "this is not valid KDL\n" > "$HOME/.config/niri/config.kdl"
        fi
        cp "$HOME/.config/niri/config.kdl" "$HOME/original.kdl"
        if [[ "$SCENARIO" == invalid-candidate-symlink ]]; then
          mv "$HOME/.config/niri/config.kdl" "$HOME/linked.kdl"
          ln -s "$HOME/linked.kdl" "$HOME/.config/niri/config.kdl"
        fi
        if fix_apply_touchpad_toggle; then exit 1; fi
        cmp "$HOME/original.kdl" "$HOME/.config/niri/config.kdl"
        if [[ "$SCENARIO" == invalid-config ]] && fix_verify_touchpad_toggle; then exit 1; fi
        ;;
      custom-path)
        mkdir -p "$HOME/custom"
        cp "$HOME/.config/niri/config.kdl" "$HOME/custom/session.kdl"
        export MYUNIX_NIRI_CONFIG="$HOME/custom/session.kdl" MYUNIX_NIRI_CONFIG_DIR="$HOME/unused"
        fix_apply_touchpad_toggle
        test -s "$HOME/custom/myunix/touchpad.kdl"
        test -s "$HOME/custom/myunix/touchpad-bind.kdl"
        test ! -e "$HOME/unused"
        test ! -e "$HOME/.config/niri/myunix"
        fix_verify_touchpad_toggle
        grep -Fq "$HOME/custom/session.kdl.myunix." "$HOME/validated-paths"
        ;;
      reload-failure)
        ! fix_apply_touchpad_toggle
        ;;
      fcitx-session)
        ! fix_diagnose_niri_config
        fix_apply_niri_config
        grep -Fqx "spawn-at-startup \"fcitx5\" \"-d\"" "$HOME/.config/niri/config.kdl"
        grep -Fq "XMODIFIERS \"@im=fcitx\"" "$HOME/.config/niri/config.kdl"
        grep -Fq "QT_IM_MODULES \"wayland;fcitx\"" "$HOME/.config/niri/config.kdl"
        fix_verify_niri_config
        ;;
    esac
  '
  assert_status 0
  printf 'PASS: Niri repair %s\n' "$scenario"
done
