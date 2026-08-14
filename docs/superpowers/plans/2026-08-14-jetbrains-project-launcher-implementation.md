# JetBrains Project Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a portable, dynamically discovered `jet` command that opens a directory with a selected JetBrains IDE and remembers the last IDE used per directory.

**Architecture:** The shared shell module owns both the `jet` function and its `jetcode` alias.  Every invocation discovers Toolbox and standard manual-install launchers, produces a deterministic menu, and stores just the selected launcher path in an XDG state file keyed by the resolved target directory.  Tests create temporary fake IDE launchers, so no real GUI is opened during verification.

**Tech Stack:** POSIX-oriented shell compatible with Bash and Zsh, `find`, `readlink`, `sort`, `awk`, `sha256sum`, existing Bash test harness.

## Global Constraints

- Use `$HOME`, XDG paths, and runtime discovery only; do not encode a user name, IDE version, or local installation path.
- Keep the command in `modules/shell-config/config/sysrc.d/functions.rc` and the entry alias in `aliases.rc`; do not create a standalone helper script.
- Discover newly added and removed IDE launchers on every `jet` call.
- Keep remembered selections under `${XDG_STATE_HOME:-$HOME/.local/state}/myunix/jetbrains/`, never in Git or export data.
- Preserve all unrelated dirty working-tree changes and stage only JetBrains-launcher files.

---

### Task 1: Add regression coverage for discovery and per-directory choice

**Files:**
- Create: `tests/test_jetbrains_launcher.sh`
- Consumes: `modules/shell-config/config/sysrc.d/functions.rc`
- Produces: executable behavioral coverage for dynamic launcher discovery and local state.

- [ ] **Step 1: Write the failing test**

Create `tests/test_jetbrains_launcher.sh` with a temporary `HOME`, a fake
Toolbox scripts directory containing executable `clion` and `pycharm`
launchers, and a fake project directory.  Each launcher appends its target
argument to `$JET_TEST_LOG`.  Source `functions.rc`, pipe `2` into
`jet "$project"`, wait for the background launcher, and assert that the log
contains the physical project path and the state file contains the PyCharm
launcher path.  Then pipe empty input into a second call and assert its output
contains `1. pycharm (last)` and it launches PyCharm again.

Add two negative paths: remove the remembered PyCharm launcher and prove that
blank input now fails without a launch; then pipe `9` and prove an invalid
selection fails without changing the state or launch log.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_jetbrains_launcher.sh`

Expected: non-zero exit because `jet` is not yet defined.

- [ ] **Step 3: Keep the failing test focused**

Use the existing `tests/test_helper.bash` helpers for command status and
output assertions.  Do not test real Toolbox, `~/.local/state`, or an actual
IDE process.

- [ ] **Step 4: Re-run the focused test**

Run: `bash tests/test_jetbrains_launcher.sh`

Expected: still non-zero until Task 2 supplies `jet`.

### Task 2: Implement the shared dynamic launcher

**Files:**
- Modify: `modules/shell-config/config/sysrc.d/functions.rc`
- Modify: `modules/shell-config/config/sysrc.d/aliases.rc`
- Test: `tests/test_jetbrains_launcher.sh`
- Consumes: command-line form `jet [DIRECTORY]` from the approved design.
- Produces: `jet` function and `jetcode` alias.

- [ ] **Step 1: Add portable helpers and `jet`**

Implement private `jet__*` helpers in `functions.rc` to:

1. Resolve the requested directory with `cd -P` and reject non-directories.
2. Collect executable Toolbox scripts from
   `${JETBRAINS_TOOLBOX_SCRIPTS:-$HOME/.local/share/JetBrains/Toolbox/scripts}`.
3. Collect executable `bin/*.sh` launchers under `$HOME/JetBrains`,
   `$HOME/.local/opt/jetbrains`, `/opt/jetbrains`, and `/opt/JetBrains`, plus
   colon-separated roots from `MYUNIX_JETBRAINS_PATHS`.  Do not recursively
   scan the Toolbox app tree because it contains internal helper scripts that
   are not project launchers.
4. Resolve and de-duplicate paths, then build a deterministic label/path menu
   without hardcoded product names.
5. Hash the physical target path to read/write one plain-text state file below
   `${XDG_STATE_HOME:-$HOME/.local/state}/myunix/jetbrains/last/`.
6. Move a still-discovered remembered launcher to menu item one, annotate it
   `(last)`, and use it for empty input.  Require a valid numeric choice when
   no valid last selection exists.
7. Start the selected launcher with the directory and record the launcher path
   only after the process has been successfully started.

Use temporary directories and a trap for internal menu files.  Keep file
formats line-oriented and avoid shell arrays so the same fragment can be
sourced by Bash and Zsh.

- [ ] **Step 2: Add the alias**

Add exactly this public alias to `aliases.rc` beneath its existing comment:

```sh
alias jetcode=jet
```

`jet` remains a function rather than an alias so it can parse its target and
interactive selection.

- [ ] **Step 3: Run focused tests to verify green**

Run: `bash tests/test_jetbrains_launcher.sh && bash tests/test_shell_config.sh`

Expected: both commands exit 0.  The launcher test proves menu order, blank
Enter behavior, stale-state fallback, invalid-input safety, and runtime
discovery.

- [ ] **Step 4: Commit the working feature slice**

```bash
git add modules/shell-config/config/sysrc.d/functions.rc \
  modules/shell-config/config/sysrc.d/aliases.rc \
  tests/test_jetbrains_launcher.sh
git commit -m "feat: add dynamic JetBrains project launcher"
```

### Task 3: Document, install, and verify the real shell integration

**Files:**
- Modify: `docs/modules/shell-config.md`
- Modify: `README.md` only if its shell-config summary needs the `jet` entry.
- Consumes: `jet` and `jetcode` from Task 2.
- Produces: user-facing instructions and installed local shared-shell files.

- [ ] **Step 1: Document usage and boundaries**

Add a concise `JetBrains project launcher` section to
`docs/modules/shell-config.md` with:

```text
jet .
jet ~/path/to/project
jetcode .
```

Explain dynamic discovery, `(last)` ordering, Enter behavior, the XDG local
state location, and optional `MYUNIX_JETBRAINS_PATHS`.  State that no project
or account data is exported.

- [ ] **Step 2: Install the reviewed shared-shell module for the desktop user**

Run: `./scripts/myunix install --module shell-config`

Expected: an idempotent source block is added to both `~/.bashrc` and
`~/.zshrc`, while `~/.config/.sysrc` and the three managed fragments are
copied from the reviewed module.  Existing shell-specific configuration is
preserved and backups go under `~/.local/state/myunix/backups/shell-config/`.

- [ ] **Step 3: Verify end-to-end discovery without opening a GUI**

Run a fresh Bash and Zsh that source `~/.config/.sysrc`, then verify `type
jet`, `alias jetcode`, and the detected local Toolbox launchers through a
non-launching helper/list path.  Confirm that none of the repository files
contain `/home/hiraeth` or a state selection.

- [ ] **Step 4: Run project-wide validation**

Run:

```bash
./tests/run.sh
find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n
command -v shellcheck >/dev/null && shellcheck $(find scripts modules tests -type f -name '*.sh' -print) || true
```

Expected: project tests and Bash syntax checks exit 0.  Report ShellCheck as
unavailable if it is not installed; do not hide a ShellCheck failure when it
is available.

- [ ] **Step 5: Secret review, commit, and push**

Stage only the documentation together with any uncommitted Task 2 files, use
`git diff --staged --check` and a credential-pattern scan, commit with a
descriptive message, then push `origin/fedora`.  Finally report fresh branch,
`git status --short`, test output, and the intentionally untouched unrelated
files.
