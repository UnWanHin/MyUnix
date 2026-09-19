# DMS Plugin and Zsh Personalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore public DMS presentation/plugins and reproducible Zsh personalization during one-click Fedora migration.

**Architecture:** Keep DMS JSON categories and plugin data separate from Niri KDL.  A focused Zsh module pins public repository revisions and writes only marker-delimited configuration, while `shell-config` remains shell-neutral.

**Tech Stack:** Bash, jq, git, Oh My Zsh, DMS CLI, existing MyUnix shell-test harness.

## Global Constraints

- Never commit secrets, tokens, cookies, SSH keys, Wi-Fi state, shell history, or paired device IDs.
- Keep every module user-scoped and idempotent; backups live only below `~/.local/state/myunix/`.
- Tests must use stubs rather than network access.
- `install --all` includes shared shell config and Zsh personalization.

---

### Task 1: Repair first-install DMS personalization

**Files:**
- Modify: `tests/test_niri_dms.sh`
- Modify: `modules/niri-dms/lib/personalization.sh`

- [ ] Add a fixture with no settings file and public bar category data.
- [ ] Verify it fails before the importer creates a minimal settings file.
- [ ] Create the parent directory and `{}` securely, then merge the public categories without creating a backup for an absent file.
- [ ] Run `bash tests/test_niri_dms.sh`.

### Task 2: Reproduce DMS plugin state safely

**Files:**
- Create: `modules/niri-dms/lib/plugins.sh`
- Create: `modules/niri-dms/config/dms/plugins.lock.json`
- Create: `modules/niri-dms/config/dms/plugin-settings.json`
- Modify: `modules/niri-dms/{install,export}.sh`, `tests/test_niri_dms.sh`

- [ ] Add tests for lock export/restore and `dankActions`-only settings merge.
- [ ] Add helpers which create/merge only the approved JSON object and restore the lock when present.
- [ ] Keep the ID manifest fallback for a repository without a lock.
- [ ] Run the focused test.

### Task 3: Add a reproducible Zsh module

**Files:**
- Create: `modules/zsh-personalization/{install,export}.sh`, `sources.tsv`, `config/*`
- Create: `tests/test_zsh_personalization.sh`
- Modify: `scripts/myunix`, `tests/test_install_flow.sh`

- [ ] Write isolated fake-git tests for pinned checkout requests and an idempotent `.zshrc` marker block.
- [ ] Install the four fixed source revisions into their standard Oh My Zsh locations and copy the reviewed P10k file with backups.
- [ ] Add module dispatch and one-click ordering after `shell-config`.
- [ ] Run module and installer-flow tests.

### Task 4: Document and verify

**Files:**
- Modify: `README.md`, `docs/modules/niri-dms.md`, `docs/modules/shell-config.md`, `docs/obsidian/{modules,installation-map}.md`
- Create: `docs/modules/zsh-personalization.md`

- [ ] Explain the public/private boundary and recovery behavior.
- [ ] Run the full tests, Bash syntax checks, `git diff --check`, ShellCheck when installed, and staged secret review.
- [ ] Commit focused changes and push `fedora`.
