# Generic Captive Portal Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe, generic captive-portal login helper and NetworkManager tray UI to MyUnix.

**Architecture:** A standalone `portal-login` module owns its Fedora manifest, the public launcher and the user-level helper. The helper performs connectivity detection and one-time redirect extraction; `scripts/myunix` only dispatches the module.

**Tech Stack:** Bash, NetworkManager `nmcli`, `curl`, `xdg-open`, desktop-entry specification, DNF.

## Global Constraints

- Do not save portal URLs, credentials, MAC addresses, tokens or browser data.
- Install `network-manager-applet` through the module DNF manifest.
- Open only validated `http://` or `https://` redirect URLs after a user starts the helper.
- Keep user files unprivileged and module state below `~/.local/state/myunix/` only.

---

### Task 1: Specify portal helper behavior with tests

**Files:**
- Create: `tests/test_portal_login.sh`
- Create: `modules/portal-login/install.sh`

- [ ] Write tests for JavaScript redirect extraction, HTTP `Location` extraction,
  unsupported schemes, full connectivity and portal launcher installation.
- [ ] Run `bash tests/test_portal_login.sh` and confirm it fails before the
  module exists.

### Task 2: Implement the isolated portal-login module

**Files:**
- Create: `modules/portal-login/packages.txt`
- Create: `modules/portal-login/config/bin/myunix-portal-login`
- Create: `modules/portal-login/config/applications/myunix-portal-login.desktop`
- Modify: `modules/portal-login/install.sh`

- [ ] Resolve only a current `portal` NetworkManager state.
- [ ] Parse a live HTTP or JavaScript redirect, validate its scheme and invoke
  `xdg-open` without persisting the URL.
- [ ] Install `nm-applet`, the executable launcher and the desktop entry
  idempotently.
- [ ] Run the portal-login test and Bash syntax checks.

### Task 3: Register and document the module

**Files:**
- Modify: `scripts/myunix`
- Modify: `README.md`
- Create: `docs/modules/portal-login.md`

- [ ] Add `portal-login` to module dispatch and README command examples.
- [ ] Document the generic detector, DMS Spotlight entry and privacy boundary.
- [ ] Run the full suite, `bash -n`, ShellCheck when available and
  `git diff --check`.
