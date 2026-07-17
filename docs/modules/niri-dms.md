# Niri + DMS

The Niri + DMS module is optional and keeps GNOME installed. It uses the documented Fedora COPR package route for Fedora 43 and 44 only. Its complete package registry is `modules/niri-dms/packages.txt`; after enabling the two COPRs, the module verifies that every entry resolves through DNF before it begins installation. The reviewed DMS plugin IDs in `modules/niri-dms/plugins.txt` are then recreated through `dms plugins install`; existing plugin metadata is detected so rerunning the module does not reinstall them. Plugin settings themselves are deliberately not exported.

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

The installed user command `~/.local/bin/niri-touchpad-toggle` toggles every
Niri touchpad. In `./scripts/myunix install --guided`, select **Niri + DMS**
under optional desktop modules, then choose whether to add its touchpad-toggle
personalization. If selected, MyUnix creates a `Mod+F8` binding; if not, it
does not reserve a key. You can alternatively bind the command yourself in the
DMS Keybinds UI. It switches the public fragment
`~/.config/niri/myunix/touchpad.kdl` between enabled and `off`, then reloads
Niri and shows a desktop notification when available. It uses no `sudo` and
defaults to enabled on a new installation. The Niri+DMS exporter copies only
these public `myunix/` fragments; Phone Connect's `kdeconnect.kdl` remains
owned by the Phone Connect module and is not copied here.

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
keys into an existing `~/.config/DankMaterialShell/settings.json`, preserving
unknown local keys. It does not restart DMS automatically; log out/in or run
`dms restart` when you deliberately want imported appearance changes applied.

The sync excludes plugin settings and metadata, paired phones, Wi-Fi,
Bluetooth and audio-device pins, output/display profiles, wallpaper and custom
paths, commands, usage histories, notification data, greeter settings, caches
and generated files. A bar widget ID such as `dankKDEConnect` is only a public
layout reference; it does not include the paired phone identity.

Log out and back into Niri after either session-level change. For Cangjie 5, Fcitx5 uses the internal ID `cangjie5`; on Fedora, `fcitx5-chinese-addons` provides the Table engine and `fcitx5-table-extra` provides the Cangjie table data.
