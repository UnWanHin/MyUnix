# System Time Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a portable Fedora time-sync module that corrects the clock with chrony and uses a UTC hardware RTC without overwriting the installed machine's timezone.

**Architecture:** `modules/time-sync` owns only Fedora chrony package installation and privileged time-service operations. `scripts/myunix` dispatches it after the DNF baseline, while tests stub all privileged commands and inject an arbitrary temporary `HOME`. DMS configuration remains untouched; documentation explains that DMS weather Auto Location is IP-based and separate from system time.

**Tech Stack:** Bash, DNF, systemd `chronyd`, chrony CLI, `timedatectl`, Bats-style shell assertions.

## Global Constraints

- Require Fedora and install `chrony` only through a DNF manifest.
- Preserve the pre-existing system timezone; never derive it from Wi-Fi, IP, VPN, DMS, or a city name.
- Use explicit `sudo` only for system package/service/RTC commands.
- Write no account, location, IP, time, or credential data to Git.
- Use `$HOME` or existing state helpers only; do not encode a local user name or `/home/<name>` path.
- Keep reruns idempotent and record outcomes only through `scripts/myunix` state handling.

---

### Task 1: Define the time-sync module contract with a failing test

**Files:**
- Create: `tests/test_time_sync.sh`
- Create: `modules/time-sync/packages.txt`

**Interfaces:**
- Consumes: `install_dnf_manifest <manifest>` from `modules/dnf/install.sh`, `is_fedora`, `require_command`, and `die` from `scripts/lib/core.sh`.
- Produces: a test contract for `install_time_sync`, and a valid one-package DNF manifest.

- [ ] **Step 1: Write the failing test**

Create `tests/test_time_sync.sh` with a temporary non-user-specific home and a command log assertion:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

run env HOME="$temporary/portable-user" MYUNIX_TEST_MODE=fedora \
  MYUNIX_TIME_SYNC_DIR="$PROJECT_ROOT/modules/time-sync" bash -c '
  sudo() { printf "sudo:%s\\n" "$*"; "$@"; }
  dnf() { printf "dnf:%s\\n" "$*"; }
  systemctl() { printf "systemctl:%s\\n" "$*"; }
  chronyc() { printf "chronyc:%s\\n" "$*"; }
  timedatectl() { printf "timedatectl:%s\\n" "$*"; }
  timeout() { shift 2; "$@"; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/network.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  source "'"$PROJECT_ROOT"'/modules/time-sync/install.sh"
  install_time_sync
'
assert_status 0
assert_output_contains 'dnf:install -y chrony'
assert_output_contains 'systemctl:enable --now chronyd.service'
assert_output_contains 'chronyc:waitsync 10 0.1'
assert_output_contains 'chronyc:makestep'
assert_output_contains 'timedatectl:set-local-rtc 0'
! rg -n '/home/' "$PROJECT_ROOT/modules/time-sync"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_time_sync.sh`

Expected: failure because `modules/time-sync/install.sh` does not yet exist.

- [ ] **Step 3: Add the manifest fixture**

Create `modules/time-sync/packages.txt`:

```text
# Fedora NTP client and service used by the portable time-sync module.
chrony
```

- [ ] **Step 4: Commit the red contract and manifest**

```bash
git add tests/test_time_sync.sh modules/time-sync/packages.txt
git commit -m "test: define Fedora time sync contract"
```

### Task 2: Implement portable chrony and RTC setup

**Files:**
- Create: `modules/time-sync/install.sh`
- Modify: `tests/test_time_sync.sh`

**Interfaces:**
- Consumes: `install_dnf_manifest`, `require_command`, and `is_fedora`.
- Produces: `time_sync_dir()` and `install_time_sync()` for `scripts/myunix` dispatch.

- [ ] **Step 1: Implement the minimal module**

Create `modules/time-sync/install.sh`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

time_sync_dir() {
  printf '%s\n' "${MYUNIX_TIME_SYNC_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
}

install_time_sync() {
  local module_dir wait_attempts wait_threshold
  is_fedora || die 'Fedora is required'
  module_dir="$(time_sync_dir)"
  wait_attempts="${MYUNIX_TIME_SYNC_WAIT_ATTEMPTS:-10}"
  wait_threshold="${MYUNIX_TIME_SYNC_WAIT_THRESHOLD:-0.1}"
  [[ "$wait_attempts" =~ ^[1-9][0-9]*$ ]] || die 'MYUNIX_TIME_SYNC_WAIT_ATTEMPTS must be a positive integer'
  [[ "$wait_threshold" =~ ^[0-9]+([.][0-9]+)?$ ]] || die 'MYUNIX_TIME_SYNC_WAIT_THRESHOLD must be numeric'

  install_dnf_manifest "$module_dir/packages.txt"
  require_command systemctl
  require_command chronyc
  require_command timedatectl
  sudo systemctl enable --now chronyd.service
  sudo chronyc waitsync "$wait_attempts" "$wait_threshold"
  sudo chronyc makestep
  sudo timedatectl set-local-rtc 0
  info 'System time synchronized with chrony; existing timezone preserved.'
}
```

- [ ] **Step 2: Extend the test for an invalid wait setting**

Append a second test invocation:

```bash
run env MYUNIX_TEST_MODE=fedora MYUNIX_TIME_SYNC_WAIT_ATTEMPTS=0 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/modules/time-sync/install.sh"
  install_time_sync
'
assert_status 2
assert_output_contains 'MYUNIX_TIME_SYNC_WAIT_ATTEMPTS must be a positive integer'
```

- [ ] **Step 3: Run the focused test to verify it passes**

Run: `bash tests/test_time_sync.sh`

Expected: exit code 0; output contains the DNF, `chronyd`, `waitsync`,
`makestep`, and UTC-RTC calls, with no local user name.

- [ ] **Step 4: Commit the module**

```bash
git add modules/time-sync/install.sh tests/test_time_sync.sh
git commit -m "feat: add portable Fedora time synchronization"
```

### Task 3: Integrate, document, and verify the module

**Files:**
- Modify: `scripts/myunix`
- Modify: `tests/test_install_flow.sh`
- Modify: `README.md`
- Create: `docs/modules/time-sync.md`

**Interfaces:**
- Consumes: `install_time_sync()` from `modules/time-sync/install.sh`.
- Produces: `./scripts/myunix install --module time-sync`, one-click baseline installation, and documented operator expectations.

- [ ] **Step 1: Add the module source and dispatcher case**

In `scripts/myunix`, source the module alongside other module sources and add:

```bash
source "$ROOT/modules/time-sync/install.sh"

# inside run_module
time-sync) install_time_sync || status=1 ;;
```

Add `time-sync` after `dnf` in `run_all_install` and after the baseline
`bootstrap dnf rpm gnome input-method` sequence in `run_custom_install` so
chrony is available before it is configured.

- [ ] **Step 2: Extend the installation-flow test**

Add a source-only dispatch check:

```bash
run env MYUNIX_SOURCE_ONLY=1 MYUNIX_TEST_MODE=fedora MYUNIX_STATE_DIR="$temporary/state" bash -c '
  source "'"$PROJECT_ROOT"'/scripts/myunix"
  install_time_sync() { printf "time-sync dispatched\\n"; }
  run_module time-sync
'
assert_status 0
assert_output_contains 'time-sync dispatched'
```

Also extend the `run_all_install` stub assertion to require
`module:time-sync`.

- [ ] **Step 3: Write user-facing documentation**

Create `docs/modules/time-sync.md` with these concrete points:

```markdown
# System Time Sync

Run `./scripts/myunix install --module time-sync` to install chrony, enable
`chronyd`, correct the current clock, and store the RTC in UTC. The module
preserves the current system timezone; it never selects a timezone from an IP,
VPN, Wi-Fi network, DMS weather location, or city.

DMS **Auto Location** controls weather only and follows the external IP. VPN
routing can change its weather result but cannot change system time. In DMS,
select **13:00** in **Settings -> Time & Weather -> Time Format** for a 24-hour
clock such as `00:57`.
```

Add the module command to the README and link this documentation from the
installation overview.

- [ ] **Step 4: Run all required verification**

Run:

```bash
bash tests/test_time_sync.sh
bash tests/test_install_flow.sh
bash tests/run.sh
while IFS= read -r script; do bash -n "$script"; done < <(rg --files -g '*.sh' scripts modules tests)
command -v shellcheck >/dev/null && shellcheck scripts/myunix scripts/lib/*.sh modules/*/*.sh tests/*.sh || true
! rg -n '/home/' modules/time-sync
git diff --check
```

Expected: tests and syntax checks pass; the final path scan has no output.

- [ ] **Step 5: Review and commit**

Inspect only staged changes, scan them for secrets, then commit:

```bash
git add README.md docs/modules/time-sync.md scripts/myunix tests/test_install_flow.sh
git diff --staged --check
! git diff --staged | rg -i '(password|secret|api[_-]?key|token|private[_-]?key)'
git commit -m "feat: synchronize portable system time setup"
git push origin fedora
```
