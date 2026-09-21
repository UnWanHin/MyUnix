# MyUnix Repair Menu Design

## Context

MyUnix can install, export, retry failed modules, and restore the guarded DMS
greeter. It does not provide a single, discoverable route for repairing a
working Fedora installation after a desktop application or session integration
drifts. Users therefore have to remember module names and ad-hoc commands.

The repair route must not become a destructive reinstaller. In particular, it
must never export, overwrite, or commit credentials, application logins,
browser profiles, VPN subscriptions, SSH keys, or FlClash subscription URLs.

## Goal

Add an interactive `./scripts/myunix fix` command with a two-level menu. A
selected repair always runs a read-only diagnosis first, prints the exact
condition and the planned changes, then requires an explicit confirmation
before it makes any change. Each successful repair runs its own focused
verification and reports any required logout or restart.

## Command Interface

```text
./scripts/myunix fix
```

`fix` requires an interactive terminal. It does not have an `--all` equivalent:
automatic repair would violate the confirmation requirement. A future
non-interactive interface, if needed, must use an explicit repair identifier
and a separate `--yes` flag; it is out of scope for this change.

The first menu contains these categories:

1. Input method and application compatibility
2. Niri + DMS session
3. Desktop application integration
4. Network and captive portal
5. Development tools

The second menu presents repair items owned by that category. Selecting an item
does not modify the system. It displays a diagnostic report followed by a
plain-language change plan and asks `Apply this repair?`. Declining leaves the
system untouched and returns to the repair menu.

## Architecture

`scripts/myunix` remains the command dispatcher and menu owner. It will source
a focused repair library from `modules/fix/` rather than embedding application
logic in the CLI entry point.

The repair library has one registration record per repair, with stable fields:

```text
id | category | display name | diagnose function | repair function | verify function | session note
```

The dispatcher owns selection, confirmation, result reporting and category
navigation. A repair function owns only the files, services, launchers and
packages already owned by its existing module. Diagnostics must be read-only.
Repair functions may reuse existing idempotent module functions, but should use
the smallest action that restores the stated condition rather than re-running
unrelated installation work.

The initial repair records are:

| Category | ID | Diagnosis and repair boundary |
| --- | --- | --- |
| Input method and application compatibility | `wechat-cangjie` | Check Fcitx5, the Cangjie engine, WeChat launcher override and Niri Fcitx session configuration; restore only the input-method configuration and WeChat adapter. |
| Niri + DMS session | `niri-config` | Validate the active Niri config; do not silently rewrite an invalid user config. The repair report provides the exact validation output and only restores MyUnix-owned fragments when they are absent. |
| Niri + DMS session | `dms-service` | Check the user DMS service and enable/start it when absent or inactive. |
| Niri + DMS session | `touchpad-toggle` | Check the MyUnix touchpad helper, `Mod+F8` binding, and Niri config include; restore only those MyUnix-owned files and reload the config. |
| Desktop application integration | `jetbrains-toolbox` | Check the user-level Toolbox launcher and `.desktop` entry; restore desktop registration and icon metadata without reinstalling an already usable Toolbox archive. |
| Desktop application integration | `flclash-launcher` | Check only that FlClash is installed and has a desktop launcher. It never reads, deletes, restores, or syncs profiles or subscription URLs. |
| Network and captive portal | `portal-login` | Check the portal-login desktop integration and launcher; repair only the locally managed command/desktop entry. |
| Development tools | `codex-fedora` | Check `node`, `npm`, and `codex`; restore the Fedora Codex CLI package path without touching `~/.codex/auth.json` or provider settings. |
| Development tools | `development-toolchain` | Check the installed MyUnix toolchain commands and show missing components; repair invokes the existing toolchain installer with its existing scope rules. |

The first implementation deliberately excludes generic "fix everything" and
kernel, bootloader, driver, VPN, DNS, or hardware repairs. Those have broader
side effects and need separate, evidence-led workflows.

## Data Flow and Safety

```text
category selection → repair selection → read-only diagnosis
  → displayed findings and plan → explicit confirmation
  → bounded repair → focused verification → session/restart guidance
```

Repairs write only to paths already managed by the owning MyUnix module. User
configuration is backed up under `~/.local/state/myunix/backups/` before any
managed configuration replacement. Package installation follows existing
module privilege boundaries. A diagnostic failure is shown as a failed check;
it never turns into an unbounded remediation attempt.

The repair framework records no run state in Git. It may use the existing
`~/.local/state/myunix/` location for local logs or backups. It does not print
secret-bearing environment variables or subscription URLs.

## User Experience

Example:

```text
MyUnix repair
› Input method and application compatibility
  Niri + DMS session
  Desktop application integration
  Network and captive portal
  Development tools

WeChat / Cangjie compatibility
Diagnosis:
  - fcitx5: installed
  - cangjie5: missing from the public profile
  - WeChat launcher override: missing

This repair will regenerate the public Fcitx5 profile and WeChat launcher
override. It will not change WeChat login data or other applications.
Log out and back into Niri after completion.
Apply this repair? [y/N]
```

The menu uses the repository's existing arrow-key selector. Confirmation is a
separate `y/N` prompt, defaulting to no. The final line identifies one of:
`repaired and verified`, `diagnosis clean; no change needed`, `cancelled`, or
`repair failed`, plus a concise next step.

## Testing and Verification

Tests run repairs in temporary homes with stubs for external commands. They
must prove that:

1. `myunix fix` rejects non-interactive execution.
2. Category and item registration are complete and IDs are unique.
3. A diagnostic does not write managed configuration.
4. Declining confirmation does not call the repair function.
5. Each initial repair emits a plan, scopes its writes to its owner, and runs a
   focused verifier after repair.
6. The WeChat/FlClash/Codex repairs never copy or inspect private credentials,
   subscription URLs, or authentication files.
7. Existing installer, export, and Niri-DMS tests continue to pass.

Before commit, run the project test suite, `bash -n` for every changed shell
script, `git diff --check`, and ShellCheck when available.

## Non-Goals

- Reinstalling every application or resetting user profiles.
- Synchronizing FlClash URLs, application sessions, account credentials or
  secrets.
- Making kernel, graphics-driver, BIOS, network-routing, or bootloader fixes
  automatic.
- Replacing `doctor`, `retry`, or the module installation interfaces.
