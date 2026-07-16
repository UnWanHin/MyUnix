# Steam Niri Integration Design

## Context

Steam is supplied by RPM Fusion as the Fedora `steam` DNF package. It is not a
publisher-hosted direct RPM and must not be placed in `modules/rpm/apps.tsv`,
which is reserved for HTTPS downloads with a pinned checksum.

Steam's CEF/OpenGL compositor can render its main window blank under Niri's
Wayland session through Xwayland Satellite. Niri documents `-system-composer`
as a GPU-preserving workaround, and Valve issue #12320 confirms it fixes the
same Niri symptom.

Sources:

- https://github.com/YaLTeR/niri/wiki/Application-Issues#steam
- https://github.com/ValveSoftware/steam-for-linux/issues/12320

## Decision

Add an isolated `modules/steam/` module that installs and verifies the RPM
Fusion `steam` DNF package, then generates a per-user `steam.desktop` override
which adds `-system-composer` to every Steam `Exec=` action.

The module runs after `bootstrap`, because bootstrap enables RPM Fusion. It is
included in one-click installation. Custom installation presents an explicit
Steam option before package installation starts.

## Boundaries

- `modules/dnf/` owns generic Fedora package manifests.
- `modules/rpm/` owns downloaded publisher RPMs only.
- `modules/steam/` owns RPM Fusion Steam installation and its user desktop
  override.
- `modules/niri-dms/` remains responsible for Niri/DMS setup and does not
  install Steam.

## Behaviour and safety

The module installs through the existing DNF network wrapper and verifies with
`rpm -q steam`. It copies the system desktop file to
`~/.local/share/applications/steam.desktop`, injects `-system-composer` after
`/usr/bin/steam` in every `Exec=` line, and adds `X-MyUnix-Managed=true`.
Existing user overrides are backed up below `~/.local/state/myunix/backups/steam/`.
Re-running is idempotent. The module never edits `/usr/share`, disables GPU
acceleration, or downloads a direct RPM.

## Verification

Tests cover DNF invocation, `rpm -q steam`, desktop-action transformation,
backup creation, and repeat execution. Run the project suite, Bash syntax
checks, and ShellCheck when available before committing.
