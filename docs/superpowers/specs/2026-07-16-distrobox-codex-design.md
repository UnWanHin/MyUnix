# Distrobox Codex Design

## Goal

Make the `codex` command available natively inside the existing Ubuntu 22.04
`ubuntu22` Distrobox so it can run ROS 2 and `colcon` commands in that
container rather than on Fedora.

## Decision

The module installs a current Node.js LTS runtime from the official Node.js
release archive below `/opt/myunix/codex-node`, verifies the archive against
the matching upstream SHA-256 manifest, and installs `@openai/codex` below
`/opt/myunix/codex`. A small container-local `/usr/local/bin/codex` wrapper
uses that runtime and CLI.

This keeps the runtime independent of Ubuntu 22.04's potentially outdated
`nodejs` package and does not change Fedora's Node.js or Codex installation.

## Authentication boundary

The CLI uses `/opt/distrobox/ubuntu22/.codex`, owned by the desktop user,
instead of the shared home-directory Codex state. On first setup the module
copies only `~/.codex/config.toml` to preserve non-secret model settings; it
does not copy `auth.json`. The module never accepts a key as an argument or
writes credentials to the repository. The user completes the normal
interactive `codex login` command inside the container.

## Interface and verification

The public MyUnix entry point is:

```bash
./scripts/myunix install --module distrobox-codex
```

It defaults to the `ubuntu22` container and supports
`MYUNIX_CODEX_CONTAINER` to select another existing container. The bootstrap
must verify `codex --version`; it does not run a model request or expose any
secret in logs.

Sources: <https://nodejs.org/dist/> and
<https://www.npmjs.com/package/@openai/codex>.
