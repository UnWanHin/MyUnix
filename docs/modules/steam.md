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
