# Captive Portal Feedback and Redirect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the user-invoked Wi-Fi Login launcher visibly report its state and reliably open a detected captive-portal login page.

**Architecture:** Extend the existing user-level Bash helper with a best-effort `notify-send` wrapper and a meta-refresh URL parser. Treat `portal`, `limited`, and `unknown` as probe states; preserve `full` as a no-browser path. Keep all URL validation before `xdg-open`.

**Tech Stack:** Bash, NetworkManager `nmcli`, `curl`, `notify-send`, DNF manifests, shell tests.

## Global Constraints

- Never store a network hostname, IP, redirect token, account name, password, or browser profile.
- Open a URL only from a user invocation and only after `portal_login_validate_url` accepts HTTP(S).
- Do not alter NetworkManager profiles, configure an automatic dispatcher, or touch GDM, greetd, Niri, or ToDesk.
- `notify-send` failures must not prevent terminal output or a valid portal launch.

---

### Task 1: Prove and implement launcher feedback and generic redirect parsing

**Files:**
- Modify: `.gitignore`
- Create: `modules/portal-login/config/bin/myunix-portal-login`
- Create: `modules/portal-login/config/applications/myunix-portal-login.desktop`
- Create: `modules/portal-login/config/autostart/myunix-nm-applet.desktop`
- Modify: `modules/portal-login/config/bin/myunix-portal-login`
- Modify: `tests/test_portal_login.sh`

**Interfaces:**
- Consumes: `nmcli -g CONNECTIVITY general`, probe response headers/body, `notify-send`, and `xdg-open`.
- Produces: `portal_login_notify <urgency> <summary> <body>`, `portal_login_meta_refresh_url <body-file>`, and `portal_login` notifications for every outcome.

- [x] **Step 0: Restore the ignored public portal sources**

Add explicit `.gitignore` negation rules for `modules/portal-login/config/` and
restore the existing public helper, launcher, and autostart files. Confirm the
focused portal test fails before restoration because the helper is absent, then
passes afterward.

- [ ] **Step 1: Add failing tests for notifications, uncertain connectivity, and meta refresh**

Append tests that stub `notify-send`, `curl`, and `xdg-open`:

```bash
run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "full\\n"; }
  notify-send() { printf "notify=%s|%s|%s\\n" "$1" "$2" "$3"; }
  portal_login
'
assert_status 0
assert_output_contains 'notify=normal|Wi-Fi Login|Already connected; no sign-in is needed.'

run bash -c '
  source "'"$portal_script"'"
  nmcli() { printf "limited\\n"; }
  notify-send() { :; }
  curl() {
    while (($#)); do case "$1" in -D) headers=$2; shift 2;; -o) body=$2; shift 2;; *) shift;; esac; done
    : > "$headers"
    printf "<meta http-equiv=\\\"refresh\\\" content=\\\"0; url=https://portal.example.test/login\\\">\\n" > "$body"
  }
  xdg-open() { printf "open=%s\\n" "$1"; }
  portal_login
'
assert_status 0
assert_equals 'open=https://portal.example.test/login' "$OUTPUT"
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
bash tests/test_portal_login.sh
```

Expected: failure because notification and meta-refresh functions do not exist yet.

- [ ] **Step 3: Add the minimal helper implementation**

Add these functions after `portal_login_timeout_seconds`:

```bash
portal_login_notify() {
  local urgency=$1 summary=$2 body=$3
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" "$summary" "$body" || true
  fi
}

portal_login_meta_refresh_url() {
  sed -nE 's/.*<meta[^>]+http-equiv=["'"'"']?[Rr]efresh["'"'"']?[^>]+content=["'"'"'][^"'"'"']*[Uu][Rr][Ll]=([^;"'"'"' >]+).*/\\1/p' "$1" | head -n 1
}
```

Update `portal_login_fetch_url` to call `portal_login_meta_refresh_url` after
the JavaScript parser. Update `portal_login` to probe on `portal|limited|unknown`,
notify on `full` and unsupported connectivity, notify before `xdg-open`, and
notify on every error path before returning nonzero.

- [ ] **Step 4: Run focused tests and syntax validation**

Run:

```bash
bash -n modules/portal-login/config/bin/myunix-portal-login
bash tests/test_portal_login.sh
```

Expected: exit status `0`.

### Task 2: Declare notification dependency and document the user-visible behavior

**Files:**
- Modify: `modules/portal-login/packages.txt`
- Modify: `docs/modules/portal-login.md`
- Test: `tests/test_portal_login.sh`

**Interfaces:**
- Consumes: DNF package manifest lines.
- Produces: a reproducible `libnotify` dependency and documented notification/redirect behavior.

- [ ] **Step 1: Add a failing installer assertion**

After the existing package-output assertion in `tests/test_portal_login.sh`, add:

```bash
assert_output_contains 'libnotify'
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
bash tests/test_portal_login.sh
```

Expected: failure because the portal module does not yet declare `libnotify`.

- [ ] **Step 3: Declare `libnotify` and update documentation**

Add `libnotify` as a separate package line in `modules/portal-login/packages.txt`.
Update `docs/modules/portal-login.md` to state that the launcher opens a live
HTTP(S) redirect for `portal`, `limited`, and `unknown` connectivity and shows
a desktop notification when already online or when it cannot open a login page.

- [ ] **Step 4: Run focused tests, full tests, and shell checks**

Run:

```bash
bash tests/test_portal_login.sh
bash tests/run.sh
find modules scripts -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n
command -v shellcheck >/dev/null && find modules scripts -type f -name '*.sh' -print0 | xargs -0 -r shellcheck || true
```

Expected: focused test and the full suite pass.

- [ ] **Step 5: Commit and push the verified public change**

Run:

```bash
git add modules/portal-login tests/test_portal_login.sh docs/modules/portal-login.md docs/superpowers/specs/2026-07-18-portal-login-feedback-design.md docs/superpowers/plans/2026-07-18-portal-login-feedback-implementation.md
git diff --staged --check
git diff --staged | rg -i 'password|secret|api[_-]?key|token|private.?key'
git commit -m "feat: improve captive portal feedback"
```

Expected: one atomic commit without private network or account data. Merge it
into `fedora`, then push `origin/fedora` after final verification.
