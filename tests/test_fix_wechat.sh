#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

for scenario in install-failure verifier-packages wechat-only render-failure backup-failure replacement-failure stale-rendered; do
  [[ -z "${TEST_CASE:-}" || "$TEST_CASE" == "$scenario" ]] || continue
  home="$temporary_dir/$scenario"
  mkdir -p "$home/rpm" "$home/flatpak-user" "$home/flatpak-system" "$home/.local/share/applications" "$home/public-fcitx"
  printf '[Desktop Entry]\nName=WeChat\nExec=/usr/bin/wechat %%U\n' > "$home/rpm/wechat.desktop"
  printf '[Desktop Entry]\nName=QQ\nExec=/usr/bin/qq %%U\n' > "$home/rpm/qq.desktop"
  printf '[Desktop Entry]\nName=Custom QQ\nExec=qq --custom %%U\n' > "$home/.local/share/applications/qq.desktop"
  cp "$home/.local/share/applications/qq.desktop" "$home/qq.before"
  printf '[Desktop Entry]\nName=WeChat User\nExec=flatpak run user-WeChat %%U\n' > "$home/flatpak-user/com.tencent.WeChat.desktop"
  printf '[Desktop Entry]\nName=WeChat System\nExec=flatpak run system-WeChat %%U\n' > "$home/flatpak-system/com.tencent.WeChat.desktop"
  run env HOME="$home" XDG_DATA_HOME="$home/.local/share" MYUNIX_SOURCE_ONLY=1 \
    MYUNIX_SYSTEM_APPLICATIONS_DIR="$home/rpm" MYUNIX_FLATPAK_USER_APPLICATIONS_DIR="$home/flatpak-user" \
    MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR="$home/flatpak-system" MYUNIX_FCITX_CONFIG_SOURCE="$home/public-fcitx" \
    SCENARIO="$scenario" bash -c '
    source "'"$PROJECT_ROOT"'/scripts/myunix"
    fcitx5() { :; }
    rpm() { [[ "$1" == -q ]]; }
    case "$SCENARIO" in
      install-failure)
        install_input_methods() { return 41; }
        install_input_method_app_overrides() { : > "$HOME/unexpected-overrides"; }
        if fix_apply_wechat_cangjie; then exit 1; fi
        test ! -e "$HOME/unexpected-overrides"
        ;;
      verifier-packages)
        mkdir -p "$HOME/.config/fcitx5"
        printf "Name=cangjie5\n" > "$HOME/.config/fcitx5/profile"
        install_input_method_app_overrides
        fix_verify_wechat_cangjie
        rpm() { return 1; }
        if fix_verify_wechat_cangjie; then exit 1; fi
        ;;
      wechat-only)
        install_dnf_manifest() { :; }
        fix_apply_wechat_cangjie
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        test -f "$HOME/.local/share/applications/wechat.desktop"
        grep -Fq user-WeChat "$HOME/.local/share/applications/com.tencent.WeChat.desktop"
        ! grep -Fq system-WeChat "$HOME/.local/share/applications/com.tencent.WeChat.desktop"
        fix_verify_wechat_cangjie
        # If the user export disappears, the system export is discovered.
        rm "$HOME/flatpak-user/com.tencent.WeChat.desktop"
        fix_apply_wechat_cangjie
        grep -Fq system-WeChat "$HOME/.local/share/applications/com.tencent.WeChat.desktop"
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        fix_verify_wechat_cangjie
        ;;
      render-failure)
        printf "[Desktop Entry]\nName=stale WeChat\nExec=/usr/bin/stale-wechat %%U\n" > "$HOME/.local/share/applications/wechat.desktop"
        render_input_method_launcher() { return 41; }
        if install_input_method_app_overrides wechat; then exit 1; else result=$?; fi
        test "$result" = 41
        grep -Fq /usr/bin/stale-wechat "$HOME/.local/share/applications/wechat.desktop"
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        ;;
      backup-failure)
        printf "[Desktop Entry]\nName=stale WeChat\nExec=/usr/bin/stale-wechat %%U\n" > "$HOME/.local/share/applications/wechat.desktop"
        render_input_method_launcher() { printf "[Desktop Entry]\nName=rendered WeChat\nExec=env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx \"QT_IM_MODULES=wayland;fcitx\" /usr/bin/wechat %%U\n" > "$2"; }
        backup_input_method_launcher() { return 42; }
        if install_input_method_app_overrides wechat; then exit 1; else result=$?; fi
        test "$result" = 42
        grep -Fq /usr/bin/stale-wechat "$HOME/.local/share/applications/wechat.desktop"
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        ;;
      replacement-failure)
        printf "[Desktop Entry]\nName=stale WeChat\nExec=/usr/bin/stale-wechat %%U\n" > "$HOME/.local/share/applications/wechat.desktop"
        render_input_method_launcher() { printf "[Desktop Entry]\nName=rendered WeChat\nExec=env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx \"QT_IM_MODULES=wayland;fcitx\" /usr/bin/wechat %%U\n" > "$2"; }
        backup_input_method_launcher() { :; }
        mv() { return 43; }
        if install_input_method_app_overrides wechat; then exit 1; else result=$?; fi
        test "$result" = 43
        grep -Fq /usr/bin/stale-wechat "$HOME/.local/share/applications/wechat.desktop"
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        ;;
      stale-rendered)
        mkdir -p "$HOME/.config/fcitx5"
        printf "Name=cangjie5\n" > "$HOME/.config/fcitx5/profile"
        install_input_method_app_overrides wechat
        fix_verify_wechat_cangjie
        for desktop_file in wechat.desktop com.tencent.WeChat.desktop; do
          printf "[Desktop Entry]\nName=stale WeChat\nExec=env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx \"QT_IM_MODULES=wayland;fcitx\" /usr/bin/wrong-wechat %%U\n" > "$HOME/.local/share/applications/$desktop_file"
          if fix_verify_wechat_cangjie; then exit 1; fi
          install_input_method_app_overrides wechat
          fix_verify_wechat_cangjie
        done
        cmp "$HOME/qq.before" "$HOME/.local/share/applications/qq.desktop"
        ;;
    esac
  '
  assert_status 0
  case "$scenario" in
    render-failure|backup-failure|replacement-failure)
      [[ "$OUTPUT" != *'Installed input-method launcher override'* ]] || {
        printf 'Unexpected success output after %s\n%s\n' "$scenario" "$OUTPUT" >&2
        exit 1
      }
      ;;
  esac
  printf 'PASS: WeChat repair %s\n' "$scenario"
done
