#!/usr/bin/env bash
set -Eeuo pipefail

readonly MYUNIX_ROS2_DISTRO='humble'

: "${MYUNIX_ROS2_ROOT:?MYUNIX_ROS2_ROOT is required}"
: "${MYUNIX_ROS2_WORKSPACE:?MYUNIX_ROS2_WORKSPACE is required}"
: "${MYUNIX_ROS2_COMMON_WORKSPACE:?MYUNIX_ROS2_COMMON_WORKSPACE is required}"
: "${MYUNIX_ROS2_COMMON_REPOSITORY:?MYUNIX_ROS2_COMMON_REPOSITORY is required}"
: "${MYUNIX_ROS2_STATUS_FILE:?MYUNIX_ROS2_STATUS_FILE is required}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

write_status() {
  mkdir -p "$(dirname "$MYUNIX_ROS2_STATUS_FILE")"
  printf '%s\n' "$1" > "$MYUNIX_ROS2_STATUS_FILE"
}

record_completion_status() {
  local status=$?
  if ((status == 0)); then
    write_status succeeded
  else
    write_status failed
  fi
  exit "$status"
}

retry_network() {
  local label=$1 attempts=${MYUNIX_ROS2_NETWORK_ATTEMPTS:-3} attempt=1
  shift
  [[ "$attempts" =~ ^[1-9][0-9]*$ ]] || die "Invalid MYUNIX_ROS2_NETWORK_ATTEMPTS: $attempts"
  while ((attempt <= attempts)); do
    printf '[ros2-humble] %s (attempt %s/%s)\n' "$label" "$attempt" "$attempts"
    if "$@"; then
      return 0
    fi
    ((attempt == attempts)) && break
    printf '[ros2-humble] %s failed; retrying in %ss\n' "$label" "$attempt" >&2
    sleep "$attempt"
    attempt=$((attempt + 1))
  done
  die "$label failed after $attempts attempts"
}

source_setup_file() {
  local setup_file=$1
  [[ -f "$setup_file" ]] || die "Missing ROS setup file: $setup_file"
  # ROS setup scripts read optional variables without nounset-safe defaults.
  set +u
  # shellcheck disable=SC1090
  source "$setup_file"
  set -u
}

write_status running
trap record_completion_status EXIT

install_ros_apt_source() {
  local version codename metadata_file package_file
  dpkg-query -W -f='${Status}' ros2-apt-source 2>/dev/null | grep -qx 'install ok installed' && return 0
  metadata_file="$(mktemp)"
  retry_network 'Fetching ROS apt source metadata' \
    curl --fail --location --silent --show-error --output "$metadata_file" \
      https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest
  version="$(awk -F'"' '/"tag_name"/ { print $4; exit }' "$metadata_file")"
  rm -f "$metadata_file"
  [[ -n "$version" ]] || die 'Unable to resolve the current ros2-apt-source release'
  # shellcheck disable=SC1091
  source /etc/os-release
  codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  package_file="$(mktemp)"
  retry_network 'Downloading ROS apt source package' \
    curl --fail --location --output "$package_file" \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${version}/ros2-apt-source_${version}.${codename}_all.deb"
  sudo dpkg -i "$package_file"
  rm -f "$package_file"
}

install_ros_humble() {
  sudo -v
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales software-properties-common curl git openssh-client \
    build-essential cmake libboost-all-dev libfmt-dev
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  sudo add-apt-repository -y universe
  install_ros_apt_source
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "ros-${MYUNIX_ROS2_DISTRO}-ros-base" \
    ros-dev-tools python3-rosdep python3-vcstool
}

prune_ros_desktop() {
  case "${MYUNIX_ROS2_PRUNE_DESKTOP:-0}" in
    0) return 0 ;;
    1) ;;
    *) die "Invalid MYUNIX_ROS2_PRUNE_DESKTOP: ${MYUNIX_ROS2_PRUNE_DESKTOP}" ;;
  esac
  dpkg-query -W -f='${Status}' "ros-${MYUNIX_ROS2_DISTRO}-desktop" 2>/dev/null | grep -qx 'install ok installed' || return 0
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "ros-${MYUNIX_ROS2_DISTRO}-desktop"
  sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
}

initialize_rosdep() {
  [[ -f /etc/ros/rosdep/sources.list.d/20-default.list ]] || retry_network 'Initializing rosdep' sudo rosdep init
  retry_network 'Updating rosdep sources' rosdep update
}

ensure_common_workspace() {
  if [[ -d "$MYUNIX_ROS2_COMMON_WORKSPACE/.git" ]]; then
    return 0
  fi
  [[ ! -e "$MYUNIX_ROS2_COMMON_WORKSPACE" ]] || die "Common workspace exists but is not a Git checkout: $MYUNIX_ROS2_COMMON_WORKSPACE"
  mkdir -p "$(dirname "$MYUNIX_ROS2_COMMON_WORKSPACE")"
  git clone "$MYUNIX_ROS2_COMMON_REPOSITORY" "$MYUNIX_ROS2_COMMON_WORKSPACE"
}

build_workspaces() {
  [[ -f "$MYUNIX_ROS2_COMMON_WORKSPACE/src/sentry_msgs/package.xml" ]] || die "Missing sentry_msgs source: $MYUNIX_ROS2_COMMON_WORKSPACE/src/sentry_msgs/package.xml"
  [[ -d "$MYUNIX_ROS2_WORKSPACE/src" ]] || die "Missing ROS workspace src/: $MYUNIX_ROS2_WORKSPACE"

  source_setup_file "/opt/ros/${MYUNIX_ROS2_DISTRO}/setup.bash"
  cd "$MYUNIX_ROS2_COMMON_WORKSPACE"
  colcon build --packages-select sentry_msgs
  source_setup_file "$MYUNIX_ROS2_COMMON_WORKSPACE/install/setup.bash"

  cd "$MYUNIX_ROS2_WORKSPACE"
  # This workspace records Debian package names and ament_python directly in
  # package.xml. fmt and Boost are installed above; none of these are rosdep keys.
  rosdep install --from-paths src --ignore-src -y --rosdistro "$MYUNIX_ROS2_DISTRO" \
    --skip-keys "sentry_msgs ament_python libfmt-dev libboost-all-dev"
  colcon build
}

verify_installation() {
  source_setup_file "/opt/ros/${MYUNIX_ROS2_DISTRO}/setup.bash"
  source_setup_file "$MYUNIX_ROS2_COMMON_WORKSPACE/install/setup.bash"
  source_setup_file "$MYUNIX_ROS2_WORKSPACE/install/setup.bash"
  command -v ros2 >/dev/null
  command -v colcon >/dev/null
  ros2 pkg prefix sentry_msgs >/dev/null
}

install_ros_humble
prune_ros_desktop
initialize_rosdep
ensure_common_workspace
build_workspaces
verify_installation
printf '%s\n' 'ROS 2 Humble and both workspaces are ready.'
