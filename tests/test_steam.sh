#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/dnf/install.sh"
source "$PROJECT_ROOT/modules/steam/install.sh"

temporary="$(mktemp -d)"
home="$temporary/home"
system_apps="$temporary/system-applications"
mkdir -p "$home/.local/share/applications" "$system_apps"
printf '%s\n' \
  '[Desktop Entry]' \
  'Name=Steam' \
  'Exec=/usr/bin/steam %U' \
  'Type=Application' \
  '' \
  '[Desktop Action Store]' \
  'Name=Store' \
  'Exec=/usr/bin/steam steam://store' > "$system_apps/steam.desktop"
printf '%s\n' 'old user override' > "$home/.local/share/applications/steam.desktop"

run env HOME="$home" MYUNIX_SYSTEM_APPLICATIONS_DIR="$system_apps" bash -c '
  sudo() { printf "sudo:%s\\n" "$*"; }
  rpm() { printf "rpm:%s\\n" "$*"; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/steam/install.sh"
  install_steam
'
assert_status 0
assert_output_contains 'sudo:dnf install -y steam'
assert_output_contains 'rpm:-q steam'
assert_equals 'Exec=/usr/bin/steam -system-composer %U' "$(rg '^Exec=' "$home/.local/share/applications/steam.desktop" | sed -n '1p')"
assert_equals 'Exec=/usr/bin/steam -system-composer steam://store' "$(rg '^Exec=' "$home/.local/share/applications/steam.desktop" | sed -n '2p')"
assert_equals 2 "$(rg -c '^Exec=/usr/bin/steam -system-composer' "$home/.local/share/applications/steam.desktop")"
assert_equals 1 "$(rg -c '^X-MyUnix-Managed=true$' "$home/.local/share/applications/steam.desktop")"
find "$home/.local/state/myunix/backups/steam" -type f -name steam.desktop -print -quit | grep -q . || {
  printf '%s\n' 'Expected existing Steam override backup' >&2
  exit 1
}

run env HOME="$home" MYUNIX_SYSTEM_APPLICATIONS_DIR="$system_apps" bash -c '
  sudo() { :; }
  rpm() { :; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/steam/install.sh"
  install_steam
'
assert_status 0
assert_equals 2 "$(rg -c '^Exec=/usr/bin/steam -system-composer' "$home/.local/share/applications/steam.desktop")"
assert_equals 1 "$(find "$home/.local/state/myunix/backups/steam" -type f -name steam.desktop | wc -l | tr -d ' ')"
