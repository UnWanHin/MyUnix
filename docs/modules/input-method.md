# Input methods

The module keeps the English keyboard in every profile and supports two
independent Chinese capabilities: Cangjie 5 and Pinyin. One-click installation
selects both; custom installation presents a keyboard selector with English
locked on and Cangjie/Pinyin as optional choices. The package registry is
`packages.tsv`; `packages.txt` is the reviewed union used by `doctor` for the
one-click path.

- Cangjie installs `ibus-table-chinese-cangjie`, `fcitx5-chinese-addons` and
  `fcitx5-table-extra`.
- Pinyin installs `ibus-libpinyin` and the shared
  `fcitx5-chinese-addons` package.

The rendered Fcitx5 profile uses the verified engine names `cangjie5` and
`pinyin`, after `keyboard-us`. Rime, Mozc and Chewing are not default
capabilities and are not installed by this module.

On GNOME, open **Settings → Keyboard → Input Sources**, add **Chinese (Traditional) → Cangjie 5**, then use `Super`+`Space` to cycle input sources. On Niri + DMS, use Fcitx5: add `cangjie5` to the Fcitx5 profile and set its Niri session environment before logging out and back in. Export captures IBus dconf settings plus the reviewed Fcitx5 `config` and `profile` files; it intentionally excludes user dictionaries and account data.

For an explicit, noninteractive module run:

```bash
MYUNIX_INPUT_CANGJIE=1 MYUNIX_INPUT_PINYIN=0 ./scripts/myunix install --module input-method
```

## Application compatibility launchers

Some proprietary desktop clients use a toolkit-specific input-method path even inside a correct Niri/Fcitx5 session. The module manages reviewed user launcher overrides below `~/.local/share/applications/`; it never edits distributor files below `/usr/share/applications/`.

- **WeChat** uses the `qt-fcitx` profile, which launches it with Fcitx Qt variables including `QT_IM_MODULES=fcitx`.
- **QQ** uses the `electron-wayland-ime` profile, which keeps Electron's Wayland auto-selection and adds `--enable-wayland-ime`.

Only applications listed in `modules/input-method/app-profiles.tsv` receive an override. Native Wayland GTK applications remain untouched, and MyUnix does not globally force `GTK_IM_MODULE`. If an application is installed after the input-method module, rerun:

```bash
./scripts/myunix install --module input-method
```

Existing user launcher overrides are backed up below `~/.local/state/myunix/backups/input-method/<timestamp>/desktop-launchers/`. The profiles and public Fcitx configuration migrate with MyUnix; chat accounts, cookies, message data, and launcher caches do not.
