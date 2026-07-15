# Shared Shell Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a MyUnix module that migrates portable Bash/Zsh shared configuration through `~/.config/.sysrc` and `~/.config/sysrc.d/`.

**Architecture:** `modules/shell-config/` owns exported public shared-shell files and source-marker management for `.bashrc` and `.zshrc`. Niri remains managed only by the Niri+DMS KDL module. Imports backup replaced managed files and edited rc files, never deleting unmanaged fragments.

**Tech Stack:** Bash, POSIX-compatible shell fragments, existing MyUnix shell-test harness.

## Global Constraints

- `~/.config/.sysrc` is the only shared entry point; it sources `env.rc`, `aliases.rc`, then `functions.rc` from `~/.config/sysrc.d/`.
- Shared fragments must be Bash/Zsh compatible and exclude secrets, keys, tokens, history, and machine-specific device paths.
- Niri must not source shell code and keeps its Wayland environment in KDL.
- No `sudo`; all changes are user-scoped, idempotent, and backup files go below `~/.local/state/myunix/backups/shell-config/`.
- Preserve unrelated worktree changes and do not push without explicit authorization.

---

### Task 1: Add tested shared config payload and importer

**Files:**

- Create: `modules/shell-config/config/.sysrc`
- Create: `modules/shell-config/config/sysrc.d/env.rc`
- Create: `modules/shell-config/config/sysrc.d/aliases.rc`
- Create: `modules/shell-config/config/sysrc.d/functions.rc`
- Create: `modules/shell-config/install.sh`
- Create: `tests/test_shell_config.sh`

**Interfaces:**

- Produces `install_shell_config()`, `import_shell_config()`, and `install_shell_rc_source <rc-file>`.
- Consumes `info()` in `scripts/lib/core.sh`.

- [ ] **Step 1: Write failing test for import, backup, and idempotent source blocks**

```bash
temporary_dir="$(mktemp -d)"
mkdir -p "$temporary_dir/home/.config/sysrc.d"
printf '%s\n' 'old sysrc' > "$temporary_dir/home/.config/.sysrc"
printf '%s\n' 'old bash' > "$temporary_dir/home/.bashrc"
printf '%s\n' 'old zsh' > "$temporary_dir/home/.zshrc"
run env HOME="$temporary_dir/home" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/shell-config/install.sh'; install_shell_config; install_shell_config"
assert_status 0
[[ "$(grep -c '^# >>> MyUnix shared shell configuration >>>$' "$temporary_dir/home/.bashrc")" == 1 ]]
[[ "$(grep -c '^# >>> MyUnix shared shell configuration >>>$' "$temporary_dir/home/.zshrc")" == 1 ]]
grep -Fq 'sysrc.d/env.rc' "$temporary_dir/home/.config/.sysrc"
find "$temporary_dir/home/.local/state/myunix/backups/shell-config" -name .sysrc -print -quit | grep -q .
```

- [ ] **Step 2: Run `bash tests/test_shell_config.sh`; confirm failure because installer is missing.**

- [ ] **Step 3: Create the initial payload.**

`.sysrc` must use this exact safe fixed-order logic rather than a glob:

```sh
# Shared Bash/Zsh entry point. Keep portable settings in sysrc.d/*.rc.
_sysrc_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}
for _sysrc_fragment in env.rc aliases.rc functions.rc; do
  _sysrc_path="$_sysrc_dir/sysrc.d/$_sysrc_fragment"
  [ -r "$_sysrc_path" ] && . "$_sysrc_path"
done
unset _sysrc_dir _sysrc_fragment _sysrc_path
```

The three `.rc` files initially contain category comments only.

- [ ] **Step 4: Implement `install.sh`.**

Implement `shell_config_dir`, `shell_config_target_dir`, `shell_config_backup_dir`, `import_shell_config`, `install_shell_rc_source`, and `install_shell_config`. Copy only `.sysrc` plus the three allowlisted fragments. Before each replacement, create one timestamped backup directory and copy the prior file. `install_shell_rc_source` removes any complete old marker block and appends exactly one block:

```sh
# >>> MyUnix shared shell configuration >>>
[ -r "$HOME/.config/.sysrc" ] && . "$HOME/.config/.sysrc"
# <<< MyUnix shared shell configuration <<<
```

It preserves all other rc-file content and creates a missing rc file safely.

- [ ] **Step 5: Run `bash tests/test_shell_config.sh && bash -n modules/shell-config/install.sh`; expect exit 0.**

- [ ] **Step 6: Commit the task.**

```bash
git add modules/shell-config/config modules/shell-config/install.sh tests/test_shell_config.sh
git commit -m "feat: add shared shell configuration installer"
```

### Task 2: Add export and CLI integration

**Files:**

- Create: `modules/shell-config/export.sh`
- Modify: `scripts/myunix`
- Modify: `tests/test_shell_config.sh`

**Interfaces:**

- Produces `export_shell_config()`.
- Consumes `install_shell_config()` from Task 1 and current CLI `run_module`/`run_export` conventions.

- [ ] **Step 1: Add failing test cases covering `export_shell_config` and `./scripts/myunix install --module shell-config`.** Use `MYUNIX_SHELL_CONFIG_SOURCE` to isolate the target; assert that `env.rc` exports but arbitrary `sysrc.d` files do not.

- [ ] **Step 2: Run `bash tests/test_shell_config.sh`; confirm export/CLI cases fail.**

- [ ] **Step 3: Implement exporter and CLI wiring.**

`export_shell_config` copies only existing `.sysrc`, `env.rc`, `aliases.rc`, and `functions.rc` from `${XDG_CONFIG_HOME:-$HOME/.config}` to `${MYUNIX_SHELL_CONFIG_SOURCE:-$(shell_config_dir)/config}`. Add installer/exporter source lines in `scripts/myunix`, add `shell-config) install_shell_config || status=1 ;;` to `run_module`, and call `export_shell_config` from `run_export` after `export_niri_dms`.

- [ ] **Step 4: Run `bash tests/test_shell_config.sh && bash tests/run.sh`; expect exit 0.**

- [ ] **Step 5: Commit the task.**

```bash
git add modules/shell-config/export.sh scripts/myunix tests/test_shell_config.sh
git commit -m "feat: export shared shell configuration"
```

### Task 3: Document and verify the module

**Files:**

- Create: `docs/modules/shell-config.md`
- Modify: `README.md`

**Interfaces:**

- Documents `./scripts/myunix install --module shell-config` and `./scripts/myunix export`.

- [ ] **Step 1: Document layout, category ownership, commands, backup location, idempotence, and recovery.** State explicitly that Niri KDL, keys/secrets, Oh My Zsh/P10k/NVM, and shell history are outside the shared exported files.

- [ ] **Step 2: Add the shell-config command to the README module list.**

- [ ] **Step 3: Verify all work.** Run `bash tests/run.sh`; run `bash -n` over every `*.sh` under `scripts` and `modules`; run ShellCheck if installed; run `git diff --check`, `git branch --show-current`, and `git status --short`. Expect tests, syntax, and diff check to exit 0; report branch/status without touching unrelated files.

- [ ] **Step 4: Commit the task.**

```bash
git add README.md docs/modules/shell-config.md docs/superpowers/specs/2026-07-15-shared-shell-config-design.md docs/superpowers/plans/2026-07-15-shared-shell-config-implementation.md
git commit -m "docs: document shared shell configuration"
```
