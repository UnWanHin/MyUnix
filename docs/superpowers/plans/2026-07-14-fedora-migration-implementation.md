# Fedora GNOME Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a safe, modular Bash tool that exports and restores a Fedora GNOME workstation, including package sources, optional applications, GNOME shortcuts, and public input-method configuration.

**Architecture:** `scripts/myunix` is the stable CLI and delegates to small module scripts. Shared Bash helpers handle errors, prompts, state and manifest parsing; system modules use narrowly scoped `sudo`, while GNOME and input-method settings always run as the desktop user. Version-controlled manifests describe packages and RPM sources; local state and backups stay below the user's home directory.

**Tech Stack:** Bash, DNF, wget, sha256sum, dconf/gsettings, RPM Fusion release RPMs, ShellCheck, Bash test harness.

## Global Constraints

- Support Fedora Workstation GNOME only; refuse other operating systems before changing state.
- Never commit or export SSH keys, credentials, tokens, browser profiles, or downloaded RPM binaries.
- Direct RPMs require HTTPS, a pinned SHA-256 checksum and temporary-download cleanup.
- Only package/repository work uses `sudo`; GNOME and input-method configuration is user-level.
- All installer modules are idempotent, and retry state is stored only in `~/.local/state/myunix/`.
- Keep source manifests, documentation and verification instructions synchronized with every managed application.

---

### Task 1: Establish the executable layout and test harness

**Files:**
- Create: `scripts/myunix`
- Create: `scripts/lib/core.sh`
- Create: `tests/test_helper.bash`
- Create: `tests/run.sh`
- Create: `.gitignore`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces `main "$@"` in `scripts/myunix` and reusable `die`, `info`, `require_command`, `is_fedora`, `state_dir` functions in `scripts/lib/core.sh`.
- Tests invoke scripts with `MYUNIX_ROOT`, `MYUNIX_STATE_DIR`, `PATH`, and `MYUNIX_TEST_MODE` overrides.

- [ ] **Step 1: Write the failing CLI-environment test**

```bash
# tests/test_cli.sh
source "$(dirname "$0")/test_helper.bash"
run "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 2
assert_output_contains 'Fedora is required'
```

- [ ] **Step 2: Run it to prove the initial failure**

Run: `bash tests/test_cli.sh`

Expected: failure because `scripts/myunix` does not exist.

- [ ] **Step 3: Implement the minimum shared layer and doctor command**

```bash
# scripts/lib/core.sh
#!/usr/bin/env bash
set -Eeuo pipefail

readonly MYUNIX_ROOT="${MYUNIX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
state_dir() { printf '%s\n' "${MYUNIX_STATE_DIR:-$HOME/.local/state/myunix}"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
info() { printf '%s\n' "$*"; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
is_fedora() { [[ -r /etc/fedora-release ]] || [[ "${MYUNIX_TEST_MODE:-}" == 'fedora' ]]; }
```

```bash
# scripts/myunix
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/core.sh"
case "${1:-}" in
  doctor) is_fedora || die 'Fedora is required'; info 'Fedora environment verified' ;;
  *) die 'Usage: myunix {doctor|install|export|retry}' ;;
esac
```

- [ ] **Step 4: Add ignored local state and clarify AGENTS scope**

```gitignore
.myunix-test-state/
*.rpm
```

Add to `AGENTS.md`: repo-local instructions govern work in this repository; global defaults belong in `~/.codex/AGENTS.md`; neither file provides background monitoring.

- [ ] **Step 5: Run validation and commit**

Run: `bash tests/run.sh && bash -n scripts/myunix scripts/lib/core.sh`

Expected: all tests pass and syntax validation emits no output.

```bash
git add .gitignore AGENTS.md scripts tests
git commit -m 'feat: add Fedora CLI foundation'
```

### Task 2: Implement manifest validation and local run state

**Files:**
- Create: `scripts/lib/manifest.sh`
- Create: `scripts/lib/state.sh`
- Create: `tests/test_manifest.sh`
- Create: `tests/test_state.sh`

**Interfaces:**
- `validate_dnf_manifest path`, `validate_rpm_manifest path`, and `read_rpm_manifest path` reject comments/blank lines safely and reject malformed records.
- `state_mark item status`, `state_failed_items`, and `state_reset` use `$(state_dir)/runs.tsv`.

- [ ] **Step 1: Write failing tests for invalid RPM fields and retries**

```bash
printf 'qq|QQ|https://example.test/qq.rpm|bad|optional|rpm -q qq\n' > "$TMP/rpm.tsv"
run validate_rpm_manifest "$TMP/rpm.tsv"
assert_status 1

state_mark 'rpm:qq' failed
state_mark 'dnf:git' succeeded
assert_equals 'rpm:qq' "$(state_failed_items)"
```

- [ ] **Step 2: Run the tests and observe failure**

Run: `bash tests/test_manifest.sh && bash tests/test_state.sh`

Expected: failure because shared manifest/state functions do not exist.

- [ ] **Step 3: Implement TSV and state helpers**

```bash
validate_rpm_manifest() {
  local file=$1 id name url checksum selection verify extra
  while IFS='|' read -r id name url checksum selection verify extra; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    [[ -z "$name" || -n "$extra" || ! "$url" =~ ^https:// || ! "$checksum" =~ ^[[:xdigit:]]{64}$ ]] && return 1
    [[ "$selection" == default || "$selection" == optional ]] || return 1
  done < "$file"
}
state_mark() { mkdir -p "$(state_dir)"; printf '%s|%s\n' "$1" "$2" >> "$(state_dir)/runs.tsv"; }
state_failed_items() { awk -F'|' '$2 == "failed" { last[$1]=$2 } END { for (item in last) print item }' "$(state_dir)/runs.tsv" 2>/dev/null | sort; }
```

- [ ] **Step 4: Make state writes atomic and test duplicate items**

Rewrite `state_mark` to write a replacement file via `mktemp`, retaining one latest status per item, then `mv` it into place. Add a test that a later `succeeded` mark removes a prior item from `state_failed_items`.

- [ ] **Step 5: Validate and commit**

Run: `bash tests/run.sh && shellcheck scripts/lib/*.sh`

Expected: all manifest and state tests pass.

```bash
git add scripts/lib tests
git commit -m 'feat: validate manifests and preserve retry state'
```

### Task 3: Add Fedora bootstrap and DNF package modules

**Files:**
- Create: `modules/bootstrap/install.sh`
- Create: `modules/dnf/core.txt`
- Create: `modules/dnf/optional.txt`
- Create: `modules/dnf/install.sh`
- Create: `tests/test_bootstrap.sh`
- Create: `tests/test_dnf.sh`
- Create: `docs/modules/bootstrap.md`
- Create: `docs/modules/dnf.md`

**Interfaces:**
- `install_bootstrap` configures RPM Fusion only after Fedora validation.
- `install_dnf_manifest path` installs non-comment package lines with `sudo dnf install -y` and records each result.

- [ ] **Step 1: Write command-recording tests**

```bash
run install_bootstrap
assert_output_contains 'dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-'
assert_output_contains 'rpmfusion-nonfree-release-'

run install_dnf_manifest "$FIXTURES/dnf.txt"
assert_output_contains 'dnf install -y git wget'
```

- [ ] **Step 2: Run tests in fake-Fedora mode**

Run: `MYUNIX_TEST_MODE=fedora PATH="$TEST_BIN:$PATH" bash tests/test_bootstrap.sh`

Expected: failure because module scripts do not exist.

- [ ] **Step 3: Implement the modules using documented RPM Fusion release URLs**

```bash
install_bootstrap() {
  is_fedora || die 'Fedora is required'
  local version
  version="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${version}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${version}.noarch.rpm"
  sudo dnf makecache
}
```

Use `mapfile` to read only nonempty, noncomment DNF package entries and pass the resulting array as quoted arguments to one DNF invocation. Do not use `eval`.

- [ ] **Step 4: Document package ownership and optional policy**

List the RPM Fusion source and Fedora-version evaluation in `docs/modules/bootstrap.md`; document that core packages are installed by `--all` while optional packages are chosen only in guided mode.

- [ ] **Step 5: Validate and commit**

Run: `bash tests/run.sh && bash -n modules/bootstrap/install.sh modules/dnf/install.sh`

Expected: fake command assertions and syntax checks pass.

```bash
git add modules tests docs/modules
git commit -m 'feat: add RPM Fusion and DNF modules'
```

### Task 4: Add verified direct-RPM support and application prompts

**Files:**
- Create: `modules/rpm/apps.tsv`
- Create: `modules/rpm/install.sh`
- Create: `tests/test_rpm.sh`
- Create: `docs/modules/rpm.md`

**Interfaces:**
- `install_rpm_record id name url sha256 selection verify_command verify_argument` downloads to a `mktemp -d` directory, verifies the checksum, installs with DNF, deletes the directory, then executes a fixed command and separately parsed argument.
- `prompt_optional_app id name` returns success only for an explicit yes answer.

- [ ] **Step 1: Write checksum and cleanup failure tests**

```bash
run install_rpm_record qq QQ https://example.test/qq.rpm "$KNOWN_SHA" optional rpm qq
assert_status 0
assert_file_not_exists "$LAST_TEMP_DIR"

run install_rpm_record qq QQ https://example.test/qq.rpm "${KNOWN_SHA/a/b}" optional rpm qq
assert_status 1
assert_output_contains 'Checksum mismatch for QQ'
assert_file_not_exists "$LAST_TEMP_DIR"
```

- [ ] **Step 2: Prove tests fail before implementation**

Run: `bash tests/test_rpm.sh`

Expected: failure because RPM installation helpers do not exist.

- [ ] **Step 3: Implement safe download and install**

```bash
install_rpm_record() {
  local id=$1 name=$2 url=$3 sha=$4 selection=$5 verify_command=$6 verify_argument=$7 tmp actual
  tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' RETURN
  wget --https-only --quiet --show-progress -O "$tmp/$id.rpm" "$url"
  actual="$(sha256sum "$tmp/$id.rpm" | awk '{print $1}')"
  [[ "$actual" == "$sha" ]] || { printf 'Checksum mismatch for %s\n' "$name" >&2; return 1; }
  sudo dnf install -y "$tmp/$id.rpm"
  command -v "$verify_command" >/dev/null && "$verify_command" "$verify_argument"
}
```

Define the seven-column `apps.tsv` format in `docs/modules/rpm.md`; its verifier fields must be a command name and one package argument. Never evaluate manifest text as shell code.

- [ ] **Step 4: Add QQ and WeChat only after source verification**

Research each current official Linux RPM source, checksum publication, package name and license. Populate `apps.tsv` only when all four are available; otherwise leave the item documented as unavailable rather than using an unverified third-party URL.

- [ ] **Step 5: Validate and commit**

Run: `bash tests/run.sh && shellcheck modules/rpm/install.sh`

Expected: checksum mismatch is rejected, temporary files are removed, and tests never run real DNF.

```bash
git add modules/rpm tests docs/modules
git commit -m 'feat: add verified RPM application installer'
```

### Task 5: Add scoped GNOME and input-method export/import modules

**Files:**
- Create: `modules/gnome/export.sh`
- Create: `modules/gnome/install.sh`
- Create: `modules/gnome/dconf/media-keys.ini`
- Create: `modules/input-method/packages.txt`
- Create: `modules/input-method/export.sh`
- Create: `modules/input-method/install.sh`
- Create: `tests/test_gnome.sh`
- Create: `tests/test_input_method.sh`
- Create: `docs/modules/gnome.md`
- Create: `docs/modules/input-method.md`

**Interfaces:**
- `export_gnome` writes only scoped media-key paths and `import_gnome` backs them up before `dconf load`.
- `export_input_methods` and `import_input_methods` manage only reviewed Fcitx5/IBus public configuration directories.

- [ ] **Step 1: Write failing no-sudo and scoped-path tests**

```bash
run import_gnome
assert_status 0
assert_output_not_contains 'sudo dconf'
assert_output_contains '/org/gnome/settings-daemon/plugins/media-keys/'
assert_file_exists "$BACKUP_DIR/media-keys.ini"
```

- [ ] **Step 2: Run with dconf and sudo fakes**

Run: `PATH="$TEST_BIN:$PATH" HOME="$TMP/home" bash tests/test_gnome.sh`

Expected: failure because GNOME functions do not exist.

- [ ] **Step 3: Implement scoped export/import**

```bash
readonly GNOME_MEDIA_KEYS='/org/gnome/settings-daemon/plugins/media-keys/'
export_gnome() { dconf dump "$GNOME_MEDIA_KEYS" > "$MODULE_DIR/dconf/media-keys.ini"; }
import_gnome() {
  local backup="$HOME/.local/state/myunix/backups/gnome-$(date +%Y%m%d-%H%M%S).ini"
  mkdir -p "$(dirname "$backup")"
  dconf dump "$GNOME_MEDIA_KEYS" > "$backup"
  dconf load "$GNOME_MEDIA_KEYS" < "$MODULE_DIR/dconf/media-keys.ini"
}
```

Treat an empty export as a valid no-custom-hotkeys state. Copy only configured Fcitx5/IBus files from explicit allowlisted paths; reject symlinks that resolve outside `$HOME/.config`.

- [ ] **Step 4: Wire input-method packages and restart guidance**

Maintain the IBus/Fcitx5/Rime/Mozc package list in `modules/input-method/packages.txt`, invoke the DNF manifest helper, and print an explicit logout/login notice after successful import.

- [ ] **Step 5: Validate and commit**

Run: `bash tests/run.sh && bash -n modules/gnome/*.sh modules/input-method/*.sh`

Expected: fake dconf asserts user-level execution, backups, and allowlisted copies.

```bash
git add modules/gnome modules/input-method tests docs/modules
git commit -m 'feat: migrate GNOME hotkeys and input methods'
```

### Task 6: Complete the interactive orchestration, retries, export, and documentation

**Files:**
- Modify: `scripts/myunix`
- Create: `scripts/lib/prompts.sh`
- Create: `modules/export/install.sh`
- Create: `tests/test_install_flow.sh`
- Create: `README.md`
- Create: `docs/modules/export.md`

**Interfaces:**
- `choose_install_mode`, `choose_modules`, `run_selected_modules`, and `retry_failed_modules` comprise the CLI flow.
- `./scripts/myunix install [--all|--guided|--module NAME]`, `export`, `retry`, and `doctor` are the published commands.

- [ ] **Step 1: Write failing interactive-flow tests**

```bash
printf '2\ny\nn\n' | run "$PROJECT_ROOT/scripts/myunix" install --guided
assert_output_contains 'Install QQ? [y/N]'
assert_output_contains 'Skip WeChat'
assert_output_contains 'Installation summary'
```

- [ ] **Step 2: Run flow tests before wiring modules**

Run: `MYUNIX_TEST_MODE=fedora PATH="$TEST_BIN:$PATH" bash tests/test_install_flow.sh`

Expected: failure because `install` has not been implemented.

- [ ] **Step 3: Implement deterministic command parsing and menu behavior**

```bash
case "$command" in
  install) run_install "$@" ;;
  export) run_export ;;
  retry) retry_failed_modules ;;
  doctor) run_doctor ;;
  *) die 'Usage: myunix {install|export|retry|doctor}' ;;
esac
```

`install` without flags requires a TTY and renders the four numbered choices. `--all` selects bootstrap, core DNF, default RPM items, GNOME and input methods without prompts. `--guided` prompts module-by-module and application-by-application. Any module failure is recorded; unaffected selections continue and a final table lists succeeded, skipped and failed work.

- [ ] **Step 4: Implement export and user documentation**

The export module invokes GNOME/input-method exports and uses `dnf repoquery --userinstalled` to write a reviewable candidate file under `modules/dnf/exported-userinstalled.txt`. README documents: cloning, inspecting manifests, `doctor`, export on the old machine, guided/all restore on the new one, retry, required logout, how to update RPM checksums, and the explicit exclusion of secrets.

- [ ] **Step 5: Validate end-to-end and commit**

Run: `bash tests/run.sh && find scripts modules -type f -name '*.sh' -exec bash -n {} + && shellcheck scripts/myunix scripts/lib/*.sh modules/*/*.sh`

Expected: all fake-Fedora unit/flow tests pass, no Bash syntax errors, and ShellCheck reports no warnings.

```bash
git add scripts modules tests README.md docs
git commit -m 'feat: add guided Fedora migration workflow'
```

### Task 7: Perform a final Fedora smoke test and release-ready review

**Files:**
- Modify: `README.md`
- Modify: `docs/modules/*.md`
- Create: `docs/verification/fedora-smoke-test.md`

**Interfaces:**
- The documented smoke test is reproducible on a clean Fedora GNOME virtual machine.

- [ ] **Step 1: Write the smoke-test checklist before running it**

Include commands to validate `doctor`, no-op DNF re-run, RPM checksum rejection, guided QQ/WeChat skip behavior, GNOME backup creation, retry-state recovery and clean Git status.

- [ ] **Step 2: Run the safe checks in the current environment**

Run: `bash tests/run.sh && find scripts modules -type f -name '*.sh' -exec bash -n {} +`

Expected: passing tests and zero syntax failures.

- [ ] **Step 3: Run in Fedora GNOME before real package installation**

Run: `./scripts/myunix doctor && ./scripts/myunix install --guided`

Expected: Fedora and GNOME requirements are reported; every change remains opt-in in guided mode.

- [ ] **Step 4: Capture results and commit**

Record Fedora release, desktop session, test results, skipped optional apps and any manual logout requirement in `docs/verification/fedora-smoke-test.md`.

```bash
git add README.md docs
git commit -m 'docs: record Fedora migration verification'
```
