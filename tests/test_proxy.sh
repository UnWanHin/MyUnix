#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

module_dir="$PROJECT_ROOT/modules/proxy"
watchdog="$module_dir/config/bin/proxy-watchdog.sh"
launcher="$module_dir/config/bin/chatgpt-proxied"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

make_stub_dir() {
  local directory=$1
  mkdir -p "$directory/bin"
  printf '%s\n' "$directory"
}

write_stub() {
  local directory=$1 name=$2 body=$3
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$directory/bin/$name"
  chmod +x "$directory/bin/$name"
}

# --- launcher: the proxy is applied only while a client answers ------------
stubs="$(make_stub_dir "$temporary/up")"
write_stub "$stubs" curl 'exit 0'
write_stub "$stubs" chatgpt 'printf "arg=%s\n" "$@"'

run env "PATH=$stubs/bin:$PATH" CHATGPT_BIN="$stubs/bin/chatgpt" bash "$launcher" --flag
assert_status 0
assert_output_contains 'arg=--flag'
assert_output_contains 'arg=--proxy-server=http://127.0.0.1:7890'
assert_output_contains 'arg=--proxy-bypass-list=localhost;127.0.0.1;[::1];*.local'

stubs="$(make_stub_dir "$temporary/down")"
write_stub "$stubs" curl 'exit 7'
write_stub "$stubs" chatgpt 'printf "arg=%s\n" "$@"'

run env "PATH=$stubs/bin:$PATH" CHATGPT_BIN="$stubs/bin/chatgpt" bash "$launcher" --flag
assert_status 0
assert_output_contains 'arg=--flag'
[[ "$OUTPUT" != *'--proxy-server'* ]] || {
  printf '%s\n' 'Launcher forced a proxy while no local proxy client was listening' >&2
  exit 1
}

# --- watchdog: reconcile up, reconcile down, and hold during startup ------
run_watchdog() {
  local home=$1 mode=$2 curl_status=$3 grace=$4
  local wstubs
  wstubs="$(make_stub_dir "$home/stubs")"
  if [[ "$curl_status" == 0 ]]; then
    write_stub "$wstubs" curl 'exit 0'
  else
    write_stub "$wstubs" curl 'exit 7'
  fi
  write_stub "$wstubs" gsettings "printf \"'%s'\\n\" '$mode'"
  run timeout 3 env "HOME=$home" "PATH=$wstubs/bin:$PATH" \
    DRY_RUN=1 POLL_SECS=3 STARTUP_GRACE="$grace" bash "$watchdog"
  cat "$home/.cache/proxy-watchdog.log" 2>/dev/null || true
}

home="$temporary/up-home"
mkdir -p "$home"
OUTPUT="$(run_watchdog "$home" none 0 90)"
assert_output_contains "reconcile: proxy=on system='none' -> applied on"
assert_output_contains 'DRY: gsettings set org.gnome.system.proxy mode manual'
assert_output_contains 'DRY: gsettings set org.gnome.system.proxy.socks port 7890'

home="$temporary/down-home"
mkdir -p "$home"
OUTPUT="$(run_watchdog "$home" manual 1 0)"
assert_output_contains "reconcile: proxy=off system='manual' -> applied off"
assert_output_contains 'DRY: gsettings set org.gnome.system.proxy mode none'

home="$temporary/grace-home"
mkdir -p "$home"
OUTPUT="$(run_watchdog "$home" manual 1 3600)"
assert_output_contains 'holding manual during startup grace (3600 s)'
[[ "$OUTPUT" != *'applied off'* ]] || {
  printf '%s\n' 'Watchdog flipped the system proxy during the startup grace window' >&2
  exit 1
}

# --- a stale pidfile must not block a fresh start -------------------------
home="$temporary/stale-home"
mkdir -p "$home/.cache"
printf '999999\n' > "$home/.cache/proxy-watchdog.pid"
OUTPUT="$(run_watchdog "$home" none 0 90)"
assert_output_contains 'reconcile: proxy=on'
[[ "$OUTPUT" != *'another instance already running'* ]] || {
  printf '%s\n' 'A stale pidfile blocked the proxy watchdog' >&2
  exit 1
}

# --- installer: user-level files, launcher override, service, idempotence --
home="$temporary/install-home"
mkdir -p "$home"
system_apps="$temporary/system-applications"
mkdir -p "$system_apps"
cat > "$system_apps/chatgpt.desktop" <<'DESKTOP'
[Desktop Entry]
Name=ChatGPT
Comment=ChatGPT by OpenAI
Exec=chatgpt %U
Icon=chatgpt
Type=Application
MimeType=x-scheme-handler/codex;
DESKTOP

install_proxy_into() {
  run env HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    MYUNIX_PROXY_BACKUP_DIR="$home/backups" \
    MYUNIX_SYSTEM_APPLICATIONS_DIR="$system_apps" \
    MYUNIX_TEST_MODE=fedora \
    "PATH=$temporary/systemctl-bin:$PATH" \
    bash -c '
      sudo() { printf "unexpected sudo: %s\n" "$*"; return 1; }
      source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
      source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
      source "'"$PROJECT_ROOT"'/modules/proxy/install.sh"
      install_proxy
    '
}

# The systemctl stub records every invocation outside the captured stdout so a
# silenced probe and a silenced enable cannot be confused with each other.
write_systemctl_stub() {
  local status=$1
  mkdir -p "$temporary/systemctl-bin"
  cat > "$temporary/systemctl-bin/systemctl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$home/systemctl.log"
exit $status
STUB
  chmod +x "$temporary/systemctl-bin/systemctl"
  rm -f "$home/systemctl.log"
}

write_systemctl_stub 0
install_proxy_into
assert_status 0
grep -qx -- '--user daemon-reload' "$home/systemctl.log" || {
  printf '%s\n' 'The proxy module did not reload the user systemd manager' >&2
  exit 1
}
grep -qx -- '--user enable --now proxy-watchdog.service' "$home/systemctl.log" || {
  printf '%s\n' 'The proxy module did not enable the watchdog user service' >&2
  exit 1
}
[[ "$OUTPUT" != *'unexpected sudo'* ]] || {
  printf '%s\n' 'The proxy module must not require root' >&2
  exit 1
}
[[ -x "$home/.local/bin/proxy-watchdog.sh" ]] || {
  printf '%s\n' 'Expected the watchdog helper to be installed' >&2
  exit 1
}
[[ -x "$home/.local/bin/chatgpt-proxied" ]] || {
  printf '%s\n' 'Expected the proxied launcher to be installed' >&2
  exit 1
}
[[ -f "$home/.config/sysrc.d/proxy.rc" ]] || {
  printf '%s\n' 'Expected the proxy shell fragment to be installed' >&2
  exit 1
}
[[ -f "$home/.config/systemd/user/proxy-watchdog.service" ]] || {
  printf '%s\n' 'Expected the proxy watchdog user unit to be installed' >&2
  exit 1
}
[[ -f "$home/.config/autostart/proxy-watchdog.desktop" ]] || {
  printf '%s\n' 'Expected the proxy watchdog autostart entry to be installed' >&2
  exit 1
}
grep -q "Exec=$home/.local/bin/proxy-watchdog.sh" "$home/.config/autostart/proxy-watchdog.desktop" || {
  printf '%s\n' 'Autostart entry does not use the resolved helper path' >&2
  exit 1
}
grep -q "Exec=$home/.local/bin/chatgpt-proxied %U" "$home/.local/share/applications/chatgpt.desktop" || {
  printf '%s\n' 'ChatGPT override does not use the proxied launcher' >&2
  exit 1
}
grep -q '^MimeType=x-scheme-handler/codex;$' "$home/.local/share/applications/chatgpt.desktop" || {
  printf '%s\n' 'ChatGPT override did not preserve the system entry fields' >&2
  exit 1
}
grep -q '^X-MyUnix-Managed=true$' "$home/.local/share/applications/chatgpt.desktop" || {
  printf '%s\n' 'ChatGPT override is not marked as managed' >&2
  exit 1
}

install_proxy_into
assert_status 0
backup_count=0
if [[ -d "$home/backups" ]]; then
  backup_count="$(find "$home/backups" -type f | wc -l)"
fi
assert_equals '0' "$backup_count"

# --- a missing ChatGPT package must not fail the module -------------------
home="$temporary/no-chatgpt-home"
mkdir -p "$home"
system_apps="$temporary/empty-applications"
mkdir -p "$system_apps"
install_proxy_into
assert_status 0
assert_output_contains 'ChatGPT desktop entry not found'

# --- a session without a user systemd bus degrades gracefully -------------
write_systemctl_stub 1
home="$temporary/no-bus-home"
mkdir -p "$home"
install_proxy_into
assert_status 0
assert_output_contains 'No user systemd bus'
[[ -x "$home/.local/bin/proxy-watchdog.sh" ]] || {
  printf '%s\n' 'Watchdog helper was not installed without a user systemd bus' >&2
  exit 1
}

# --- module dispatch ------------------------------------------------------
run env MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$temporary/state" bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  install_proxy() { printf "proxy module dispatched\n"; }
  run_module proxy
'
assert_status 0
assert_output_contains 'proxy module dispatched'
