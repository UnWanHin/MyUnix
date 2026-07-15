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
