# Niri + DMS

The Niri + DMS module keeps GNOME installed and is included in one-click
installation so the synchronized desktop, DMS personalization and hotkeys are
restored on a replacement Fedora computer. Custom installation still lets the
user opt out. It uses the documented Fedora COPR package route for Fedora 43
and 44 only. Its complete package registry is `modules/niri-dms/packages.txt`;
after enabling the COPRs, the module verifies that every entry resolves through
DNF before it begins installation. The reviewed DMS plugin IDs in
`modules/niri-dms/plugins.txt` are then recreated through `dms plugins install`;
when `config/dms/plugins.lock.json` is present, `dms plugins restore` pins the
managed plugin revisions instead. Existing plugin metadata is detected so
rerunning the module remains idempotent. `config/dms/plugin-settings.json`
contains only the reviewed public `dankActions` section; KDE Connect pairing
identity and all other plugin state remain local.

The installer also enables the packaged user-level `dms.service` with
`systemctl --user enable dms.service`. This starts the DMS bar and UI with the
Niri graphical session; it does not replace GDM or change the display manager.
If DMS is missing after an earlier installation, run that command once and
log out/in again.

The interactive `./scripts/myunix fix` menu keeps session repairs separate
from application repairs. Input-method repairs do not rewrite Niri config;
use **Niri + DMS session → Niri configuration validation** when Fcitx5
startup/environment or a managed session binding needs attention. Every repair
shows its diagnosis and plan before confirmation, and waits for Enter after
reporting the result.

The Niri + DMS repair entries are confirmation-gated and scoped to the public
session integration:

- **Niri configuration validation** runs `niri validate --config` against the
  exact active config path when available and reports the complete command
  output under a labeled diagnostic. Its repair first restores absent,
  independent MyUnix-owned touchpad/helper/binding files; only after that
  exact config validates may it prepare managed include lines and restore
  the Fcitx5 startup/environment through the Niri module helper. It validates
  that exact candidate in the same directory before replacing the config,
  and backs up changed managed files under `~/.local/state/myunix/backups/`.
  An invalid user config is never replaced or rewritten. `niri` must be
  available to validate both the original and candidate configuration.
  Fcitx5 startup takes effect on the next Niri login; reloading the config does
  not run `spawn-at-startup`. In an existing session, log out and back in, or
  start Fcitx5 separately with `fcitx5 -d` and restart applications to pick up
  repaired environment settings.
- **DMS user service** checks `systemctl --user is-enabled` and
  `systemctl --user is-active`, then enables and starts the existing
  `dms.service` only after confirmation. It never uses `sudo` or reinstalls
  DMS.
- **Niri touchpad toggle** restores only the managed
  `~/.local/bin/niri-touchpad-toggle` helper, `myunix/touchpad.kdl`, its
  `Mod+F8` binding, and the two MyUnix include lines. Both original and exact
  candidate config must validate before replacement; mouse and trackpoint
  settings remain untouched. Verification validates the resulting config,
  not just file presence. When `NIRI_SOCKET` identifies a running session,
  `niri msg action load-config-file` must succeed or the repair reports failure.

`MYUNIX_NIRI_CONFIG` selects the exact config file and its directory owns the
managed fragments, even when a different `MYUNIX_NIRI_CONFIG_DIR` is set.
Without that file override, `MYUNIX_NIRI_CONFIG_DIR/config.kdl` is used.

These repairs do not read or modify credentials, subscriptions, browser
profiles, DMS private state, or other application-owned configuration. If the
session is not running, log out and back in after applying a session repair.

Run the input-method module before using Chinese input. The Niri module imports the reviewed Niri/DMS `.kdl` files from `modules/niri-dms/config/niri/`, backing up any existing `config.kdl` and `dms/` directory below `~/.local/state/myunix/backups/niri-dms/`. It then configures the Niri session to start Fcitx5 and exports `XMODIFIERS=@im=fcitx`, `QT_IM_MODULE=fcitx`, and `QT_IM_MODULES=wayland;fcitx`. It deliberately does not globally set `GTK_IM_MODULE`; native GTK Wayland applications use Niri's text-input-v3 route.

Rerun the module safely after DMS creates `~/.config/niri/config.kdl`:

```bash
./scripts/myunix install --module niri-dms
./scripts/myunix install --module input-method
```

## Configuration and shortcut synchronization

Run `./scripts/myunix export` on the configured machine to copy the public
Niri configuration into `modules/niri-dms/config/niri/`. This module owns
`config.kdl` and the reviewed `dms/*.kdl` files, including `dms/binds.kdl`,
which is the synchronized DMS shortcut source. The DMS-generated
`dms/alttab.kdl` may be exported for reproducibility, but it must not be
hand-edited.

## Managed custom shortcuts

`Mod` means the Super/Windows key in Niri. The complete canonical list remains
in [`modules/niri-dms/config/niri/dms/binds.kdl`](../../modules/niri-dms/config/niri/dms/binds.kdl);
the shortcuts below are the MyUnix-managed DMS and desktop customizations:

| Shortcut | Action |
| --- | --- |
| `Mod+T` | Open Kitty terminal |
| `Mod+Space` | Open DMS application launcher |
| `Mod+E` | Open Nautilus file manager |
| `Alt+E` | Open NetworkManager connection editor |
| `Mod+S` | Launch Flameshot region screenshot |
| `Mod+F8` | Toggle all touchpads; preserves tap-to-click, drag and natural scrolling settings |
| `Mod+Shift+T` | Toggle the focused window floating |
| `Mod+Shift+F` | Toggle fullscreen for the focused window |
| `Mod+Alt+L` | Lock screen through DMS |
| `Mod+Comma` | Open DMS settings |
| `Mod+M` | Toggle DMS process list/task manager |
| `Mod+N` | Toggle DMS notification center |
| `Mod+P` | Cycle display profile |
| `Mod+V` | Open DMS clipboard manager |
| `Mod+Y` | Open DMS wallpaper browser |
| `Mod+Shift+N` | Toggle DMS notepad |
| `Super+X` | Toggle DMS power menu |
| `Alt+Space` | Toggle DMS spotlight bar |
| `Ctrl+Alt+Delete` | Toggle DMS process list |
| `Ctrl+Shift+R` | Open DMS workspace rename |
| `Print` | Screenshot the current screen |
| `Alt+Print` | Screenshot the focused window |

The same file also synchronizes workspace/column navigation, window movement,
tabbed-column mode, overview, monitor movement, volume/brightness/media keys,
and the `Mod+1`…`Mod+9` workspace bindings. These are intentionally kept in
the canonical KDL rather than duplicated in this document. If a key is changed
locally, run `./scripts/myunix export` and review the resulting public diff
before committing it to the migration source.

The installed user command `~/.local/bin/niri-touchpad-toggle` toggles every
Niri touchpad. The one-click `./scripts/myunix install --all` profile enables
its `Mod+F8` binding automatically. In `./scripts/myunix install --guided`,
select **Niri + DMS** under optional desktop modules, then choose whether to
add its touchpad-toggle personalization. If selected, MyUnix creates a
`Mod+F8` binding; if not, it does not reserve a key. You can alternatively bind
the command yourself in the DMS Keybinds UI. It switches the public fragment
`~/.config/niri/myunix/touchpad.kdl` between enabled and `off`, then reloads
Niri and shows a desktop notification when available. Its binding uses
`repeat=false`, and the helper holds a user-state lock, so a held key or rapid
second press cannot run two conflicting toggles at once. It uses no `sudo` and
defaults to enabled on a new installation. When enabled, a one-finger tap is a
left click, tap-and-drag enables one-finger dragging, and two-finger scrolling
uses the reverse (natural) direction; the toggle does not reset either
preference. The Niri+DMS exporter copies only these
public `myunix/` fragments; Phone Connect's `kdeconnect.kdl` remains owned by
the Phone Connect module and is not copied here.

The export is an allowlist: it does not recurse through `~/.config/niri`, so
timestamped backups and unrelated files stay local. `myunix/kdeconnect.kdl` is
intentionally not owned here; the separate [Phone Connect](phone-connect.md)
module exports and restores that KDE Connect startup fragment. DMS JSON
settings are synchronized only through the categorized public allowlist below;
plugin state, caches and machine-specific paths remain excluded.

## DMS personalization synchronization

Public DMS preferences are kept separately from Niri KDL in
`modules/niri-dms/config/dms/`:

- `bar.json` — bar layout, widgets, tray and focused-window presentation.
- `dock.json` — dock layout, placement and visual options.
- `appearance.json` — typography, animation, elevation, blur and visual style.
- `frame.json` — connected-frame appearance and geometry.
- `time-weather.json` — clock format, calendar display, weather units, weather
  visibility and IP-based Auto Location. It intentionally excludes coordinates,
  city names and all DMS session data.

`./scripts/myunix export` regenerates only these category files from the live
DMS settings. The Niri+DMS installer shallow-merges only their allowlisted
keys into `~/.config/DankMaterialShell/settings.json`, preserving unknown local
keys. On a new machine it creates a private empty JSON object first, so the
bar is not skipped before DMS generates its settings file. Existing files are
backed up before an effective change; a newly created file has no prior state
to back up. It does not restart DMS automatically; log out/in or run
`dms restart` when you deliberately want imported appearance changes applied.

Kitty is synchronized through a separate public allowlist under
`modules/niri-dms/config/kitty/`: `kitty.conf`, `dank-theme.conf`, and
`dank-tabs.conf`. The installer backs up changed files below the Niri/DMS
backup state directory before importing them. Kitty history, runtime sockets,
backup files, and other unlisted files remain local.

The Niri exporter/importer deliberately excludes `dms/outputs.kdl`, which can
contain monitor-specific modes, scale and positions. The optional include in
`config.kdl` remains so each computer can keep or regenerate its own display
profile; this prevents a laptop's output settings from causing an invalid
layout or black screen on another machine. DMS's generated `dms/input.kdl` is
also excluded because it is not referenced by the public config; touchpad
behavior is carried by the portable `myunix/touchpad.kdl` fragment.

The sync excludes plugin metadata and paired-device identities, while the
reviewed `dankActions` object is synchronized separately. It also excludes
Wi-Fi,
Bluetooth and audio-device pins, output/display profiles, wallpaper and custom
paths, commands, usage histories, notification data, greeter settings, caches
and generated files. A bar widget ID such as `dankKDEConnect` is only a public
layout reference; it does not include the paired phone identity.

Log out and back into Niri after either session-level change. For Cangjie 5, Fcitx5 uses the internal ID `cangjie5`; on Fedora, `fcitx5-chinese-addons` provides the Table engine and `fcitx5-table-extra` provides the Cangjie table data.
