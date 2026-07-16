# DMS Personalization Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export and restore categorized, portable DMS personalization safely.

**Architecture:** The Niri+DMS module owns four allowlisted JSON category files. Bash delegates JSON extraction and shallow merges to `jq`, while backing up an existing DMS settings file before the first effective import change.

**Tech Stack:** Bash, jq, DMS JSON settings.

## Global Constraints

- Use explicit key allowlists; never export full `settings.json`.
- Do not synchronize devices, paths, commands, histories, plugins, tokens, or pairing state.
- Import must preserve unknown local DMS settings.
- Do not restart DMS automatically.

---

### Task 1: Add categorized export/import tests

**Files:**
- Modify: `tests/test_niri_dms.sh`
- Create: `modules/niri-dms/config/dms/`

- [ ] Write a temporary DMS settings fixture containing portable bar data and
excluded Wi-Fi/plugin/path data; assert export writes category files without
the excluded values, then assert import merges bar changes while preserving an
unknown local setting.

- [ ] Run `bash tests/test_niri_dms.sh` and confirm it fails before the new
functions exist.

### Task 2: Implement allowlisted category synchronization

**Files:**
- Modify: `modules/niri-dms/install.sh`, `modules/niri-dms/export.sh`
- Create: `modules/niri-dms/config/dms/bar.json`, `dock.json`,
  `appearance.json`, `frame.json`

- [ ] Implement category extraction with explicit jq key arrays.
- [ ] Implement shallow category merge with one backup per import.
- [ ] Run `bash tests/test_niri_dms.sh` and Bash syntax checks.

### Task 3: Export current public personalization and document boundaries

**Files:**
- Modify: `docs/modules/niri-dms.md`,
  `docs/superpowers/specs/2026-07-15-migration-graph-and-session-sync-design.md`

- [ ] Export the current four public category files.
- [ ] Document the category ownership and excluded state.
- [ ] Run focused tests, `git diff --check`, and review exported JSON for
private data before any commit.
