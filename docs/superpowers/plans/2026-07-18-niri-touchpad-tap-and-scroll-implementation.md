# Niri Touchpad Tap And Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tap-to-click and reverse touchpad scrolling persist across `Mod+F8` toggles in Niri.

**Architecture:** The MyUnix touchpad fragment becomes the sole persistent owner of enabled touchpad preferences. The toggle helper writes either the complete enabled fragment (`tap`) or the disabled fragment (`off`), then asks Niri to reload. The base Niri template no longer duplicates input preferences that a later include can supersede.

**Tech Stack:** Bash, KDL, Niri 26.04, Bats test suite.

## Global Constraints

- Keep the `Mod+F8` binding in DMS's managed binds file.
- The enabled touchpad fragment must contain `tap` and `natural-scroll`.
- The disabled touchpad fragment must contain only the `off` touchpad state.
- Do not change mouse, trackpoint, kernel, driver, or libinput package settings.
- Keep all paths user-relative through `$HOME` or XDG variables; do not hardcode a username.

---

### Task 1: Prove and preserve toggle fragment behavior

**Files:**
- Modify: `tests/test_niri_dms.sh`
- Modify: `modules/niri-dms/bin/niri-touchpad-toggle`

**Interfaces:**
- Consumes: `MYUNIX_NIRI_TOUCHPAD_STATE_FILE` and `MYUNIX_NIRI_TOUCHPAD_SKIP_RELOAD`.
- Produces: an enabled fragment containing `tap`, or a disabled fragment containing `off`.

- [ ] **Step 1: Add assertions for the enabled fragment before changing the helper**

Keep the existing first execution assertion for `off`. Extend the test after
its second execution, which returns the state to enabled:

```bash
run grep -Fx '        tap' "$touchpad_state"
assert_status 1
```

Expected: the test fails because the current enabled fragment is empty.

- [ ] **Step 2: Run the focused test and confirm the regression**

Run:

```bash
bats tests/test_niri_dms.sh
```

Expected: failure from the new `tap` assertion only.

- [ ] **Step 3: Make the helper write an explicit enabled fragment**

Replace the enabled branch emitted lines with:

```bash
'input {' \
'    touchpad {' \
'        tap' \
'        natural-scroll' \
'    }' \
'}' > "$temporary"
```

Keep the disabled branch unchanged so it writes `off` only.

- [ ] **Step 4: Assert both toggle states**

After the first execution, assert `off` exists and `tap` does not. After the
second execution, assert both `tap` and `natural-scroll` exist:

```bash
run grep -Fx '        off' "$touchpad_state"
assert_status 0
run grep -F '        tap' "$touchpad_state"
assert_status 1

run "$temporary_touchpad/niri-touchpad-toggle"
assert_status 0
run grep -Fx '        tap' "$touchpad_state"
assert_status 0
run grep -Fx '        natural-scroll' "$touchpad_state"
assert_status 0
```

- [ ] **Step 5: Run the focused test and commit the helper change**

Run:

```bash
bats tests/test_niri_dms.sh
git add modules/niri-dms/bin/niri-touchpad-toggle tests/test_niri_dms.sh
git commit -m "fix: preserve Niri touchpad tap across toggles"
```

Expected: all Niri-DMS tests pass.

### Task 2: Move persistent preferences to the MyUnix fragment

**Files:**
- Modify: `modules/niri-dms/config/niri/config.kdl`
- Modify: `modules/niri-dms/config/niri/myunix/touchpad.kdl`
- Modify outside Git: `$XDG_CONFIG_HOME/niri/config.kdl`
- Modify outside Git: `$XDG_CONFIG_HOME/niri/myunix/touchpad.kdl`

**Interfaces:**
- Consumes: Niri's `input { touchpad { ... } }` KDL section.
- Produces: a default enabled fragment that has `tap` and reverse scrolling.

- [ ] **Step 1: Add a template assertion for the desired state**

Add to `tests/test_niri_dms.sh`:

```bash
run grep -Fx '        tap' "$PROJECT_ROOT/modules/niri-dms/config/niri/myunix/touchpad.kdl"
assert_status 1
```

Expected: failure because the template currently has only a comment.

- [ ] **Step 2: Move `tap` to the MyUnix-owned fragment**

Set `modules/niri-dms/config/niri/myunix/touchpad.kdl` to:

```kdl
// This file is owned by MyUnix and toggled by niri-touchpad-toggle.
input {
    touchpad {
        tap
        natural-scroll
    }
}
```

In `modules/niri-dms/config/niri/config.kdl`, remove both `tap` and
`natural-scroll` from its base `touchpad` section. Add both settings only to
the MyUnix-owned fragment.

- [ ] **Step 3: Apply the same validated fragments to the active session**

Copy the two updated template files to `$XDG_CONFIG_HOME/niri/`, preserving
the existing DMS fragments. Run:

```bash
niri validate
niri msg action load-config-file
```

Expected: `config is valid`; Niri reloads without an error.

- [ ] **Step 4: Run the focused test and commit the template change**

Run:

```bash
bats tests/test_niri_dms.sh
git add modules/niri-dms/config/niri/config.kdl modules/niri-dms/config/niri/myunix/touchpad.kdl tests/test_niri_dms.sh
git commit -m "feat: set persistent Niri tap and reverse scrolling"
```

Expected: all Niri-DMS tests pass.

### Task 3: Validate the module and record user-facing behavior

**Files:**
- Modify: `docs/modules/niri-dms.md` if that module document exists; otherwise `README.md`
- Modify outside Git: `$HOME/.local/bin/niri-touchpad-toggle`

**Interfaces:**
- Consumes: the installed helper and active Niri configuration.
- Produces: documented `Mod+F8` behavior with persistent tap-to-click.

- [ ] **Step 1: Synchronize the installed toggle helper**

Run the module's helper installation function or copy only
`modules/niri-dms/bin/niri-touchpad-toggle` to `$HOME/.local/bin/niri-touchpad-toggle`
with mode `0755`. Do not re-run package installation.

- [ ] **Step 2: Validate the session configuration and helper output**

Run:

```bash
niri validate
MYUNIX_NIRI_TOUCHPAD_SKIP_RELOAD=1 "$HOME/.local/bin/niri-touchpad-toggle"
grep -Fx '        off' "$XDG_CONFIG_HOME/niri/myunix/touchpad.kdl"
MYUNIX_NIRI_TOUCHPAD_SKIP_RELOAD=1 "$HOME/.local/bin/niri-touchpad-toggle"
grep -Fx '        tap' "$XDG_CONFIG_HOME/niri/myunix/touchpad.kdl"
niri msg action load-config-file
```

Expected: each command exits successfully and the final active fragment
contains `tap`.

- [ ] **Step 3: Document the user-visible behavior**

State that `Mod+F8` toggles only the touchpad enabled state, a one-finger tap
is a left click when enabled, and two-finger scroll uses the reverse direction.
Do not document user-specific device names.

- [ ] **Step 4: Run complete validation, export, and commit**

Run:

```bash
./tests/run.sh
find scripts modules -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n
command -v shellcheck >/dev/null && find scripts modules -type f -name '*.sh' -print0 | xargs -0 -r shellcheck || true
./scripts/myunix export --module niri-dms
git add README.md docs modules tests
git diff --staged --check
git diff --staged | rg -i 'password|secret|api[_-]?key|token|private.?key' && exit 1 || true
git commit -m "docs: document persistent Niri touchpad controls"
git push origin fedora
```

Expected: tests and syntax checks pass, exported module captures the portable
configuration, no secret scan matches, and `origin/fedora` accepts the commits.
