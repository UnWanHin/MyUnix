# Niri Touchpad Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a persistent, guided-optional `Mod+F8` Niri/DMS touchpad command that is reproduced through MyUnix.

**Architecture:** A small user executable writes the single public Niri
touchpad override fragment atomically. Niri configuration includes that
fragment after normal input preferences, and the Niri+DMS module explicitly
installs and exports the one managed fragment without touching phone-connect
state.

**Tech Stack:** Bash, Niri KDL, DMS shortcut bindings, Bats-style shell tests.

## Global Constraints

- Run only as the target desktop user; no `sudo`.
- Default to an enabled touchpad after a fresh MyUnix installation.
- Preserve module isolation and do not export unrelated `myunix/` fragments.
- Maintain idempotence and use atomic writes for live Niri configuration.

---

### Task 1: Define and test the managed toggle contract

**Files:**

- Create: `modules/niri-dms/bin/niri-touchpad-toggle`
- Create: `modules/niri-dms/config/niri/myunix/touchpad.kdl`
- Modify: `tests/test_niri_dms.sh`

**Interfaces:**

- Consumes: `MYUNIX_NIRI_TOUCHPAD_STATE_FILE` and optional `MYUNIX_NOTIFY_SEND` test overrides.
- Produces: an enabled Niri `input { touchpad {} }` fragment or a disabled `input { touchpad { off } }` fragment.

- [x] Write failing tests that invoke the helper twice against a temporary state
  path and assert that the first invocation contains an exact `off` line and
  the second no longer does.
- [x] Run `bash tests/test_niri_dms.sh` and confirm the helper-path assertion
  fails before the helper exists.
- [x] Implement the executable with `set -Eeuo pipefail`, `mktemp` plus atomic
  `mv`, explicit enabled/disabled fragments, optional notification, and an
  opportunistic `niri msg action load-config-file`.
- [x] Add an enabled default fragment and run the focused test again.

### Task 2: Wire installation, export, and the Niri shortcut

**Files:**

- Modify: `modules/niri-dms/install.sh`
- Modify: `modules/niri-dms/export.sh`
- Modify: `modules/niri-dms/config/niri/config.kdl`
- Modify: `modules/niri-dms/config/niri/dms/binds.kdl`
- Modify: `tests/test_niri_dms.sh`

**Interfaces:**

- Installer copies `modules/niri-dms/bin/niri-touchpad-toggle` to
  `~/.local/bin/niri-touchpad-toggle` with executable permissions.
- Import/export own exactly `myunix/touchpad.kdl` alongside `config.kdl` and
  `dms/*.kdl`.
- The guided custom installer offers `niri-touchpad-toggle` as a `Mod+F8`
  personalization and writes an optional binding fragment only when selected.

- [x] Write failing importer/exporter tests using temporary HOME directories;
  assert the executable, the touchpad fragment, and the binding are present,
  while `myunix/kdeconnect.kdl` remains excluded.
- [x] Run the focused Niri+DMS test and confirm the new assertions fail.
- [x] Implement explicit helper installation and allowlisted touchpad-fragment
  import/export, then add the include and binding.
- [x] Run the focused test and validate the generated KDL with
  `niri validate -c modules/niri-dms/config/niri/config.kdl`.

### Task 3: Document and validate the migration path

**Files:**

- Modify: `docs/modules/niri-dms.md`
- Modify: `docs/obsidian/modules.md`
- Modify: `docs/obsidian/session.md`
- Modify: `README.md` if its module synopsis enumerates Niri/DMS behavior

- [x] Document the `Mod+F8` behavior, public state scope, default state,
  re-run/export workflow, and no-sudo boundary.
- [x] Run `bash tests/run.sh`, Bash syntax checks for all scripts, available
  ShellCheck, Niri validation, and `git diff --check`.
- [ ] Review the staged diff for secrets, then commit only this cohesive
  touchpad-toggle change with `feat: add managed Niri touchpad toggle`.
  Deferred: the working tree has earlier uncommitted user work interleaved in
  the same module files, so this task must not stage or commit those changes.
