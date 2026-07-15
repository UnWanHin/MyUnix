# Niri + DMS Cangjie recovery record

## Symptoms

Chinese input worked in GNOME but not in Niri + DMS. IBus could select `table:cangjie5`, yet Wayland clients did not receive Chinese input. Fcitx5 initially showed Cangjie data files but would not select the engine.

## Root cause

GNOME manages IBus itself; Niri + DMS needs a Wayland-native input-method service. The correct service is Fcitx5. Fedora splits the Fcitx Table components: `fcitx5-chinese-addons` supplies `libtable.so`, while `fcitx5-table-extra` supplies the Cangjie dictionaries. Installing only the dictionary package leaves Fcitx unable to load Cangjie.

Fcitx5's Cangjie input-method ID is `cangjie5`. `table-cangjie5` is not a valid Fcitx ID and is discarded from its profile.

## Persistent configuration

- The input-method module installs `fcitx5-chinese-addons` and `fcitx5-table-extra` and exports reviewed Fcitx5 `config` and `profile` files.
- The Niri + DMS module owns the Niri session integration: it starts Fcitx5 and sets `XMODIFIERS`, `QT_IM_MODULE`, and `QT_IM_MODULES` for Fcitx5.
- Do not globally force `GTK_IM_MODULE` in Niri. The Fcitx Wayland guidance recommends native GTK Wayland text-input-v3 where available.
- The input-method module owns allowlisted launcher adapters for toolkit-specific clients: WeChat uses Fcitx Qt variables, while QQ receives Electron's `--enable-wayland-ime`. They are XDG user overrides, rebuilt from distributor desktop files when the module is rerun.

When either application is installed or its desktop file changes, rebuild the
adapter rather than editing `/usr/share/applications/` directly:

```bash
./scripts/myunix install --module input-method
```

## Verification

After logging into Niri, `fcitx5-remote -n` should show `cangjie5` when Chinese is active, and `fcitx5-remote` should print `2`. `Ctrl`+`Space` toggles Fcitx active state between English and the active Cangjie engine.
