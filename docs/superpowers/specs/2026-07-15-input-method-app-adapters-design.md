# Input-method application adapters design

**Status:** approved in conversation

## Goal

Make app-specific Chinese-input compatibility part of MyUnix migration so
Tencent WeChat, QQ, and future known desktop applications do not require
manual launcher edits after a Fedora/Niri move.

## Architecture

The input-method module gains an allowlisted `app-profiles.tsv` registry. Each
record identifies a system desktop file and a small, named compatibility
profile. On install, MyUnix detects whether the system desktop file exists and
creates an XDG user launcher override in `~/.local/share/applications/` only
for installed applications. The system launcher below `/usr/share/applications`
is never modified.

Initial profiles are:

- `qt-fcitx` for WeChat: set `XMODIFIERS=@im=fcitx`,
  `QT_IM_MODULE=fcitx`, and `QT_IM_MODULES=fcitx` for the launcher process.
- `electron-wayland-ime` for QQ: set `XMODIFIERS=@im=fcitx`, retain Electron
  Wayland auto-selection, and add `--enable-wayland-ime`.

The profile registry is extensible, but no unreviewed application receives a
generic override. Native Wayland GTK applications remain untouched; MyUnix
does not globally force `GTK_IM_MODULE`.

## Safety and migration behavior

- Before replacing an existing user launcher, copy it below
  `~/.local/state/myunix/backups/input-method/<timestamp>/desktop-launchers/`.
- Preserve non-`Exec=` desktop-entry data from the distributor launcher.
- Re-running the module rebuilds a launcher from the current system desktop
  file, so upgrades are adopted without duplicating environment prefixes.
- Missing applications are a successful no-op. Install the application later,
  then rerun `./scripts/myunix install --module input-method`.
- Exported input-method configuration remains public Fcitx configuration;
  MyUnix does not export chat accounts, message data, cookies, launcher cache,
  or application profile data.

## Verification and documentation

- Shell tests use temporary desktop files to verify WeChat/QQ transformation,
  no-op handling for missing apps, idempotence, and backup creation.
- Module documentation records the exact profiles, the rerun workflow, and the
  rule that new applications require an explicit registry entry plus tests.
- The incident record links the original Niri+DMS Cangjie issue to this
  launcher-compatibility layer.
