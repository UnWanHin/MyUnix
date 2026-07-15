# Interactive Installer and Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a keyboard-driven one-click/custom installer, optional Cangjie/Pinyin selection, visible module status, network timeouts and retriable/skip-aware failures.

**Architecture:** `scripts/lib/ui.sh` owns terminal input and rendering; `scripts/lib/network.sh` owns only retryable network command execution. The input-method module resolves package groups and renders a Fcitx profile from selected capabilities. `scripts/myunix` orchestrates module progress and failure actions without making configuration writes retryable.

**Tech Stack:** Bash, ANSI TTY escape sequences, GNU `timeout`, DNF5, wget, Fcitx5.

## Global Constraints

- No `gum`, `fzf`, downloaded executable, account data or input-method text data.
- `./scripts/myunix install` is the interactive entry point; `--all` is one-click and `--guided` invokes custom input selection on a TTY.
- One-click always selects English, Cangjie and Pinyin; English is locked in custom mode.
- Greeter remains outside one-click/custom flow and retains its explicit replacement confirmation.
- Network retries wrap repository/download/package/plugin commands only, never configuration import or dconf/Fcitx writes.
- Default network attempts are 3; DNF/plugin timeout is 1800 seconds; direct-RPM download timeout is 600 seconds.
- Preserve local run state below `~/.local/state/myunix/` and never store it in Git.

---

### Task 1: Build dependency-free terminal selectors

**Files:**
- Create: `scripts/lib/ui.sh`
- Create: `tests/test_ui.sh`
- Modify: `scripts/myunix`

**Interfaces:**
- `ui_choose_one title option...` writes the selected zero-based index to stdout.
- `ui_choose_many title locked_csv option...` writes selected zero-based indices, one per line, to stdout.
- `ui_is_interactive` returns zero only for a real TTY.

- [ ] **Step 1: Write failing selector tests.** Stub `ui_read_key` to return `down`, `enter` for `ui_choose_one`, and `space`, `down`, `space`, `enter` for `ui_choose_many`. Assert the first sequence returns `1`; assert the second returns indices `0` and `1` when index `0` is locked.

- [ ] **Step 2: Run `bash tests/test_ui.sh`; verify failure because `scripts/lib/ui.sh` is absent.**

- [ ] **Step 3: Implement `scripts/lib/ui.sh`.** Use `read -rsn1` and parse escape sequences `ESC [ A` and `ESC [ B`; render `●` for selected and `○` for unselected entries. Space toggles only non-locked entries; Enter returns the current state; Ctrl-C returns non-zero. When stdout is not a TTY, return an explicit error rather than emitting raw escape control codes.

- [ ] **Step 4: Add the install-mode screen to `run_interactive_install`.** Render exactly `One-click installation` and `Custom installation`; dispatch one-click to `run_all_install` and custom to `run_custom_install`. Keep the old numeric menu removed from the interactive path.

- [ ] **Step 5: Run:**

```bash
bash tests/test_ui.sh
bash -n scripts/lib/ui.sh scripts/myunix
```

Expected: both exit 0.

### Task 2: Model Cangjie and Pinyin selections

**Files:**
- Create: `modules/input-method/packages.tsv`
- Modify: `modules/input-method/install.sh`
- Modify: `modules/input-method/packages.txt`
- Modify: `tests/test_input_method.sh`
- Modify: `docs/modules/input-method.md`

**Interfaces:**
- `input_method_resolve_packages cangjie pinyin` prints unique DNF packages.
- `input_method_render_fcitx_profile target cangjie pinyin` writes a profile containing `keyboard-us` plus selected Fcitx engines.
- `install_input_methods cangjie pinyin` installs resolved packages, backs up then writes the public Fcitx profile, and applies application launcher adapters.

- [ ] **Step 1: Write failing tests.** Assert `input_method_resolve_packages 1 0` includes `ibus-table-chinese-cangjie` and `fcitx5-table-extra`, but not `ibus-libpinyin`; assert `input_method_resolve_packages 0 1` includes `ibus-libpinyin` and `fcitx5-chinese-addons`; assert both selections deduplicate `fcitx5-chinese-addons`.

- [ ] **Step 2: Verify the installed Fcitx engine identifiers before implementation.** Run:

```bash
fcitx5-remote -l || true
rpm -ql fcitx5-chinese-addons | rg '/(pinyin|table).*\.conf|lib.*pinyin'
```

Use the actual configured Fcitx Pinyin engine ID in the profile renderer; do not guess it.

- [ ] **Step 3: Create `packages.tsv`** with group/package records for `base`, `cangjie`, and `pinyin`; base includes `ibus`, `fcitx5`, and `fcitx5-configtool`. Move the existing default package names out of `packages.txt`; remove `fcitx5-rime`, `fcitx5-mozc`, `rime`, `ibus-chewing` and any unused default engine from the one-click set.

- [ ] **Step 4: Implement resolver and profile rendering.** Read only valid group records, deduplicate with an associative array, and generate `keyboard-us` followed by selected engine entries. Preserve the existing backup path and launcher adapter behavior. Require at least one optional Chinese selection only for custom mode; one-click always supplies both.

- [ ] **Step 5: Run:**

```bash
bash tests/test_input_method.sh
bash -n modules/input-method/install.sh
```

Expected: both exit 0; profile tests prove English is present in every mode.

### Task 3: Connect custom input selection to installation modes

**Files:**
- Modify: `scripts/myunix`
- Modify: `tests/test_install_flow.sh`
- Modify: `tests/test_ui.sh`
- Modify: `README.md`
- Modify: `docs/modules/input-method.md`

**Interfaces:**
- `choose_custom_input_methods` exports `MYUNIX_INPUT_CANGJIE=0|1` and `MYUNIX_INPUT_PINYIN=0|1`.
- `run_all_install` sets both values to `1`.
- `run_custom_install` invokes only the input-method multi-select before executing the existing baseline module list.

- [ ] **Step 1: Write failing flow tests.** Source `scripts/myunix` with `MYUNIX_SOURCE_ONLY=1`, stub `ui_choose_many` to select Cangjie only, stub `run_module`, then assert the input-method invocation receives `MYUNIX_INPUT_CANGJIE=1` and `MYUNIX_INPUT_PINYIN=0`. Add a one-click test asserting both are `1`.

- [ ] **Step 2: Run `bash tests/test_install_flow.sh`; verify failure because the custom chooser is absent.**

- [ ] **Step 3: Implement selection hand-off.** `run_module input-method` calls `install_input_methods "${MYUNIX_INPUT_CANGJIE:-1}" "${MYUNIX_INPUT_PINYIN:-1}"`. `run_all_install` sets both values before running modules. `run_custom_install` calls the selector and then runs the same safe baseline list. `--guided` calls `run_custom_install`; `--module input-method` defaults both selections to `1` unless variables explicitly override them.

- [ ] **Step 4: Update README and input-method docs** with keyboard controls and examples:

```bash
MYUNIX_INPUT_CANGJIE=1 MYUNIX_INPUT_PINYIN=0 ./scripts/myunix install --module input-method
```

- [ ] **Step 5: Run:**

```bash
bash tests/test_install_flow.sh
bash tests/test_ui.sh
git diff --check
```

Expected: all exit 0.

### Task 4: Add network retry, timeout and status primitives

**Files:**
- Create: `scripts/lib/network.sh`
- Modify: `scripts/lib/state.sh`
- Modify: `modules/bootstrap/install.sh`
- Modify: `modules/dnf/install.sh`
- Modify: `modules/rpm/install.sh`
- Modify: `modules/niri-dms/install.sh`
- Modify: `modules/phone-connect/install.sh`
- Create: `tests/test_network.sh`
- Modify: `tests/test_rpm.sh`
- Modify: `tests/test_dnf.sh`

**Interfaces:**
- `network_run kind label command...` runs a command with the configured timeout and attempts, returns the final status, and prints `label — attempt N/M`.
- `network_timeout_seconds dnf|download` reads the documented environment overrides.
- `state_mark item deferred` records an interactive skip after retry exhaustion; `state_failed_items` includes both `failed` and `deferred` for later retry.

- [ ] **Step 1: Write failing network tests.** Stub `timeout` and a command that fails twice then succeeds; assert three attempts and final success. Stub a command that always fails; assert a final non-zero status after exactly `MYUNIX_NETWORK_ATTEMPTS` attempts. Assert `network_run download` passes `MYUNIX_DOWNLOAD_TIMEOUT_SECONDS` and `network_run dnf` passes `MYUNIX_DNF_TIMEOUT_SECONDS` to `timeout --foreground`.

- [ ] **Step 2: Run `bash tests/test_network.sh`; verify failure because `network.sh` is absent.**

- [ ] **Step 3: Implement `network.sh`.** Validate integer environment values; use `timeout --foreground "${seconds}s"`; wait 2, then 4 seconds between attempts; print a status line before every attempt; never use `eval`.

- [ ] **Step 4: Route only network calls through the wrapper.** Wrap RPM Fusion DNF operations, DNF manifest installs, optional DNF package installs, wget, DNF RPM installation, COPR enables, DMS plugin installation and KDE Connect Nautilus package installation. Leave configuration import, profile rendering, firewall operations and verification commands unwrapped.

- [ ] **Step 5: Extend state and tests.** Allow `deferred` in `state_mark`; make `state_failed_items` return `failed` and `deferred`; add an assertion to `tests/test_state.sh` proving deferred modules are selected by retry.

- [ ] **Step 6: Run:**

```bash
bash tests/test_network.sh
bash tests/test_rpm.sh
bash tests/test_dnf.sh
bash tests/test_state.sh
find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 bash -n
```

Expected: all exit 0.

### Task 5: Show module progress and allow interactive failure actions

**Files:**
- Modify: `scripts/myunix`
- Modify: `scripts/lib/ui.sh`
- Modify: `tests/test_install_flow.sh`
- Modify: `docs/verification/fedora-smoke-test.md`
- Modify: `README.md`

**Interfaces:**
- `run_selected_modules module...` prints `[current/total] module`, measures elapsed seconds, and returns non-zero when any module fails or is deferred.
- `ui_choose_failure_action module` returns `retry`, `skip`, or `stop`.

- [ ] **Step 1: Write failing orchestration tests.** Stub `run_module` so the first invocation fails and the second succeeds; stub `ui_choose_failure_action` to return `retry`; assert one module is retried and output includes `[1/2]`. Repeat with `skip`; assert `state_mark "module:<name>" deferred` is called and the next independent module runs. Repeat with `stop`; assert remaining modules do not run.

- [ ] **Step 2: Run `bash tests/test_install_flow.sh`; verify the new progress/failure assertions fail.**

- [ ] **Step 3: Implement progress and action handling.** `run_selected_modules` loops with total/current counters and `SECONDS`; on a failure in an interactive session, call the three-action selector. Retry re-runs only the current module; skip marks it `deferred` and continues; stop returns immediately. In non-interactive mode, do not prompt: retain failure state, continue independent modules, then return non-zero.

- [ ] **Step 4: Update user documentation.** Explain module status lines, download attempt status, retry, deferred modules and the timeout override variables. Update the Fedora smoke checklist to exercise retry and skip independently.

- [ ] **Step 5: Run the full verification:**

```bash
bash tests/run.sh
find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 bash -n
command -v shellcheck >/dev/null && find scripts modules tests -type f -name '*.sh' -print0 | xargs -0 shellcheck -S warning || true
git diff --check
```

Expected: tests, syntax checks and diff check exit 0. Record an unavailable ShellCheck rather than treating its absence as a pass.

- [ ] **Step 6: Commit and push after staged secret review:**

```bash
git add scripts modules tests README.md docs
git diff --cached --check
git commit -m "feat: add resilient interactive installer"
git push origin fedora
```
