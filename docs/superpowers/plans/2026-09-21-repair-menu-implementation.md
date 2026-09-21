# MyUnix Repair Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an interactive, categorized `myunix fix` command that diagnoses a selected repair before an explicit confirmation can make bounded, verified changes.

**Architecture:** `scripts/myunix` owns the command and menu navigation. A new `modules/fix/` library holds declarative repair registration plus category-scoped diagnose, repair, and verify functions that call existing module-owned helpers instead of duplicating installation logic. Tests use temporary homes and command stubs so diagnostics and declined confirmations are provably side-effect free.

**Tech Stack:** Bash 5, existing MyUnix shell libraries, Bats-style project shell tests, DNF/user systemd/Niri helpers already managed by MyUnix.

## Global Constraints

- `fix` requires an interactive terminal and has no automatic `--all` mode.
- Every repair must show read-only findings and a concrete plan before a `y/N` confirmation.
- Never inspect, copy, print, reset, or commit application logins, browser profiles, FlClash profiles/subscription URLs, SSH keys, tokens, passwords, or `~/.codex/auth.json`.
- Repairs may write only files/services already owned by their corresponding MyUnix module; backups remain below `~/.local/state/myunix/`.
- Keep existing `doctor`, `install`, `export`, `retry`, and `rollback` interfaces unchanged.
- Before every commit run affected tests, `bash -n` for edited shell scripts, `git diff --check`, and ShellCheck when installed.

---

### Task 1: Add repair framework and safe interactive dispatcher

**Files:**
- Create: `modules/fix/install.sh`
- Modify: `scripts/myunix:37-38, 307-334`
- Modify: `scripts/lib/ui.sh:1-145`
- Create: `tests/test_fix.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Produces `run_fix()`, `fix_choose_category()`, `fix_choose_repair()`, and `fix_run_selected <repair-id>` for the CLI.
- Produces `ui_confirm <prompt>` that prints no affirmative value until the user explicitly types `y` or `Y`.
- Consumes registered repair records through `fix_repair_ids`, `fix_repair_category`, `fix_repair_label`, `fix_diagnose_<id>`, `fix_plan_<id>`, `fix_apply_<id>`, and `fix_verify_<id>`.
- Later tasks register concrete repair IDs using the interface above.

- [ ] **Step 1: Write failing dispatcher tests**

Create `tests/test_fix.sh` with tests that source `scripts/myunix` under
`MYUNIX_SOURCE_ONLY=1`, stub the registration functions, and prove:

```bash
run env MYUNIX_UI_TEST_MODE=0 bash -c \
  "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/scripts/lib/ui.sh'; source '$PROJECT_ROOT/modules/fix/install.sh'; run_fix"
assert_status 2
assert_output_contains 'Interactive repair requires a terminal'

run env MYUNIX_FIX_TEST_CONFIRM=n bash -c \
  "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/scripts/lib/ui.sh'; source '$PROJECT_ROOT/modules/fix/install.sh'; fix_run_selected fixture; test ! -e '$temporary_dir/applied'"
assert_status 0
assert_output_contains 'cancelled'
```

Add an affirmative case that writes a temporary marker only after the test
confirmation is `y`, calls a verifier, and prints `repaired and verified`.

- [ ] **Step 2: Run the new test before implementation**

Run: `bash tests/test_fix.sh`

Expected: failure because `modules/fix/install.sh` and `run_fix` do not exist.

- [ ] **Step 3: Implement the minimal dispatcher**

Create `modules/fix/install.sh` with a small static category list and
registration helpers. Implement `run_fix` to call `ui_require_interactive`,
select category then repair, render the diagnostic and plan text, call
`ui_confirm`, then invoke only the selected repair and verifier. A clean
diagnostic must print `diagnosis clean; no change needed` and skip confirmation.

Add this helper to `scripts/lib/ui.sh`:

```bash
ui_confirm() {
  local prompt=$1 answer
  if [[ -n "${MYUNIX_FIX_TEST_CONFIRM:-}" ]]; then
    answer=$MYUNIX_FIX_TEST_CONFIRM
  else
    printf '%s [y/N] ' "$prompt" >&2
    IFS= read -r answer || return 1
  fi
  [[ "$answer" == y || "$answer" == Y ]]
}
```

Source the repair library in `scripts/myunix` and dispatch `fix` in the final
case statement. Preserve all existing command cases.

- [ ] **Step 4: Run focused tests and static validation**

Run:

```bash
bash tests/test_fix.sh
bash -n scripts/myunix scripts/lib/ui.sh modules/fix/install.sh tests/test_fix.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Commit the framework slice**

```bash
git add scripts/myunix scripts/lib/ui.sh modules/fix/install.sh tests/test_fix.sh tests/run.sh
git commit -m "feat: add interactive repair dispatcher"
```

### Task 2: Register desktop, input, network, and development repairs

**Files:**
- Modify: `modules/fix/install.sh`
- Modify: `tests/test_fix.sh`
- Modify: `docs/modules/input-method.md`
- Modify: `docs/modules/niri-dms.md`
- Modify: `docs/modules/jetbrains-toolbox.md`
- Modify: `docs/modules/portal-login.md`
- Modify: `docs/modules/codex-fedora.md`

**Interfaces:**
- Consumes Task 1 dispatcher contracts.
- Produces initial registrations: `wechat-cangjie`, `flclash-launcher`,
  `portal-login`, `codex-fedora`, and `development-toolchain`.
- Uses existing functions `install_input_methods`, `install_input_method_app_overrides`, `install_portal_login`, `install_codex_fedora`, and `install_development_toolchain`.

- [ ] **Step 1: Write failing scope and confirmation tests**

Extend `tests/test_fix.sh` with temporary-home tests that confirm the repair
registry includes all five IDs and that:

```bash
fix_diagnose_wechat_cangjie
test ! -e "$temporary_home/.config/fcitx5/profile"
test ! -e "$temporary_home/.local/share/applications/wechat.desktop"
```

Use stubs for DNF and installer functions. Assert the WeChat repair calls only
the input-method functions, the FlClash repair only creates/checks its desktop
launcher, and the Codex repair never reads `$HOME/.codex/auth.json`.

- [ ] **Step 2: Run the focused test before implementation**

Run: `bash tests/test_fix.sh`

Expected: failure because those registration IDs and functions are absent.

- [ ] **Step 3: Implement bounded repairs**

Add each repair as a category-owned set of four functions. Diagnostics use
`command -v`, `rpm -q`, `test -f`, and existing profile/launcher paths only.
Each plan text names exact actions and whether logout is required. Repairs reuse
the owning module function and do not scan private configuration directories.

For `flclash-launcher`, treat a working RPM and existing `.desktop` entry as
clean. If the desktop entry is missing, run only the managed RPM desktop
registration helper; never inspect `~/.config/FlClash`.

- [ ] **Step 4: Run tests and static validation**

Run:

```bash
bash tests/test_fix.sh
bash -n modules/fix/install.sh tests/test_fix.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Commit the repair records slice**

```bash
git add modules/fix/install.sh tests/test_fix.sh docs/modules
git commit -m "feat: add application repair records"
```

### Task 3: Register Niri + DMS session repairs

**Files:**
- Modify: `modules/fix/install.sh`
- Modify: `tests/test_fix.sh`
- Modify: `docs/modules/niri-dms.md`

**Interfaces:**
- Produces registrations: `niri-config`, `dms-service`, and `touchpad-toggle`.
- Consumes existing `configure_niri_dms_touchpad_toggle_binding`,
  `install_niri_dms_touchpad_toggle`, and `enable_dms_user_service` helpers.
- `niri-config` returns a non-clean diagnostic on invalid configuration but does
  not overwrite arbitrary user configuration; it repairs only missing
  MyUnix-owned fragments.

- [ ] **Step 1: Write failing Niri repair tests**

Add temporary-home tests that build a minimal Niri config including
`myunix/touchpad.kdl` and `myunix/touchpad-bind.kdl`. Assert:

```bash
fix_diagnose_touchpad_toggle
test ! -e "$temporary_home/.config/niri/myunix/touchpad-bind.kdl"
fix_apply_touchpad_toggle
test -s "$temporary_home/.config/niri/myunix/touchpad-bind.kdl"
```

Stub `niri` and `systemctl` to verify that the correct focused command is
called. Add a negative test proving an invalid user `config.kdl` is reported,
not replaced.

- [ ] **Step 2: Run the focused test before implementation**

Run: `bash tests/test_fix.sh`

Expected: failure because Niri repair records are absent.

- [ ] **Step 3: Implement Niri/DMS repairs**

`niri-config` runs `niri validate` when available and diagnoses missing public
fragments separately. `dms-service` checks `systemctl --user is-enabled` and
`is-active`, then invokes `enable_dms_user_service` plus a start only after
confirmation. `touchpad-toggle` checks the helper, include and binding; its
repair recreates only the helper/binding and asks Niri to reload when running.

- [ ] **Step 4: Run Niri-focused tests and validation**

Run:

```bash
bash tests/test_fix.sh
bash tests/test_niri_dms.sh
bash -n modules/fix/install.sh tests/test_fix.sh
```

Expected: every command exits 0.

- [ ] **Step 5: Commit the Niri repair slice**

```bash
git add modules/fix/install.sh tests/test_fix.sh docs/modules/niri-dms.md
git commit -m "feat: add Niri DMS repair records"
```

### Task 4: Finish CLI documentation and repository verification

**Files:**
- Modify: `README.md`
- Modify: `docs/obsidian/recovery.md`
- Modify: `docs/obsidian/modules.md`
- Modify: `tests/test_fix.sh`

**Interfaces:**
- Documents `./scripts/myunix fix` as an interactive, confirmation-gated repair
  flow distinct from installation and retry.
- Produces a complete command help/error message naming `fix`.

- [ ] **Step 1: Write failing documentation/interface tests**

Add assertions that `scripts/myunix` usage output contains `fix`, and that its
noninteractive invocation prints `Interactive repair requires a terminal`.

- [ ] **Step 2: Run the test before documentation/interface changes**

Run: `bash tests/test_fix.sh`

Expected: failure until the usage string and final CLI dispatch are complete.

- [ ] **Step 3: Update concise user documentation**

Add `./scripts/myunix fix` to README and recovery command examples. Explain the
category menu, diagnosis-before-confirmation behavior, and that it intentionally
does not restore FlClash subscriptions, account state, or secrets. Add the
repair ownership boundary to the Obsidian modules index.

- [ ] **Step 4: Run full verification**

Run:

```bash
bash tests/run.sh
find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 -r bash -n
git diff --check
if command -v shellcheck >/dev/null; then find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 shellcheck; fi
```

Expected: all commands exit 0. If ShellCheck is unavailable, record that fact
without claiming it ran.

- [ ] **Step 5: Review for secrets and commit**

Run:

```bash
git diff --cached | rg -i 'password|secret|token|api[_-]?key|subscription'
git add README.md docs/obsidian/recovery.md docs/obsidian/modules.md tests/test_fix.sh
git commit -m "docs: document interactive repair menu"
```

Expected: the staged diff contains documentation references to protected data
but no values, credentials, URLs, or authentication material.

- [ ] **Step 6: Push verified commits**

Run: `git push origin fedora`

Expected: remote accepts all repair-menu commits.
