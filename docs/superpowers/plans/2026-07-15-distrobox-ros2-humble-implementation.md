# Distrobox ROS 2 Humble Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproducibly bootstrap the existing Ubuntu 22.04 Distrobox until the shared ROS 2 sentry workspace completes `colcon build`.

**Architecture:** A Fedora-side MyUnix module validates the shared workspace and enters the named Distrobox. A container-side script owns ROS apt setup, private message-source checkout, rosdep, and ordered builds. The host dispatcher only exposes the module and retains retry state.

**Tech Stack:** Bash, Distrobox, Ubuntu 22.04 apt, ROS 2 Humble, rosdep, colcon, Git over user-provided SSH.

## Global Constraints

- Use ROS 2 Humble and its official apt source for Ubuntu 22.04.
- Build `sentry_msgs` from `git@github.com:HUSTLYRM/sentry.common.git` before the main workspace.
- Do not add, copy, print, or commit SSH keys.
- Do not change source files below `ros2_ly_ws_sentry` or `sentry.common`.
- Keep the helper idempotent and use MyUnix's existing failure/retry behaviour.

---

### Task 1: Add a tested ROS 2 Distrobox module

**Files:**
- Create: `modules/distrobox-ros2-humble/install.sh`
- Create: `modules/distrobox-ros2-humble/container-bootstrap.sh`
- Create: `tests/test_distrobox_ros2_humble.sh`

- [x] Write a failing module test that verifies defaults, workspace validation and the `distrobox enter` command.
- [x] Implement Fedora-side path/default helpers and a container-side idempotent bootstrap.
- [x] Run the focused test and Bash syntax validation.

### Task 2: Expose and document the module

**Files:**
- Modify: `scripts/myunix`
- Modify: `README.md`
- Modify: `docs/modules/distrobox.md`

- [x] Add `distrobox-ros2-humble` to the dispatcher without adding it to one-click installation.
- [x] Document prerequisites, SSH behaviour, invocation, variables and verification.
- [x] Run the complete MyUnix test suite and doctor check.
