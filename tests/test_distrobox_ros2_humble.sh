#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

module="$PROJECT_ROOT/modules/distrobox-ros2-humble/install.sh"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$module'; distrobox_ros2_humble_container_name"
assert_status 0
assert_equals 'ubuntu22' "$OUTPUT"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$module'; MYUNIX_ROS2_ROOT=/tmp/ros-root; distrobox_ros2_humble_workspace"
assert_status 0
assert_equals '/tmp/ros-root/ros2_ly_ws_sentry' "$OUTPUT"

temporary_root="$(mktemp -d)"
mkdir -p "$temporary_root/ros2_ly_ws_sentry/src"
run env MYUNIX_TEST_MODE=fedora MYUNIX_ROS2_ROOT="$temporary_root" XDG_STATE_HOME="$temporary_root/state" bash -c '
  distrobox() {
    local argument status_file=
    printf "distrobox %s\\n" "$*"
    for argument in "$@"; do
      case "$argument" in
        MYUNIX_ROS2_STATUS_FILE=*) status_file="${argument#*=}" ;;
      esac
    done
    [ -n "$status_file" ] || return 17
    mkdir -p "$(dirname "$status_file")"
    printf succeeded > "$status_file"
  }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/modules/distrobox-ros2-humble/install.sh"
  install_distrobox_ros2_humble
'
assert_status 0
assert_output_contains 'distrobox enter ubuntu22 -- env'
assert_output_contains 'MYUNIX_ROS2_COMMON_REPOSITORY=git@github.com:HUSTLYRM/sentry.common.git'
assert_output_contains 'MYUNIX_ROS2_STATUS_FILE='
assert_output_contains 'ROS 2 Humble bootstrap completed'

bootstrap="$PROJECT_ROOT/modules/distrobox-ros2-humble/container-bootstrap.sh"
run grep -F 'MYUNIX_ROS2_DISTRO='"'"'humble'"'"'' "$bootstrap"
assert_status 0
run grep -F '"ros-${MYUNIX_ROS2_DISTRO}-ros-base"' "$bootstrap"
assert_status 0
run grep -F 'readonly ROS_DISTRO=' "$bootstrap"
assert_status 1
run grep -F 'MYUNIX_ROS2_PRUNE_DESKTOP' "$bootstrap"
assert_status 0
run grep -F '"ros-${MYUNIX_ROS2_DISTRO}-ament-python"' "$bootstrap"
assert_status 1
run grep -F 'rosdep install --from-paths src --ignore-src -y --rosdistro' "$bootstrap"
assert_status 0
run grep -F 'colcon build --packages-select sentry_msgs' "$bootstrap"
assert_status 0
run grep -F 'ros2-apt-source_${version}.${codename}_all.deb' "$bootstrap"
assert_status 0
run grep -F "retry_network 'Initializing rosdep' sudo rosdep init" "$bootstrap"
assert_status 0
run grep -F "retry_network 'Updating rosdep sources' rosdep update" "$bootstrap"
assert_status 0
run grep -F -- '--skip-keys "sentry_msgs ament_python libfmt-dev libboost-all-dev"' "$bootstrap"
assert_status 0
run grep -F 'source_setup_file "/opt/ros/${MYUNIX_ROS2_DISTRO}/setup.bash"' "$bootstrap"
assert_status 0
run grep -F 'set +u' "$bootstrap"
assert_status 0
