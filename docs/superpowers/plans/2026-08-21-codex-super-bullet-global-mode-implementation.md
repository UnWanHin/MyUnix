# Codex SuperBullet Global Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-level, globally discoverable Codex SuperBullet mode and keep its templates, installer, launcher, tests, and documentation synchronized in MyUnix.

**Architecture:** A dedicated `codex-super-bullet` module owns public templates for the global AGENTS policy, a profile layered on the existing Codex provider/auth, a concise skill, and a phase-aware `super-bullet` launcher. The installer writes to `${CODEX_HOME:-$HOME/.codex}` and `~/.local/bin`, preserving existing files in `~/.local/state/myunix/backups/`.

**Tech Stack:** Bash, TOML, Markdown, existing MyUnix test harness, Codex CLI `-p`, `exec`, and `review` commands.

## Global Constraints

- Never copy API keys, auth files, SSH keys, cookies, passwords, or browser data into Git.
- Use user-level paths derived from `$HOME` and `$CODEX_HOME`; do not hard-code `hiraeth`.
- Sol validation is read-only and must never auto-fix, delegate, browse broadly, or expand scope.
- Print SuperBullet markers only for phases actually run.
- Preserve the seven unrelated modified files already present in the worktree.
- Run the full test suite, `bash -n` for every shell script, and ShellCheck when available before committing.

---

### Task 1: Add failing contract tests

**Files:**
- Create: `tests/test_codex_super_bullet.sh`
- Test: `modules/codex-super-bullet/config/AGENTS.md`, `modules/codex-super-bullet/config/super-bullet.config.toml`, `modules/codex-super-bullet/bin/super-bullet`, `modules/codex-super-bullet/install.sh`

**Interfaces:**
- Tests consume installer helpers and a fake `codex` executable through `PATH`.
- Tests produce a temporary installed Codex home and launcher transcript.

- [ ] **Step 1: Write assertions for templates and launcher behavior.** Check Luna/max/multi-agent profile values, default-on and turn-level disable wording, truthful markers, no secret-like strings, `run`/`exec`/`review` command dispatch, Sol/high/read-only review flags, and no review after failed execution.
- [ ] **Step 2: Run the new test before creating module files.**

Run: `bash tests/test_codex_super_bullet.sh`

Expected: FAIL because the new module and templates do not yet exist.

### Task 2: Implement the isolated module and templates

**Files:**
- Create: `modules/codex-super-bullet/config/AGENTS.md`
- Create: `modules/codex-super-bullet/config/super-bullet.config.toml`
- Create: `modules/codex-super-bullet/config/skills/super-bullet/SKILL.md`
- Create: `modules/codex-super-bullet/bin/super-bullet`
- Create: `modules/codex-super-bullet/install.sh`

**Interfaces:**
- `install_codex_super_bullet` installs the four public artifacts idempotently.
- `super-bullet run`, `super-bullet exec <PROMPT...>`, and `super-bullet review` are the public launcher commands.

- [ ] **Step 1: Add the minimal phase-aware launcher.** Resolve `codex` from `MYUNIX_CODEX_BIN`/`PATH`; join all `exec` prompt words into one argument; use `-p super-bullet` for Luna; use Sol's read-only review with `gpt-5.6-sol`, high/max effort, and `--disable multi_agent`; review the exact pre-task `HEAD` range when Luna commits, otherwise review uncommitted changes; print markers only immediately before the invoked phase; preserve statuses.
- [ ] **Step 2: Add the profile and behavioral templates.** Keep provider/auth inheritance in the base config; document default-on, explicit turn disable, truthful markers, and Sol restrictions.
- [ ] **Step 3: Add an idempotent installer.** Copy templates to `${CODEX_HOME:-$HOME/.codex}` and `$HOME/.local/bin`, create backups under `${XDG_STATE_HOME:-$HOME/.local/state}/myunix/backups/codex-super-bullet/<timestamp>`, and never use `sudo`.
- [ ] **Step 4: Run the focused test.**

Run: `bash tests/test_codex_super_bullet.sh`

Expected: PASS.

### Task 3: Wire the module and document usage

**Files:**
- Modify: `scripts/myunix`
- Modify: `README.md`
- Create: `docs/modules/codex-super-bullet.md`
- Modify: `docs/obsidian/modules.md`
- Modify: `docs/obsidian/installation-map.md`

- [ ] **Step 1: Source the module and add `codex-super-bullet` to `run_module`.** Keep it explicit and isolated; do not add it to package manifests because it installs no RPM.
- [ ] **Step 2: Add CLI examples and explain global paths, launcher commands, exact-change review behavior, profile inheritance, and disable/re-enable phrases.**
- [ ] **Step 3: Run the focused test and the existing CLI tests.**

### Task 4: Install and verify the user runtime

**Files:**
- Runtime writes: `${CODEX_HOME:-$HOME/.codex}/AGENTS.md`, `${CODEX_HOME:-$HOME/.codex}/super-bullet.config.toml`, `${CODEX_HOME:-$HOME/.codex}/skills/super-bullet/SKILL.md`, `$HOME/.local/bin/super-bullet`

- [ ] **Step 1: Run `./scripts/myunix install --module codex-super-bullet` for the current user.**
- [ ] **Step 2: Verify `super-bullet --help`, `codex -p super-bullet --version`, and installed file ownership/modes without reading auth data.**
- [ ] **Step 3: Run `bash -n` over every repository shell script and ShellCheck when available.**

### Task 5: Review, commit, and push

- [ ] **Step 1: Inspect staged diff and scan for credential-like material.**
- [ ] **Step 2: Run `bash tests/run.sh` and record the result.**
- [ ] **Step 3: Commit only intended new/modified files with `feat: add global Codex SuperBullet mode`.**
- [ ] **Step 4: Push the verified commit to `origin/fedora`.**
- [ ] **Step 5: Report branch, `git status`, verification output, and intentionally untouched files.**
