# DMS plugin dependencies and the optional KDE integration

## Context

DankMaterialShell's plugin manager installs plugin code but no Fedora packages.
Between 2026-09-26 and 2026-09-30 the extra plugins on this workstation
(AMD GPU Monitor, Calculator, DMS Theme Sync, Docker Manager, Emoji Launcher,
Home Assistant Monitor, Wallpaper Carousel) were installed and made to work by
hand, and a temporary script applied the missing dependencies. DNF transaction
`#25` on 2026-09-30 00:26 CST installed 252 packages and about 551 MiB from an
argument list that the deleted `~/dms-fix-apply.sh` had assembled from more
than one source, so the transaction no longer said which package belonged to
which plugin.

The same session also added the plugin shortcuts, the `XDG_MENU_PREFIX` needed
by the KDE-aware plugin menus, a `window-rule` that hides the XWayland video
bridge helper and the DMS bar widgets that show the new plugins. None of it was
in the repository, so a replacement computer would have lost all of it.

## Decision

`modules/niri-dms/packages.txt` now owns only the dependencies a Fedora
workstation needs for the reviewed plugins: `qalculate` and `qt6-qtwebsockets`
for Calculator and Home Assistant Monitor, `adw-gtk3-theme`, `qt5ct`, `qt6ct`,
`kvantum`, `qt6-qttools`, `plasma-breeze`, `breeze-gtk`, `xsettingsd` and
`papirus-icon-theme` for the Theme Sync plugin's GTK/Qt/Kvantum/icon themes.
AMD GPU Monitor does not come from DNF: it needs upstream's `amdgpu_top`, which
Fedora does not package, so `modules/rpm/apps.tsv` gained a checksum-pinned
optional record for it.

`plasma-workspace` moved to the new opt-in `packages-kde.txt` behind
`MYUNIX_NIRI_DMS_KDE=1` (custom installation: **KDE/Plasma application menu**).
It is the only source of a complete `/etc/xdg/menus/plasma-applications.menu`,
but it resolves to roughly 250 packages and weak-depends on
`xwaylandvideobridge`. `kde-cli-tools` is listed with it because `keditfiletype`
is neither a `Requires` nor a `Recommends`. Selecting it also writes
`myunix/plasma-menu.kdl`, and removing the package removes that fragment again.

`myunix/plugin-binds.kdl` owns the plugin shortcuts, and `config.kdl` no longer
sets `XDG_MENU_PREFIX` inline. It also carries the `xwaylandvideobridge`
`window-rule`: the helper hides itself with the X11 EWMH opacity hint, which
`xwayland-satellite` does not implement, so niri tiled an unclosable black
window. The rule makes it floating, unfocused and fully transparent.

The public plugin settings projection now also allows the non-secret
`dockerManager` keys, so the container binary (`podman`) is restored on a new
computer while Home Assistant tokens, KDE Connect device IDs and theme-folder
overrides stay local. `export_niri_dms` and `install_niri_dms` normalize the
whole managed include list in one function, and the exporter never writes an
inline `XDG_MENU_PREFIX`.

The Niri configuration repair restores `myunix/plugin-binds.kdl` next to the
touchpad fragments, so `./scripts/myunix fix` and the installer agree on what
a complete managed session looks like.

## Consequences

A new computer gets the plugin dependencies, the shortcuts, the KDE menu
fragment, the bar layout and the video-bridge rule from the repository, and the
heavy Plasma package set only when the user asks for it. `dms plugins install`
still installs only plugin code, so a future plugin addition must extend
`packages.txt` (or `apps.tsv`) in the same change.

`appearance.json`, `dock.json` and `frame.json` remain near-empty because DMS
6.7 moved most visual options into `barConfigs`/`dockConfigs` arrays and
`builtInPluginSettings`; the allowlist still captures `bar.json` faithfully.
Restoring those categories is a known follow-up and must not be done by
hand-editing the exported files.
