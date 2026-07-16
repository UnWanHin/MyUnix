# Distrobox

This optional module installs Fedora's `distrobox` package and verifies the
command. It relies on the existing Podman installation, but does **not** create
a container, pull `ubuntu:22.04`, configure a registry mirror or export any
container state.

```bash
./scripts/myunix install --module distrobox
```

When you decide to create an Ubuntu 22.04 development container later:

```bash
distrobox create --name ubuntu22 --image ubuntu:22.04
distrobox enter ubuntu22
```

The default container shares your home directory. For a clean Ubuntu-only home
instead, add `--home ~/.local/share/distrobox/ubuntu22-home` at creation time.
Containers, images, package caches and project files are intentionally not
exported by MyUnix; recreate them deliberately on a new computer.

## Codex inside Ubuntu containers

Use the separate `distrobox-codex` module when Codex needs to execute commands
inside Ubuntu itself, such as ROS 2 Humble and `colcon` commands. It installs a
current Node.js 22 runtime from the official Node.js archive after verifying
the matching SHA-256 manifest, then installs the official `@openai/codex` npm
package below `/opt/myunix` in the selected container.

```bash
./scripts/myunix install --module distrobox-codex

distrobox enter ubuntu22
codex
```

The default target is `ubuntu22`; select another existing container with
`MYUNIX_CODEX_CONTAINER=name`. The command is native to the container, so its
shell commands run against Ubuntu's ROS environment rather than Fedora.

The Ubuntu22 CLI uses the dedicated container path
`/opt/distrobox/ubuntu22/.codex`, not the shared Fedora `~/.codex` directory.
On the first install it copies only the existing `config.toml` to retain model
settings; it does not copy `auth.json`, API keys, or tokens. Complete the
separate container login once with `codex login` inside the container.

Sources: <https://nodejs.org/dist/> and
<https://www.npmjs.com/package/@openai/codex>.

## ROS 2 Humble sentry workspace

The separate `distrobox-ros2-humble` module prepares the existing `ubuntu22`
container until the shared sentry workspace can finish `colcon build`. It uses
official ROS 2 Humble ROS-Base and development packages for Ubuntu 22.04, clones the private external
`sentry.common` message workspace with your existing SSH configuration, builds
`sentry_msgs` first, and then runs rosdep and `colcon build` for the sentry
workspace.

The workspace records `ament_python`, `libfmt-dev`, and `libboost-all-dev` as
package dependencies even though they are not valid rosdep keys. The module
installs fmt and Boost explicitly and gets the ROS ament build environment from
the Humble ROS-Base meta-package, then skips only those known invalid keys
during rosdep resolution. The skip list is deliberately passed to rosdep as one
quoted argument; otherwise rosdep treats subsequent key names as filesystem
paths. There is no `ros-humble-ament-python` Ubuntu package.

It never copies an SSH key, never creates a fake `sentry_msgs`, and never adds
the ROS package installation to Fedora.

```bash
MYUNIX_ROS2_ROOT="$HOME/Documents/DirtroBox/Ubuntu-22.04" \
./scripts/myunix install --module distrobox-ros2-humble
```

If an earlier run installed the larger `ros-humble-desktop` meta-package, opt
into its removal and an apt autoremove pass while preserving ROS-Base and the
packages required by rosdep:

```bash
MYUNIX_ROS2_ROOT="$HOME/Documents/DirtroBox/Ubuntu-22.04" \
MYUNIX_ROS2_PRUNE_DESKTOP=1 \
./scripts/myunix install --module distrobox-ros2-humble
```

Defaults are `ubuntu22`,
`$HOME/Documents/DirtroBox/Ubuntu-22.04/ros2_ly_ws_sentry`, and its sibling
`sentry.common`. Override the container or source location only when needed:

```bash
MYUNIX_ROS2_CONTAINER=ubuntu22 \
MYUNIX_ROS2_COMMON_REPOSITORY=git@github.com:HUSTLYRM/sentry.common.git \
./scripts/myunix install --module distrobox-ros2-humble
```

After a successful run, enter the container and load both overlays in order:

```bash
distrobox enter ubuntu22
source /opt/ros/humble/setup.zsh
source ~/Documents/DirtroBox/Ubuntu-22.04/sentry.common/install/setup.zsh
source ~/Documents/DirtroBox/Ubuntu-22.04/ros2_ly_ws_sentry/install/setup.zsh
```

The ROS package setup follows the official Humble Debian-package and rosdep
instructions: <https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html>
and <https://docs.ros.org/en/humble/Tutorials/Intermediate/Rosdep.html>.
