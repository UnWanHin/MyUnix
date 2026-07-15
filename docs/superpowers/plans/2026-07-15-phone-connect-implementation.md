# Phone Connect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a privacy-preserving KDE Connect Phone Connect module for Fedora Niri + DMS.

**Architecture:** `modules/phone-connect/` owns packages, a public Niri startup fragment, guarded firewall handling, and export. The Niri+DMS template includes the fragment optionally so a full Niri import does not erase it. Device pairing remains outside Git.

**Tech Stack:** Bash, DNF, firewalld, Niri KDL, MyUnix shell tests.

## Global Constraints

- Use `kdeconnectd`, never Valent or SSH-agent configuration.
- Never edit DMS-generated `dms/*.kdl`; use only `~/.config/niri/myunix/kdeconnect.kdl`.
- `kde-connect-nautilus` is opt-in through `MYUNIX_PHONE_CONNECT_NAUTILUS=1` or the guided prompt.
- Opening `1714-1764/tcp` and `1714-1764/udp` needs `MYUNIX_CONFIRM_KDECONNECT_FIREWALL=allow` when noninteractive.
- Never export device identities, certificates, pairing data, files, clipboard data, SMS, or keys.

---

### Task 1: Add tested KDE Connect installation and Niri payload

**Files:**

- Create: `modules/phone-connect/packages.txt`
- Create: `modules/phone-connect/config/niri/myunix/kdeconnect.kdl`
- Create: `modules/phone-connect/install.sh`
- Create: `tests/test_phone_connect.sh`

**Interfaces:**

- Produces `install_phone_connect()`, `import_kdeconnect_niri_fragment()`, `ensure_kdeconnect_niri_include()`, and `configure_kdeconnect_firewall()`.
- Consumes `info()`, `die()`, and `is_fedora()` from `scripts/lib/core.sh`.

- [ ] **Step 1: Write the failing Niri integration and firewall-gating test.**

```bash
temporary_dir="$(mktemp -d)"
mkdir -p "$temporary_dir/home/.config/niri"
printf '%s\n' 'include optional=true "dms/binds.kdl"' > "$temporary_dir/home/.config/niri/config.kdl"
run env HOME="$temporary_dir/home" MYUNIX_PHONE_CONNECT_DRY_RUN=1 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/phone-connect/install.sh'; import_kdeconnect_niri_fragment; ensure_kdeconnect_niri_include; ensure_kdeconnect_niri_include"
assert_status 0
assert_equals 1 "$(grep -c '^include optional=true "myunix/kdeconnect.kdl"$' "$temporary_dir/home/.config/niri/config.kdl")"
grep -Fqx 'spawn-at-startup "kdeconnectd"' "$temporary_dir/home/.config/niri/myunix/kdeconnect.kdl"
run env MYUNIX_PHONE_CONNECT_DRY_RUN=1 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/phone-connect/install.sh'; configure_kdeconnect_firewall"
assert_status 0
assert_output_contains 'Firewall changes skipped'
```

- [ ] **Step 2: Run `bash tests/test_phone_connect.sh`; expect failure because the module does not exist.**

- [ ] **Step 3: Add the static payload.** `packages.txt` contains `kdeconnectd`; the fragment contains:

```kdl
// Managed by MyUnix phone-connect. Pairing data is intentionally not exported.
spawn-at-startup "kdeconnectd"
```

- [ ] **Step 4: Implement the installer.** It checks Fedora, installs the manifest, conditionally installs `kde-connect-nautilus`, imports the fragment with backup, adds exactly one main-config include, runs the firewall gate, verifies `kdeconnectd`/`kdeconnect-cli`, and prints pairing guidance.

`configure_kdeconnect_firewall()` skips when firewalld is unavailable/inactive or approval is missing. With an active firewall and approval, it runs `sudo firewall-cmd --permanent --add-port=1714-1764/tcp`, the UDP equivalent, then `sudo firewall-cmd --reload`. `MYUNIX_PHONE_CONNECT_DRY_RUN=1` must print intended commands but never run them.

- [ ] **Step 5: Run `bash tests/test_phone_connect.sh && bash -n modules/phone-connect/install.sh`; expect exit 0.**

- [ ] **Step 6: Commit the installer task:** `git add modules/phone-connect tests/test_phone_connect.sh && git commit -m "feat: add KDE Connect phone module"`.

### Task 2: Preserve the fragment during Niri imports and expose the CLI

**Files:**

- Modify: `modules/niri-dms/config/niri/config.kdl`
- Modify: `config/niri/config.kdl`
- Modify: `scripts/myunix`
- Modify: `tests/test_niri_dms.sh`
- Modify: `tests/test_phone_connect.sh`

**Interfaces:**

- Adds one `include optional=true "myunix/kdeconnect.kdl"` to each Niri template.
- Exposes `./scripts/myunix install --module phone-connect` and `export_phone_connect()`.

- [ ] **Step 1: Add failing tests asserting exactly one optional include in the template and that CLI dispatch accepts `phone-connect` in Fedora test mode with dry-run stubs.**

- [ ] **Step 2: Run the focused tests; confirm these new cases fail.**

- [ ] **Step 3: Add the include adjacent to other optional user-managed includes, outside `dms/`; source phone module files in `scripts/myunix`; add `phone-connect) install_phone_connect || status=1 ;;`; call `export_phone_connect` after `export_niri_dms`.**

- [ ] **Step 4: Run `bash tests/test_phone_connect.sh && bash tests/test_niri_dms.sh && bash tests/run.sh`; expect exit 0.**

- [ ] **Step 5: Commit the integration task:** `git add modules/niri-dms/config/niri/config.kdl config/niri/config.kdl scripts/myunix tests/test_niri_dms.sh tests/test_phone_connect.sh && git commit -m "feat: preserve KDE Connect Niri integration"`.

### Task 3: Add public export and migration documentation

**Files:**

- Create: `modules/phone-connect/export.sh`
- Create: `docs/modules/phone-connect.md`
- Modify: `README.md`
- Modify: `tests/test_phone_connect.sh`

**Interfaces:**

- Produces `export_phone_connect()` that copies only the public Niri fragment.

- [ ] **Step 1: Add a failing export test using `MYUNIX_PHONE_CONNECT_CONFIG_SOURCE`; assert `kdeconnect.kdl` exports and no KDE Connect state directory is copied.**

- [ ] **Step 2: Run `bash tests/test_phone_connect.sh`; confirm the new export case fails.**

- [ ] **Step 3: Implement `export_phone_connect()`.** Missing fragment is a successful no-op; an existing fragment is copied only to `config/niri/myunix/kdeconnect.kdl`.

- [ ] **Step 4: Document exact install and firewall-confirmation commands, `kdeconnect-cli -l`, pairing on the same LAN, optional Nautilus integration, and every privacy exclusion. Add the module command to README.**

- [ ] **Step 5: Run `bash tests/run.sh`, Bash syntax checks for every script/module shell file, ShellCheck if installed, `git diff --check`, `git branch --show-current`, and `git status --short`; expect checks to pass and report the local status.**

- [ ] **Step 6: Commit documentation:** `git add README.md docs/modules/phone-connect.md modules/phone-connect/export.sh docs/superpowers/specs/2026-07-15-phone-connect-design.md docs/superpowers/plans/2026-07-15-phone-connect-implementation.md && git commit -m "docs: document Phone Connect migration"`.
