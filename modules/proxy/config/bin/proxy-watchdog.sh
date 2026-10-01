#!/usr/bin/env bash
# proxy-watchdog — keep the GNOME system proxy in sync with the local proxy
# client (FlClash on 127.0.0.1:7890).
#
# Why: if FlClash is force-killed or crashes while the GNOME system proxy is
# set to "manual -> 127.0.0.1:7890", every GUI app that follows the system
# proxy (Firefox, GNOME apps, ...) loses ALL connectivity. This watchdog:
#   * proxy client up   -> system proxy = manual @127.0.0.1:7890 (browser
#                          reaches OpenAI/YouTube again)
#   * proxy client down -> system proxy = none                   (browser
#                          falls back to direct; everything keeps working)
#
# Every poll it READS the actual GNOME proxy mode and reconciles it with the
# probe, so it also repairs situations where the client is running fine but
# the system proxy was silently switched to "none" (e.g. a stray toggle, the
# client re-asserting its own setting, ...). It never touches ignore-hosts
# (the custom list stays untouched). Single-instance via pidfile.
#
# STARTUP_GRACE: right after a reboot the proxy client may take a while to
# come up. During this window the watchdog refuses to flip manual -> none, so
# apps launched early (e.g. the ChatGPT desktop app) keep using the proxy
# that is about to come back. Only the DOWN direction is held; repairs to
# "manual" are never delayed.
#
# Manage it on the HOST with:
#   systemctl --user enable --now proxy-watchdog     (service install)
#   systemctl --user restart proxy-watchdog          (after an update)
#   systemctl --user status proxy-watchdog           (check)
# Log: ~/.cache/proxy-watchdog.log

PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${PROXY_PORT:-7890}"
POLL_SECS="${POLL_SECS:-5}"
STARTUP_GRACE="${STARTUP_GRACE:-90}"
LOG="$HOME/.cache/proxy-watchdog.log"
PIDFILE="$HOME/.cache/proxy-watchdog.pid"

mkdir -p "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# single instance
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  log "another instance already running (pid $(cat "$PIDFILE")); exiting"
  exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

start_epoch="$(date +%s)"

proxy_up() {
  curl -s -m 1 -o /dev/null "http://${PROXY_HOST}:${PROXY_PORT}/" 2>/dev/null
}

gsettings_set() {
  if [ -n "$DRY_RUN" ]; then
    log "DRY: gsettings $*"
    return 0
  fi
  if command -v gsettings >/dev/null 2>&1; then
    gsettings "$@" 2>>"$LOG"
  else
    log "gsettings not available; giving up on GUI proxy control"
    return 1
  fi
}

apply_proxy_on() {
  local ok=0
  gsettings_set set org.gnome.system.proxy mode 'manual'               || ok=1
  gsettings_set set org.gnome.system.proxy.http host "$PROXY_HOST"     || ok=1
  gsettings_set set org.gnome.system.proxy.http port "$PROXY_PORT"     || ok=1
  gsettings_set set org.gnome.system.proxy.https host "$PROXY_HOST"    || ok=1
  gsettings_set set org.gnome.system.proxy.https port "$PROXY_PORT"    || ok=1
  gsettings_set set org.gnome.system.proxy.socks host "$PROXY_HOST"    || ok=1
  gsettings_set set org.gnome.system.proxy.socks port "$PROXY_PORT"    || ok=1
  return $ok
}

apply_proxy_off() {
  gsettings_set set org.gnome.system.proxy mode 'none' || return 1
  return 0
}

read_mode() {
  if command -v gsettings >/dev/null 2>&1; then
    gsettings get org.gnome.system.proxy mode 2>/dev/null
  else
    echo "unknown"
  fi
}

hold_logged=
last_sig=
fail_prev=

reconcile() {
  local desired actual mode_now flipped sig
  if proxy_up; then
    desired=on
  else
    desired=off
  fi
  mode_now="$(read_mode)"
  case "$mode_now" in
    "'manual'") actual=on ;;
    "'none'")   actual=off ;;
    *)          actual=unknown ;;
  esac

  # boot-race guard: only the DOWN direction is held during STARTUP_GRACE.
  if [ "$desired" = off ] && [ "$actual" = on ] \
     && [ $(( $(date +%s) - start_epoch )) -lt "$STARTUP_GRACE" ]; then
    [ -z "$hold_logged" ] && log "holding manual during startup grace ($STARTUP_GRACE s) - proxy client not up yet"
    hold_logged=1
    return 0
  fi
  hold_logged=

  if [ "$actual" = unknown ] || [ "$actual" != "$desired" ]; then
    flipped=
    if [ "$desired" = on ]; then
      apply_proxy_on && flipped=1
    else
      apply_proxy_off && flipped=1
    fi
    if [ -n "$flipped" ]; then
      sig="ok:$desired:$actual"
      if [ "$sig" != "$last_sig" ]; then
        log "reconcile: proxy=$desired system=$mode_now -> applied $desired"
      fi
      last_sig="$sig"
      fail_prev=
    else
      [ -z "$fail_prev" ] && log "reconcile FAILED (gsettings write error); retrying each poll"
      fail_prev=1
      last_sig=""
    fi
  else
    last_sig=""
    fail_prev=
  fi
  return 0
}

log "start: pid=$$ grace=${STARTUP_GRACE}s poll=${POLL_SECS}s host=${PROXY_HOST}:${PROXY_PORT}"
reconcile

while true; do
  sleep "$POLL_SECS"
  reconcile
done
