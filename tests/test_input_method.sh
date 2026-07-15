#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/manifest.sh"
source "$PROJECT_ROOT/modules/dnf/install.sh"
source "$PROJECT_ROOT/modules/input-method/install.sh"

temporary_install="$(mktemp -d)"
run env HOME="$temporary_install/home" XDG_DATA_HOME="$temporary_install/home/.local/share" MYUNIX_SYSTEM_APPLICATIONS_DIR="$temporary_install/empty-applications" bash -c "sudo() { printf '%s\\n' \"\$*\"; }; source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/scripts/lib/manifest.sh'; source '$PROJECT_ROOT/modules/dnf/install.sh'; source '$PROJECT_ROOT/modules/input-method/install.sh'; install_input_methods"
assert_status 0
assert_output_contains 'fcitx5-rime'
assert_output_contains 'fcitx5-table-extra'
assert_output_contains 'Log out and back in'

temporary="$(mktemp -d)"
mkdir -p "$temporary/source" "$temporary/home/.config/fcitx5"
printf '%s\n' 'Name=Default' > "$temporary/source/profile"
printf '%s\n' 'old-profile' > "$temporary/home/.config/fcitx5/profile"
run env HOME="$temporary/home" MYUNIX_FCITX_CONFIG_SOURCE="$temporary/source" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/input-method/install.sh'; import_fcitx5_public_config; cat \"\$HOME/.config/fcitx5/profile\""
assert_status 0
assert_output_contains 'Name=Default'
find "$temporary/home/.local/state/myunix/backups/input-method" -type f -name profile -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing Fcitx5 profile backup' >&2
  exit 1
}

temporary_apps="$(mktemp -d)"
mkdir -p "$temporary_apps/system" "$temporary_apps/home/.local/share/applications"
printf '%s\n' '[Desktop Entry]' 'Name=wechat' 'Exec=/usr/bin/wechat %U' 'Type=Application' > "$temporary_apps/system/wechat.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=QQ' 'Exec=/opt/QQ/qq %U' 'Type=Application' > "$temporary_apps/system/qq.desktop"
printf '%s\n' 'old user launcher' > "$temporary_apps/home/.local/share/applications/wechat.desktop"
run env HOME="$temporary_apps/home" XDG_DATA_HOME="$temporary_apps/home/.local/share" MYUNIX_SYSTEM_APPLICATIONS_DIR="$temporary_apps/system" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/input-method/install.sh'; install_input_method_app_overrides; install_input_method_app_overrides"
assert_status 0
assert_equals 'Exec=env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx QT_IM_MODULES=fcitx /usr/bin/wechat %U' "$(rg '^Exec=' "$temporary_apps/home/.local/share/applications/wechat.desktop")"
assert_equals 'Exec=env XMODIFIERS=@im=fcitx ELECTRON_OZONE_PLATFORM_HINT=auto /opt/QQ/qq --enable-wayland-ime %U' "$(rg '^Exec=' "$temporary_apps/home/.local/share/applications/qq.desktop")"
[[ ! -e "$temporary_apps/home/.local/share/applications/missing.desktop" ]] || {
  printf '%s\n' 'Unexpected launcher override for missing application' >&2
  exit 1
}
find "$temporary_apps/home/.local/state/myunix/backups/input-method" -path '*/desktop-launchers/wechat.desktop' -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing user launcher backup' >&2
  exit 1
}
