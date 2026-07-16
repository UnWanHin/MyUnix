# Niri Touchpad Toggle Design

## Context

Niri owns libinput touchpad settings in the Niri session. DMS exposes neither
a touchpad action nor a touchpad settings page, and Niri 26.04 exposes static
`touchpad { off }` configuration but no IPC action that toggles it at runtime.
The user wants `Mod+F8` to switch the touchpad on and off from a DMS/Niri
shortcut, with the customization reproduced by MyUnix.

## Decision

Add a small, user-level executable named `niri-touchpad-toggle` to the Niri +
DMS module. It atomically rewrites the public Niri fragment
`~/.config/niri/myunix/touchpad.kdl` between an enabled fragment and
`touchpad { off }`, then asks Niri to reload its configuration when available.
It emits a desktop notification when `notify-send` is installed.

`modules/niri-dms/config/niri/config.kdl` will include this fragment after its
base input settings and optionally include a generated binding fragment. The
guided custom installer asks whether to add the touchpad toggle; selecting it
creates the default `Mod+F8` binding, while declining it removes that managed
binding. The module installer and exporter will explicitly copy only the
touchpad fragments; they will continue to exclude unrelated
`myunix/` fragments such as Phone Connect state.

## Boundaries

- The helper runs as the desktop user and never uses `sudo`.
- It manages all touchpads because Niri 26.04 does not provide per-device
  touchpad configuration.
- The selected enabled/disabled preference and optional shortcut are public
  configuration and are exported. Backups and run state remain below
  `~/.local/state/myunix/`.
- The helper is a persistent user command under `~/.local/bin`, not a
  temporary script. No project receives a `.vscode` or other project-local
  artifact.
- MyUnix will maintain this setting whenever its Niri/DMS module is installed
  or exported. It cannot observe operating-system changes while Codex/MyUnix
  is not running; use `./scripts/myunix export` after manual changes.

## Verification

Tests must prove that the helper writes valid enabled and disabled fragments,
does not leave temporary files, and that import/export transfer only the
touchpad fragment. The full shell suite, Bash syntax checks, `niri validate`,
and `git diff --check` must pass before the change is committed.
