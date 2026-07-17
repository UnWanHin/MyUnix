#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

portal_script="$PROJECT_ROOT/modules/portal-login/config/bin/myunix-portal-login"

run bash -c "source '$portal_script'; portal_login_validate_url 'https://portal.example.test/login'"
assert_status 0

run bash -c "source '$portal_script'; portal_login_validate_url 'javascript:alert(1)'"
assert_status 1

run bash -c '
  source "'"$portal_script"'"
  tmp="$(mktemp -d)"
  printf "<script>top.self.location.href='"'"'http://portal.example.test/login'"'"'</script>\n" > "$tmp/body"
  portal_login_body_url "$tmp/body"
'
assert_status 0
assert_equals 'http://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  tmp="$(mktemp -d)"
  printf "HTTP/1.1 302 Found\r\nLocation: https://portal.example.test/login\r\n\r\n" > "$tmp/headers"
  portal_login_header_url "$tmp/headers"
'
assert_status 0
assert_equals 'https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  tmp="$(mktemp -d)"
  printf "<meta content=\"0; url=https://portal.example.test/login\" http-equiv=\"refresh\">\n" > "$tmp/body"
  portal_login_meta_refresh_url "$tmp/body"
'
assert_status 0
assert_equals 'https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  tmp="$(mktemp -d)"
  printf "<meta http-equiv=\"refresh\" content=\"0; url=https://portal.example.test/login\">\n" > "$tmp/body"
  portal_login_meta_refresh_url "$tmp/body"
'
assert_status 0
assert_equals 'https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "portal\n"; }
  notify-send() {
    case "$*" in *--action=open*) printf "open\n";; esac
  }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    printf "<script>location.href='"'"'https://portal.example.test/login'"'"'</script>\n" > "$body"
    : > "$headers"
  }
  xdg-open() { printf "open=%s\n" "$1"; }
  portal_login
'
assert_status 0
assert_equals 'open=https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "portal\n"; }
  notify-send() { :; }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    printf "<script>location.href='"'"'https://portal.example.test/login'"'"'</script>\n" > "$body"
    : > "$headers"
  }
  xdg-open() { printf "unexpected open\n"; }
  portal_login
'
assert_status 0
assert_output_contains 'Sign-in page is ready. Select Open sign-in page in the notification.'
[[ "$OUTPUT" != *'unexpected open'* ]] || {
  printf '%s\n' 'Portal helper opened a page after the notification was dismissed' >&2
  exit 1
}

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "full\n"; }
  notify-send() { printf "notify=%s\n" "$*"; }
  curl() { printf "unexpected curl\n"; return 1; }
  portal_login
'
assert_status 0
assert_output_contains 'Already connected; no sign-in is needed.'
assert_output_contains 'notify=--urgency=normal Wi-Fi Login Already connected; no sign-in is needed.'

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "limited\n"; }
  notify-send() {
    case "$*" in *--action=open*) printf "open\n";; esac
  }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    : > "$headers"
    printf "<meta http-equiv=\"refresh\" content=\"0; url=https://portal.example.test/login\">\n" > "$body"
  }
  xdg-open() { printf "open=%s\n" "$1"; }
  portal_login
'
assert_status 0
assert_equals 'open=https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "unknown\n"; }
  notify-send() {
    case "$*" in *--action=open*) printf "open\n";; esac
  }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    printf "<script>location.href='"'"'https://portal.example.test/login'"'"'</script>\n" > "$body"
    : > "$headers"
  }
  xdg-open() { printf "open=%s\n" "$1"; }
  portal_login
'
assert_status 0
assert_equals 'open=https://portal.example.test/login' "$OUTPUT"

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "portal\n"; }
  notify-send() {
    case "$*" in
      *--action=open*) printf "open\n" ;;
      *) printf "notify=%s\n" "$*" ;;
    esac
  }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    printf "<script>location.href='"'"'https://portal.example.test/login'"'"'</script>\n" > "$body"
    : > "$headers"
  }
  xdg-open() { return 1; }
  portal_login
'
assert_status 1
assert_output_contains 'Unable to open the captive-portal sign-in page.'
assert_output_contains 'notify=--urgency=critical Wi-Fi Login Unable to open the sign-in page in a browser.'

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "portal\n"; }
  curl() {
    while (($#)); do
      case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac
    done
    printf "<script>location.href='"'"'javascript:alert(1)'"'"'</script>\n" > "$body"
    : > "$headers"
  }
  notify-send() { printf "notify=%s\n" "$*"; }
  xdg-open() { printf "unexpected open\n"; }
  portal_login
'
assert_status 1
assert_output_contains 'Refusing unsupported captive-portal redirect scheme'
assert_output_contains 'notify=--urgency=critical Wi-Fi Login The network returned an unsafe sign-in address.'
[[ "$OUTPUT" != *'unexpected open'* ]] || {
  printf '%s\n' 'Portal helper opened an unsafe redirect' >&2
  exit 1
}

tmp="$(mktemp -d)"
run env HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" MYUNIX_TEST_MODE=fedora bash -c '
  sudo() { printf "%s\n" "$*"; }
  timeout() { shift 2; "$@"; }
  nm-applet() { :; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/portal-login/install.sh"
  install_portal_login
'
assert_status 0
assert_output_contains 'network-manager-applet'
assert_output_contains 'libnotify'
[[ -x "$tmp/home/.local/bin/myunix-portal-login" ]] || {
  printf '%s\n' 'Expected portal-login helper to be installed' >&2
  exit 1
}
[[ -f "$tmp/home/.local/share/applications/myunix-portal-login.desktop" ]] || {
  printf '%s\n' 'Expected portal-login desktop entry to be installed' >&2
  exit 1
}
[[ -f "$tmp/home/.config/autostart/myunix-nm-applet.desktop" ]] || {
  printf '%s\n' 'Expected NetworkManager applet autostart entry to be installed' >&2
  exit 1
}

run env MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$tmp/state" bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  install_portal_login() { printf "portal module dispatched\n"; }
  run_module portal-login
'
assert_status 0
assert_output_contains 'portal module dispatched'
