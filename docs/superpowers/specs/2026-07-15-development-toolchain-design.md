# Development Toolchain Migration

## Status

Approved.

## Goal

Capture the verified Fedora 44 development environment as an isolated MyUnix
module, and expose it as a step in custom installation after input-method
selection.

## Inventory

The recorded environment is JDK/Javac 26.0.1, CMake 4.4.0, Ninja 1.13.2,
Rust/Cargo 1.96.1, Python 3.14.6, Anaconda 25.11.1, Node.js 22.22.2, Go
1.26.5, GCC 16.1.1 and Clang 22.1.8. DNF-managed package versions are Fedora
repository snapshots, so future Fedora revisions can install newer compatible
versions; the verifier reports the installed result.

## Architecture

Add `modules/development-toolchain/` with four responsibilities:

- `packages.tsv` maps selectable DNF components to packages; `build-tools`
  also installs Fedora's `Development Tools` group.
- `install.sh` resolves selected components, handles privileged system work,
  and delegates only portable downloads to the user scope.
- `config/` holds reviewed user-shell integration and `verify.sh`; it never
  contains downloaded binaries or user environments.
- `docs/modules/development-toolchain.md` records exact sources, scope
  behaviour and rebuild instructions.

Custom installation becomes a sequenced wizard: first input methods, then an
optional **Development Toolchain** selection. If selected, users toggle
components and choose System or User scope. One-click remains a conservative
desktop baseline and does not install the toolchain.

## Scope model

### System

Fedora packages install through DNF. JDK 26.0.1, CMake 4.4.0 and Anaconda
25.11.1 install under `/opt`; `alternatives`, `/usr/local/bin` and
`/etc/profile.d` expose them to all users. This mirrors the verified source
scripts.

### User

JDK, CMake and Anaconda install under `~/.local/opt`; command links are below
`~/.local/bin`. A managed `~/.config/sysrc.d/development-toolchain.rc`
exports the selected portable locations. The shared `.sysrc` becomes a
sorted `sysrc.d/*.rc` loader so toolchain integration stays in its own file.

Ninja, Rust/Cargo, Python development packages, Node.js, Go, GCC, Clang and
the Fedora development group remain DNF system packages in both scope modes.
They need system libraries, compilers or package integration and are not
silently replaced by unrelated user-level version managers.

## Interfaces

- `install_development_toolchain scope components_csv`
  accepts `system|user` and a comma-separated selection; an omitted component
  list means all documented components.
- `MYUNIX_TOOLCHAIN_SCOPE` and `MYUNIX_TOOLCHAIN_COMPONENTS` provide a
  noninteractive module interface.
- `choose_custom_development_toolchain` sets those variables after the
  input-method screen in the TTY wizard.

## Safety and privacy

- No downloaded archive, Conda environment, package cache, credentials or
  project dependency is committed.
- Downloads use fixed official HTTPS URLs and temporary directories.
- User shell files are backed up under `~/.local/state/myunix/` before MyUnix
  replaces its managed toolchain fragment.
- The existing `~/temp` material is reference-only and is never moved,
  edited or deleted by MyUnix.

## Verification

Tests cover component resolution, system/user path selection, generated shell
integration, wizard sequencing and verification-command rendering. The full
shell suite, Bash syntax checks, `doctor`, Niri validation and diff checks run
before synchronization.
