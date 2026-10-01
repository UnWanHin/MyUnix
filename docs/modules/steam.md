# Steam on Fedora Niri

Steam is managed as the RPM Fusion `steam` DNF package, not as a downloaded
direct RPM. MyUnix's bootstrap module enables RPM Fusion before Steam is
installed, so normal Fedora package updates continue to update Steam.

## Install or reapply

```bash
./scripts/myunix install --module steam
```

One-click installation includes Steam. In custom installation, select
**Steam (RPM Fusion; Niri compatible)** from the optional desktop-applications
screen.

## Niri blank-window workaround

MyUnix creates `~/.local/share/applications/steam.desktop` from the system
desktop entry and adds `-system-composer` to Steam's main launcher and every
desktop action. This retains Steam web-view GPU acceleration while using the
system compositor instead of Steam's problematic CEF/OpenGL presentation path
under Niri/Xwayland.

It never edits `/usr/share/applications/steam.desktop`. A pre-existing user
Steam override is backed up below `~/.local/state/myunix/backups/steam/`.

This workaround is documented by Niri:

- <https://github.com/YaLTeR/niri/wiki/Application-Issues#steam>
- <https://github.com/ValveSoftware/steam-for-linux/issues/12320>

## X11 context menus and the XWayland satellite

Steam's X11 popups (the library context menu, tray menu and file dialogs) close
about 33 ms after they open under the Fedora 44 `xwayland-satellite` 0.8.2
package. Its `require_wm_focus()` re-asserts the X input focus on
override-redirect windows when focus returns to the compositor, so Steam
receives the focus loss it treats as a dismiss. The bug is independent of
`-system-composer` and reproduces with any Niri window rule.

Upstream fixed the focus hand-back in the `v0.8.3` release, and no Fedora 44
repository carries it yet. MyUnix does not put a locally built binary into the
one-click installation path; use the repair instead:

```bash
./scripts/myunix fix
# Niri + DMS session -> XWayland Steam popups (xwayland-satellite 0.8.3)
```

The repair downloads the `xcb-util` `-devel` build dependencies into a
temporary sysroot, builds the pinned upstream tag with
`cargo install --git ... --tag v0.8.3 --locked`, installs the result to
`/usr/local/bin/xwayland-satellite`, and reports its SHA-256 next to the
reference build. `/usr/local/bin` precedes `/usr/bin` in the Niri session PATH,
so the override wins while the Fedora package stays installed and untouched as
the fallback. It never installs build dependencies system-wide, and it removes
the temporary sysroot when it finishes.

Log out and back into Niri to replace the running satellite process, then
restart Steam so its X11 clients reconnect. When Fedora ships a satellite
release at or above 0.8.3, the diagnosis reports that the package already
carries the fix and no override is required.

A related package, `xwaylandvideobridge`, arrives with `plasma-workspace`. It
hides its helper window with the X11 EWMH opacity hint, which
`xwayland-satellite` does not implement, and Niri then tiles an unclosable
black window. `modules/niri-dms` reproduces the intended invisibility with a
`window-rule` for that app ID; see
[Niri + DMS](niri-dms.md#optional-kdeplasma-application-menu).
