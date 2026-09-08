# Portable DNF profile and source registry

## Context

The old DNF export captured every package marked user-installed. That list is
useful for review, but it also contains Fedora installation dependencies,
kernel and firmware packages, boot components, device drivers and packages
already owned by focused MyUnix modules. Replaying it on another computer would
make migrations brittle and could select the wrong hardware configuration.

Repository setup had a similar gap: ChatGPT and VS Code relied on local DNF
repository files, while the Niri + DMS module enabled a DMS COPR that did not
match the installed `dms-git` package and omitted the Niri COPR.

## Decision

`modules/dnf/portable.txt` is the one-click application and tool profile.
`modules/dnf/sources.tsv` is the reviewed source registry with three scopes:

- `profile` provides the portable profile's RPM Fusion, ChatGPT and VS Code
  packages.
- `niri-dms` provides the DankLinux, DMS Git and YaLTeR Niri COPRs only when
  that optional desktop module is selected.
- `catalog` records a known source without enabling it automatically.

The ChatGPT repository key is a public signing key checked into the source
tree. It permits RPM signature verification; it is not a Codex key, login,
token or credential.

`exported-userinstalled.txt` and `exported-enabled-repositories.txt` remain
review snapshots, never automatic installation inputs.

## Consequences

A new computer restores the useful workstation DNF tools and their required
sources without searching for package names or repository setup. Feature
modules retain ownership of their packages and setup. Hardware, account and
session-specific state remains local to the new computer.
