# Steam Niri Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make RPM Fusion Steam installation and its Niri `-system-composer` workaround reproducible through MyUnix.

**Architecture:** A new `modules/steam/` module installs the DNF package and generates the user desktop override. The top-level installer selects the module for one-click mode and offers it in custom mode.

**Tech Stack:** Bash, DNF, RPM, freedesktop desktop entries, Bats-style shell tests.

## Global Constraints

- Steam is a DNF/RPM Fusion package, not a direct downloaded RPM.
- Never edit `/usr/share/applications/steam.desktop`.
- Keep backups below `~/.local/state/myunix/`.
- Verify installation with `rpm -q steam`.
- Preserve GPU acceleration with `-system-composer`.

---

### Task 1: Implement and test the isolated Steam module

**Files:**
- Create: `modules/steam/install.sh`
- Create: `modules/steam/packages.txt`
- Create: `tests/test_steam.sh`

**Interfaces:**
- Consumes `install_dnf_manifest <manifest>`.
- Produces `install_steam` and `install_steam_desktop_override`.

- [ ] Write a failing `tests/test_steam.sh` that fakes DNF/RPM, supplies a
  temporary system desktop entry with main and action `Exec=` lines, and
  expects one `-system-composer` argument per line.
- [ ] Run `bash tests/test_steam.sh`; it must fail before the module exists.
- [ ] Add `packages.txt` containing `steam`, then implement installation,
  verification, backup, and an `awk` desktop-entry transform.
- [ ] Re-run `bash tests/test_steam.sh`; add idempotence and backup assertions
  until it exits zero.
- [ ] Commit only these three files with message `feat: add Steam RPM Fusion integration module`.

### Task 2: Add one-click and custom installer selection

**Files:**
- Modify: `scripts/myunix`
- Modify: `tests/test_install_flow.sh`

**Interfaces:**
- Consumes `install_steam`.
- Produces the `steam` module selector and the label `Steam (RPM Fusion; Niri compatible)`.

- [ ] Add a failing installer-flow test asserting one-click includes `steam`
  and custom mode invokes it only when selected.
- [ ] Run `bash tests/test_install_flow.sh`; it must fail before wiring.
- [ ] Source the module, dispatch `steam` in `run_module`, append it to
  one-click execution, and add a custom desktop-app choice.
- [ ] Run `bash tests/test_install_flow.sh && bash tests/test_steam.sh`; both
  must exit zero.
- [ ] Commit only this wiring and test with message `feat: offer Steam in MyUnix installation flows`.

### Task 3: Document the Niri compatibility decision

**Files:**
- Create: `docs/modules/steam.md`
- Modify: `README.md`
- Modify: `tests/test_steam.sh`

**Interfaces:**
- Documents `./scripts/myunix install --module steam`.

- [ ] Add a failing documentation assertion requiring RPM Fusion,
  `-system-composer`, and the Niri source link.
- [ ] Run `bash tests/test_steam.sh`; it must fail before the document exists.
- [ ] Add concise module documentation and a README module link, including the
  direct-RPM exclusion, backup location, and source links.
- [ ] Run all `tests/test_*.sh`, Bash syntax checks for every `scripts` and
  `modules` shell file, and ShellCheck when available.
- [ ] Commit only documentation and final test update with message
  `docs: record Steam Niri compositor workaround`.
