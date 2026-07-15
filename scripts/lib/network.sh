#!/usr/bin/env bash
set -Eeuo pipefail

network_positive_integer() {
  local name=$1 value=$2
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    printf 'ERROR: %s must be a positive integer, got %s\n' "$name" "$value" >&2
    return 2
  }
}

network_attempts() {
  local attempts=${MYUNIX_NETWORK_ATTEMPTS:-3}
  network_positive_integer MYUNIX_NETWORK_ATTEMPTS "$attempts" || return $?
  printf '%s\n' "$attempts"
}

network_timeout_seconds() {
  local kind=$1 seconds
  case "$kind" in
    dnf) seconds=${MYUNIX_DNF_TIMEOUT_SECONDS:-1800} ;;
    download) seconds=${MYUNIX_DOWNLOAD_TIMEOUT_SECONDS:-600} ;;
    *) printf 'ERROR: Unknown network operation kind: %s\n' "$kind" >&2; return 2 ;;
  esac
  network_positive_integer "${kind} timeout" "$seconds" || return $?
  printf '%s\n' "$seconds"
}

network_retry_delay_seconds() {
  local attempt=$1
  case "$attempt" in
    1) printf '2\n' ;;
    *) printf '4\n' ;;
  esac
}

network_run() {
  local kind=$1 label=$2 attempts seconds attempt status delay
  shift 2
  (($# > 0)) || {
    printf 'ERROR: network_run requires a command.\n' >&2
    return 2
  }
  attempts="$(network_attempts)" || return $?
  seconds="$(network_timeout_seconds "$kind")" || return $?

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    printf '%s — attempt %s/%s\n' "$label" "$attempt" "$attempts"
    if timeout --foreground "${seconds}s" "$@"; then
      return 0
    else
      status=$?
    fi
    ((attempt == attempts)) && break
    delay="$(network_retry_delay_seconds "$attempt")"
    printf '%s failed (status %s); retrying in %ss.\n' "$label" "$status" "$delay" >&2
    sleep "$delay"
  done
  printf '%s failed after %s attempt(s), status %s.\n' "$label" "$attempts" "$status" >&2
  return "$status"
}
