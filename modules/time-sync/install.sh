#!/usr/bin/env bash
set -Eeuo pipefail

time_sync_dir() {
  printf '%s\n' "${MYUNIX_TIME_SYNC_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
}

install_time_sync() {
  local module_dir wait_attempts wait_threshold
  is_fedora || die 'Fedora is required'
  module_dir="$(time_sync_dir)"
  wait_attempts="${MYUNIX_TIME_SYNC_WAIT_ATTEMPTS:-10}"
  wait_threshold="${MYUNIX_TIME_SYNC_WAIT_THRESHOLD:-0.1}"
  [[ "$wait_attempts" =~ ^[1-9][0-9]*$ ]] || die 'MYUNIX_TIME_SYNC_WAIT_ATTEMPTS must be a positive integer'
  [[ "$wait_threshold" =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'MYUNIX_TIME_SYNC_WAIT_THRESHOLD must be numeric'

  install_dnf_manifest "$module_dir/packages.txt"
  require_command systemctl
  require_command chronyc
  require_command timedatectl
  sudo systemctl enable --now chronyd.service
  sudo chronyc waitsync "$wait_attempts" "$wait_threshold"
  sudo chronyc makestep
  sudo timedatectl set-local-rtc 0
  info 'System time synchronized with chrony; existing timezone preserved.'
}
