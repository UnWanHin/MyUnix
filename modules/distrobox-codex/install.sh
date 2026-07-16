#!/usr/bin/env bash
set -Eeuo pipefail

distrobox_codex_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

distrobox_codex_container_name() {
  printf '%s\n' "${MYUNIX_CODEX_CONTAINER:-ubuntu22}"
}

distrobox_codex_home() {
  printf '/opt/distrobox/%s/.codex\n' "$(distrobox_codex_container_name)"
}

distrobox_codex_status_file() {
  printf '%s\n' "${MYUNIX_CODEX_STATUS_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/myunix/distrobox-codex/status}"
}

distrobox_codex_validate() {
  require_command distrobox
  [[ -f "$(distrobox_codex_dir)/container-bootstrap.sh" ]] || die 'Missing Distrobox Codex bootstrap script'
}

distrobox_codex_run() {
  local container codex_home bootstrap status_file distrobox_status status
  container="$(distrobox_codex_container_name)"
  codex_home="$(distrobox_codex_home)"
  bootstrap="$(distrobox_codex_dir)/container-bootstrap.sh"
  status_file="$(distrobox_codex_status_file)"
  rm -f "$status_file"

  distrobox_status=0
  distrobox enter "$container" -- env \
    MYUNIX_CODEX_HOME="$codex_home" \
    MYUNIX_CODEX_STATUS_FILE="$status_file" \
    bash "$bootstrap" || distrobox_status=$?

  [[ -f "$status_file" ]] || die 'Distrobox Codex bootstrap did not report a completion status'
  status="$(<"$status_file")"
  [[ "$status" == succeeded ]] || die "Distrobox Codex bootstrap failed (status: $status)"
  ((distrobox_status == 0)) || die "Distrobox exited with status $distrobox_status"
}

install_distrobox_codex() {
  is_fedora || die 'Fedora is required'
  distrobox_codex_validate
  info "Installing container-native Codex in $(distrobox_codex_container_name)"
  distrobox_codex_run
  info 'Container-native Codex installed. Enter the container and run codex.'
}
