# Niri + DMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in Fedora Niri + DMS desktop stack and an explicitly confirmed DankGreeter/greetd replacement with a tested GDM rollback path.

**Architecture:** A new `niri-dms` module installs and exports user-scoped desktop configuration. A separate `niri-dms-greeter` module owns the system display-manager change, records service/configuration backup state before mutation, and is never selected by `--all`. The stable CLI dispatches both modules and a rollback command without changing GNOME exports.

**Tech Stack:** Bash, DNF/COPR, systemd, greetd, DMS/DankGreeter, Niri, Kitty, dconf-independent file exports, ShellCheck and Bash tests.

## Global Constraints

- Support only Fedora 43/44 for DMS/DankGreeter; reject unsupported releases before changes.
- Keep GNOME packages and desktop-session files installed; never make Niri the forced default session.
- Do not execute `curl | sh`; use documented DNF packages and DMS commands.
- The Greeter replacement requires an explicit module command and a typed confirmation; `install --all` must skip it.
- Backup `/etc/greetd/config.toml` and GDM/greetd enabled state under `/var/lib/myunix/backups/` before a system change.
- `rollback niri-dms-greeter` restores service state and configuration without deleting user data.

---

### Task 1: Add Niri+DMS module contracts and release gates

**Files:**
- Create: `modules/niri-dms/install.sh`
- Create: `modules/niri-dms/export.sh`
- Create: `modules/niri-dms/packages.txt`
- Create: `tests/test_niri_dms.sh`
- Create: `docs/modules/niri-dms.md`
- Modify: `scripts/myunix`

- [ ] Write a failing test that sets `MYUNIX_FEDORA_RELEASE=42`, invokes `install_niri_dms`, and asserts exit status 2 plus `DMS is supported only on Fedora 43 or 44`.
- [ ] Run `bash tests/test_niri_dms.sh`; expect failure because the module does not exist.
- [ ] Implement `fedora_release`, `require_dms_supported_fedora`, and `install_niri_dms`. It must call the documented stable DMS DNF package route, install Niri/Kitty/Hyfetch/Nerd Font dependencies from `packages.txt`, and never invoke display-manager commands.
- [ ] Add an export function that copies allowlisted Niri, DMS, Kitty and P10k files into the module config directory without touching `.zsh_history` or arbitrary plugins.
- [ ] Add `niri-dms` to `run_module`; keep it outside existing GNOME logic.
- [ ] Run `bash tests/run.sh` and `bash -n modules/niri-dms/*.sh scripts/myunix`; commit `feat: add Niri and DMS desktop module`.

### Task 2: Implement DankGreeter preflight, backup and explicit activation

**Files:**
- Create: `modules/niri-dms-greeter/install.sh`
- Create: `modules/niri-dms-greeter/rollback.sh`
- Create: `tests/test_greeter.sh`
- Create: `docs/modules/niri-dms-greeter.md`
- Modify: `scripts/myunix`

- [ ] Write failing tests that fake `systemctl`, `dms`, `cp`, and `read`; assert activation refuses without `MYUNIX_CONFIRM_GREETER=replace-gdm`, writes a backup manifest before disabling GDM, and never runs during `install --all`.
- [ ] Run `bash tests/test_greeter.sh`; expect failure because the greeter module is absent.
- [ ] Implement preflight checks for Fedora support, `dms-greeter`, `greetd`, Niri, and an installed GNOME session file. Capture `systemctl is-enabled gdm/greetd` and copy existing greetd config to a timestamped `/var/lib/myunix/backups/niri-dms-greeter/` directory.
- [ ] Implement activation in this order: `dms greeter status`; `dms greeter enable`; `dms greeter sync`; verify status; only then disable GDM and enable greetd. Record the backup path.
- [ ] Add module selection only through `./scripts/myunix install --module niri-dms-greeter`; reject it from `--all` and guide the user to use the explicit command.
- [ ] Run all tests and syntax validation; commit `feat: add guarded DankGreeter activation`.

### Task 3: Implement GDM rollback and end-user documentation

**Files:**
- Modify: `modules/niri-dms-greeter/rollback.sh`
- Modify: `scripts/myunix`
- Modify: `README.md`
- Create: `docs/verification/niri-dms-smoke-test.md`

- [ ] Write a failing rollback test with backup fixtures; assert it restores `config.toml`, disables/stops greetd, and re-enables GDM in that order.
- [ ] Implement `rollback_niri_dms_greeter backup_path`, require an explicit backup path or latest valid backup, and refuse missing/malformed backup metadata.
- [ ] Expose `./scripts/myunix rollback niri-dms-greeter [backup-path]` and print the exact TTY fallback instructions if the user has already lost a graphical session.
- [ ] Document installation, login-session selection, DMS theme sync, Kitty/Nerd Font/P10k setup, activation, rollback, and Fedora VM smoke test procedure.
- [ ] Run `bash tests/run.sh`, syntax checks, and `./scripts/myunix doctor`; commit `docs: add Niri DMS verification and rollback guide`.
