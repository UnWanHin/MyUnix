# Steam X11 popups and the XWayland satellite override

## Context

Steam's X11 context menus closed about 33 ms after they opened on this
workstation. Investigation on 2026-10-01 used `xev`-style probes, a focus
logger and window-property dumps stored in a scratch directory, and rejected
several hypotheses first: the `-system-composer` launcher workaround, Niri
window rules, Steam's own settings and the display configuration made no
difference, and the same menus worked in a GNOME session.

The cause is `xwayland-satellite` 0.8.2, the package Fedora 44 ships. Its
`require_wm_focus()` re-asserts the X input focus on override-redirect windows
when focus returns to the compositor, so Steam sees a focus loss and dismisses
its own menu. Upstream fixed the focus hand-back in `v0.8.3`
(commit `b83eab900644e4c7c77982ce3d44cb490f0c5e1d`), which is in no Fedora 44
repository: `dnf list --available` shows only 0.8.1 from `fedora` and 0.8.2 from
`updates`.

The binary was built by hand that evening with `cargo install --git
https://github.com/Supreeeme/xwayland-satellite --tag v0.8.3 --locked`. The build
needs the `xcb-util` `-devel` headers, which belong to no MyUnix manifest, and
the session had no root, so the RPMs were unpacked into a temporary sysroot.
The result was installed as `/usr/local/bin/xwayland-satellite`; `/usr/local/bin`
precedes `/usr/bin` in the Niri session PATH, and `~/.local/bin` is not on that
PATH at all. The Steam popups opened normally afterwards.

`plasma-workspace` also weak-depends on `xwaylandvideobridge`, whose helper
window hides itself with the X11 EWMH opacity hint that `xwayland-satellite`
does not implement; Niri tiled it as an unclosable black window.

## Decision

The fix is a repair record, not part of the one-click installation:
`./scripts/myunix fix` → **Niri + DMS session** → **XWayland Steam popups
(xwayland-satellite 0.8.3)**. It is confirmation-gated like every other repair
and is the only repair that builds software.

`fix_apply_xwayland_satellite` downloads the five `xcb-util` `-devel` packages
with `dnf download` and unpacks them into a temporary sysroot, so no build
dependency is installed system-wide. It then points `PKG_CONFIG_PATH`, `CPATH`
and `LIBRARY_PATH` at that sysroot, builds the pinned tag with `--locked` (so
`Cargo.lock` pins every crate) and installs the result to `/usr/local/bin` with
`sudo`. The temporary sysroot is removed on every exit path. The Fedora package
stays installed and untouched as the fallback, and no Niri configuration
changes.

The recorded reference SHA-256 is reported, not enforced: the same locked
source produces different bytes from a different `CARGO_HOME`, `rustc` or
Fedora release, because the binary embeds the registry source paths for its
panic locations. A build on 2026-10-01 from a clean temporary `CARGO_HOME`
reproduced the recipe and produced a different hash for the same pinned tag.

The diagnosis reports healthy as soon as the Fedora package is at or above
0.8.3, so the repair becomes a no-op when Fedora catches up. The video-bridge
black tile is handled separately by the managed `window-rule` in
`modules/niri-dms/config/niri/config.kdl`, because it is a Niri layout
configuration rather than a missing package.

## Consequences

Running the repair needs `cargo`, `dnf`, `rpm2cpio`, `cpio` and `sudo`, and
takes about a minute of compiling. Log out and back into Niri to replace the
running satellite process, then restart Steam so its X11 clients reconnect.

The repair does not remove the Fedora package, so a later `sudo dnf upgrade`
that replaces `xwayland-satellite` with a fixed build simply makes the override
redundant; the diagnosis says so and no cleanup is required. If the override is
ever removed, the machine falls back to the packaged behaviour.
