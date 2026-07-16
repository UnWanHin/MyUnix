# Distrobox ROS 2 Humble Bootstrap

## Goal

Prepare the existing `ubuntu22` Distrobox to build the shared
`ros2_ly_ws_sentry` workspace with `colcon build`.

## Decision

Use ROS 2 Humble from the official ROS apt repository because the workspace
explicitly targets Ubuntu 22.04 and Humble. Install the official ROS-Base and
development-tool packages, then use `rosdep` for declared dependencies.

`sentry_msgs` is a private, external interface package. The bootstrap clones
`git@github.com:HUSTLYRM/sentry.common.git` as a sibling of the main workspace,
builds and sources `sentry_msgs` first, and then builds the main workspace. It
does not create a substitute message package or modify either ROS repository.

## Boundaries

- The Fedora host keeps owning Distrobox and Podman.
- All Ubuntu packages are installed only inside `ubuntu22` with its own sudo.
- The source workspaces remain below the shared host directory
  `~/Documents/DirtroBox/Ubuntu-22.04`.
- SSH configuration and keys remain user-owned and are never copied into Git.
- The helper accepts environment overrides for the container name, root,
  workspace path, common-workspace path and source repository.

## Verification

The bootstrap must verify `ros2`, `colcon`, the sourced `sentry_msgs` package,
and finish `colcon build` from `ros2_ly_ws_sentry`. A failed apt, clone,
rosdep, custom-message build, or main build stops the module so MyUnix can
offer its existing retry/defer flow.

## Sources

- ROS 2 Humble Debian packages:
  <https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html>
- rosdep workspace installation:
  <https://docs.ros.org/en/humble/Tutorials/Intermediate/Rosdep.html>
