# Fedora GNOME migration design

**Status:** approved in conversation; awaiting written-spec review

## Purpose

MyUnix will recreate a Fedora GNOME workstation after a computer replacement. It will install system packages and optional desktop applications, restore selected GNOME and input-method settings, and document every managed source. The repository must remain safe to publish and straightforward to maintain.

## Goals

- Provide an interactive installer with one-click, guided, retry, and full re-run flows.
- Keep system package installation, direct RPM installation, GNOME configuration, input methods, and exporting as independent modules.
- Restore custom GNOME hotkeys as user settings, while keeping package and repository work privileged and explicit.
- Export only public, reproducible configuration. SSH keys, credentials, account tokens, browser profiles, and other private data are out of scope.
- Install direct RPMs by downloading their HTTPS URLs with `wget` to a temporary directory, verifying SHA-256, then invoking DNF. RPM binaries are never committed.
- Treat RPM Fusion as a Fedora repository setup module; no PPA abstraction is used.

## Repository layout

```text
AGENTS.md
README.md
scripts/
  myunix                    # stable command-line entry point
  lib/                       # logging, prompts, safety, state, DNF/RPM helpers
modules/
  bootstrap/                 # Fedora validation and RPM Fusion
  dnf/                       # maintained DNF package manifests
  rpm/                       # URL/checksum RPM manifest and installer
  gnome/                     # exported dconf data, including custom hotkeys
  input-method/              # IBus, Fcitx5, Rime, Mozc packages and public config
  export/                    # collection from an existing Fedora machine
docs/
  superpowers/specs/          # design and later implementation plan
  modules/                    # source, update, and troubleshooting documentation
tests/                        # shell-level validation and manifest fixtures
```

Each module owns its manifests, installation logic, verification, and documentation. The entry point only parses commands, performs shared safety checks, and invokes modules in dependency order.

## Command interface

`./scripts/myunix install` is interactive when attached to a terminal and presents:

1. **Install everything** — runs all enabled modules and applications.
2. **Custom installation** — select modules, then answer a separate yes/no prompt for each optional application such as QQ and WeChat.
3. **Retry last failures** — executes only failed state entries.
4. **Run everything again** — rechecks and re-executes all selected items safely.

Non-interactive and targeted equivalents are:

```bash
./scripts/myunix install --all
./scripts/myunix install --guided
./scripts/myunix install --module gnome
./scripts/myunix retry
./scripts/myunix export
./scripts/myunix doctor
```

`--all` never prompts; it uses the enabled defaults in the versioned manifests. `--guided` performs the same choices as the menu. Modules can be invoked independently so failures are contained and diagnosis is simple.

## Configuration data

### DNF and RPM data

DNF manifests list packages declaratively, with core and optional sets kept separate. The direct-RPM manifest records at least an identifier, display name, HTTPS URL, SHA-256, optional/default selection, and verification command. The RPM installer uses `mktemp -d`, `wget`, checksum verification, and `sudo dnf install`; cleanup runs on every exit path.

RPM Fusion setup is an idempotent bootstrap action. It verifies Fedora before enabling the official free and non-free RPM Fusion release RPMs and refreshing metadata.

### GNOME and input methods

GNOME settings are treated as target-user settings. Export collects only scoped dconf paths needed by this repository, especially the media-keys custom-keybinding list and individual binding paths. Import creates a timestamped backup of those scoped paths before loading the stored data; it never runs through `sudo`.

The input-method module owns public IBus and Fcitx5 configuration plus package manifests for IBus, Fcitx5, Rime, Mozc, and Chinese support components. It reports post-install actions that require a GNOME logout or restart. It does not copy user dictionaries or other unreviewed private data by default.

### State

The installer records selected, succeeded, skipped, and failed items below `~/.local/state/myunix/`. This local state enables retries and clean reporting but is ignored by Git. DNF and configuration operations themselves remain idempotent, so a full re-run is safe.

## Safety and failure behavior

- Refuse unsupported operating systems before making changes; print the detected Fedora release and desktop-session prerequisites.
- Ask before any destructive replacement of scoped GNOME configuration. Always create a local backup first.
- Use `sudo` only for package/repository work; preserve the invoking user's environment for GNOME and input-method configuration.
- Validate URLs, checksums, manifests, network reachability, and available tools before each module executes.
- Continue independent selected items where safe, summarize failures at the end, and make failed items available to `retry`.
- Never use `curl | sh` or commit downloaded executables or RPM files.

## Quality gates

- Shell scripts use Bash strict mode, quoted variables, explicit error paths, and a shared logging interface.
- Tests cover CLI selection, retry-state interpretation, manifest validation, checksum failure handling, and the guarantee that user-level GNOME commands are not elevated.
- Before every commit, run the test suite, `bash -n` against all scripts, and ShellCheck where installed.
- Document each package source, desktop-session prerequisite, and any required logout/restart in the relevant module document and README.

## Non-goals

- Migrating SSH keys, credentials, browser profiles, or user account data.
- Managing hardware drivers, disk layout, secure boot keys, or immutable Fedora variants in the first release.
- Treating a direct RPM URL as permanent: maintainers must update its manifest and checksum whenever its upstream version changes.
