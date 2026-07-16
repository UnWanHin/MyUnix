#!/usr/bin/env bash
set -Eeuo pipefail

readonly DISTROBOX_ROS2_HUMBLE_DEFAULT_COMMON_REPOSITORY='git@github.com:HUSTLYRM/sentry.common.git'

distrobox_ros2_humble_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

distrobox_ros2_humble_container_name() {
  printf '%s\n' "${MYUNIX_ROS2_CONTAINER:-ubuntu22}"
}

distrobox_ros2_humble_root() {
  printf '%s\n' "${MYUNIX_ROS2_ROOT:-$HOME/Documents/DirtroBox/Ubuntu-22.04}"
}

distrobox_ros2_humble_workspace() {
  printf '%s\n' "${MYUNIX_ROS2_WORKSPACE:-$(distrobox_ros2_humble_root)/ros2_ly_ws_sentry}"
}

distrobox_ros2_humble_common_workspace() {
  printf '%s\n' "${MYUNIX_ROS2_COMMON_WORKSPACE:-$(distrobox_ros2_humble_root)/sentry.common}"
}

distrobox_ros2_humble_common_repository() {
  printf '%s\n' "${MYUNIX_ROS2_COMMON_REPOSITORY:-$DISTROBOX_ROS2_HUMBLE_DEFAULT_COMMON_REPOSITORY}"
}

distrobox_ros2_humble_status_file() {
  printf '%s\n' "${MYUNIX_ROS2_STATUS_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/myunix/distrobox-ros2-humble/status}"
}

distrobox_ros2_humble_validate() {
  local root workspace bootstrap
  root="$(distrobox_ros2_humble_root)"
  workspace="$(distrobox_ros2_humble_workspace)"
  bootstrap="$(distrobox_ros2_humble_dir)/container-bootstrap.sh"
  require_command distrobox
  [[ -d "$root" ]] || die "ROS 2 shared root does not exist: $root"
  [[ -d "$workspace/src" ]] || die "ROS 2 workspace does not contain src/: $workspace"
  [[ -f "$bootstrap" ]] || die "Missing ROS 2 container bootstrap: $bootstrap"
}

distrobox_ros2_humble_run() {
  local container root workspace common repository bootstrap status_file distrobox_status status
  container="$(distrobox_ros2_humble_container_name)"
  root="$(distrobox_ros2_humble_root)"
  workspace="$(distrobox_ros2_humble_workspace)"
  common="$(distrobox_ros2_humble_common_workspace)"
  repository="$(distrobox_ros2_humble_common_repository)"
  bootstrap="$(distrobox_ros2_humble_dir)/container-bootstrap.sh"
  status_file="$(distrobox_ros2_humble_status_file)"
  rm -f "$status_file"

  distrobox_status=0
  distrobox enter "$container" -- env \
    MYUNIX_ROS2_ROOT="$root" \
    MYUNIX_ROS2_WORKSPACE="$workspace" \
    MYUNIX_ROS2_COMMON_WORKSPACE="$common" \
    MYUNIX_ROS2_COMMON_REPOSITORY="$repository" \
    MYUNIX_ROS2_STATUS_FILE="$status_file" \
    bash "$bootstrap" || distrobox_status=$?

  [[ -f "$status_file" ]] || die 'ROS 2 container bootstrap did not report a completion status'
  status="$(<"$status_file")"
  [[ "$status" == succeeded ]] || die "ROS 2 container bootstrap failed (status: $status)"
  ((distrobox_status == 0)) || die "Distrobox exited with status $distrobox_status"
}

install_distrobox_ros2_humble() {
  is_fedora || die 'Fedora is required'
  distrobox_ros2_humble_validate
  info "Bootstrapping ROS 2 Humble in $(distrobox_ros2_humble_container_name)"
  distrobox_ros2_humble_run
  info 'ROS 2 Humble bootstrap completed. Enter the container and source the workspace setup file.'
}
