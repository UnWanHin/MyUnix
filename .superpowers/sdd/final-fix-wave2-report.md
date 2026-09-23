# Final fix wave 2 — RED/GREEN report

Date: 2026-09-23
Branch: `fedora`
Base reviewed: `a3f4fef`

## Scope

This wave closes the final review findings for the repair menu:

- WeChat launcher-owner failure propagation and rendered `Exec=` verification.
- Interactive result acknowledgement without selector redraw or input echo.
- Portal Login managed-file backups, idempotence, and failure propagation.
- Accurate Fcitx5/Niri next-login guidance in code, docs, and repair plan.

No remote push was performed.

## RED/GREEN evidence

### WeChat input-method owner

RED regressions used a stale WeChat launcher and stubs that failed each owner
operation independently. Before the fix, failed rendering, backup, or
replacement could continue to the success message; verifier checks also passed
for a stale launcher because they tested only file existence.

GREEN changes:

- `render_input_method_launcher`, `backup_input_method_launcher`, and the
  replacement `mv` now return failures to
  `install_input_method_app_overrides`.
- Temporary rendered files are removed on failure.
- `input_method_launcher_override_is_healthy` compares the rendered source
  `Exec=` lines with the installed user override.
- WeChat-only repair remains filtered to `wechat`; QQ fixtures remain byte-for-
  byte unchanged.

Regression scenarios: `install-failure`, `verifier-packages`, `wechat-only`,
`render-failure`, `backup-failure`, `replacement-failure`, and
`stale-rendered`.

### Interactive repair UX

RED PTY behavior showed `cancelled` immediately followed by category redraw,
so the result and next step were not reliably readable. The acknowledgement
input also needed to remain outside captured selector output.

GREEN changes:

- `run_fix` calls `fix_acknowledge_result` after every selected repair result,
  including clean diagnosis, cancellation, apply failure, and verification
  failure.
- The prompt and silent `read -rs` use stderr/input directly, so the value is
  neither echoed nor returned as a selector value.
- Back and Exit remain available after acknowledgement.

The real PTY regression covers `cancelled`, `success`, `clean`, `failure`, and
`verification-failure`, and asserts that no clear/redraw occurs before Enter.

### Portal Login owner

RED scenarios covered a missing desktop sibling beside a customized helper,
unchanged files, backup failure, replacement failure, package failure, and a
non-file target. The old installer overwrote changed files directly and did
not provide the managed backup boundary.

GREEN changes:

- Changed existing managed files are copied to
  `~/.local/state/myunix/backups/portal-login/<timestamp>/` before replacement.
- Matching content and mode is left untouched; no backup is created for it.
- Installation uses a temporary file and atomic `mv -T` replacement.
- Copy, backup, replacement, package, and non-file-target failures propagate.
- The existing sibling is backed up even when another portal file is absent.

Regression scenarios are in `tests/test_fix_portal.sh`.

### Fcitx5/Niri guidance

The Niri plan and applied result now state that repaired `spawn-at-startup`
configuration takes effect on the next Niri login; reloading the config does
not start Fcitx5 in an existing session. Users are told to log out/in or run
`fcitx5 -d` separately and restart applications for repaired environment
settings. Documentation and the repair design/implementation plan use the
same guidance.

## Verification

Focused tests:

```text
bash tests/test_fix_wechat.sh       PASS
bash tests/test_fix_portal.sh       PASS
bash tests/test_fix_niri.sh         PASS
python3 tests/test_fix_pty.py       PASS (5 PTY cases)
bash tests/test_fix.sh               PASS
bash tests/test_portal_login.sh      PASS
bash tests/test_input_method.sh      PASS
```

Full suite:

```text
HOME=<temporary> XDG_STATE_HOME=<temporary> bash tests/run.sh
Full test suite exit_code=0
```

Additional checks:

```text
bash -n modules/fix/install.sh modules/input-method/install.sh \
  modules/portal-login/install.sh tests/test_fix.sh tests/test_fix_niri.sh \
  tests/test_fix_wechat.sh tests/test_fix_portal.sh
python3 -m py_compile tests/test_fix_pty.py
git diff --check
```

`shellcheck` is not installed in the environment, so no ShellCheck run was
available. The worktree was reviewed for credentials and unrelated account
data; no secrets were added.
