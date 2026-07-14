# Niri + DMS workstation design

**Status:** approved in conversation; awaiting written-spec review

## Goal

Add Niri + DankMaterialShell (DMS) as a second Fedora desktop session without replacing or modifying the existing GNOME session. Include Kitty, a Nerd Font, Oh My Zsh/Powerlevel10k configuration, and a shared DMS-driven color palette.

## Boundaries

- GNOME remains installed and selectable in GDM. The installer never changes the user's default desktop session.
- Niri/DMS configuration is isolated below `modules/niri-dms/`; it does not reuse GNOME dconf exports.
- DMS is installed through its documented Fedora package path, never through `curl | sh`.
- DMS's documented Fedora package support is limited to Fedora 43/44 at the time of writing. The module must stop before making changes on other releases.
- Kitty, font, Zsh and P10k are user-experience components; package installation may use `sudo`, but configuration import/export must run as the desktop user.

## Module layout

```text
modules/niri-dms/
  install.sh             # Fedora/DMS gate and package orchestration
  export.sh              # copies reviewed Niri, DMS, Kitty and P10k files
  packages.txt           # Niri, Kitty, Hyfetch, fonts, portals and helpers
  config/
    niri/                # exported Niri config
    dms/                 # exported DMS configuration
    kitty/               # kitty.conf and generated palette include
    shell/               # .p10k.zsh and reviewed .zshrc fragment
docs/modules/niri-dms.md
```

## Installation flow

1. Validate Fedora, architecture, a graphical login manager, and Fedora 43/44 support before enabling any DMS source.
2. Install Niri and base Wayland/portal dependencies, then enable the documented stable DMS Fedora source and install DMS/Quickshell.
3. Install Kitty, a Nerd Font, Hyfetch, Zsh, Oh My Zsh prerequisites and Powerlevel10k prerequisites.
4. Install only reviewed configuration files. Existing Niri, DMS, Kitty, `.zshrc` and `.p10k.zsh` files are backed up under `~/.local/state/myunix/backups/niri-dms/`.
5. Present the required post-install steps: select Niri at the GDM session chooser, start DMS through the Niri session configuration, open Kitty and run `p10k configure` once if no tracked P10k configuration exists.

## Theme synchronization

DMS/Matugen is the palette authority. The Niri+DMS module stores a Kitty palette include generated or exported by DMS/Matugen; `kitty.conf` includes that file. Powerlevel10k is configured with compatible foreground, background and accent colors, but remains independent of runtime DMS processes so the shell still works in GNOME or a TTY.

The initial version avoids a fragile custom daemon. A documented refresh command regenerates the Kitty include after a wallpaper or DMS palette change, and users may rerun the module safely.

## Export scope

Export imports only:

- Niri configuration and keybinds;
- DMS configuration and selected theme files;
- Kitty configuration and palette include;
- `.p10k.zsh` plus an allowlisted Oh My Zsh/P10k fragment from `.zshrc`.

It excludes shell history, SSH keys, tokens, browser profiles, private application data and unreviewed Zsh plugins.

## Verification

- Shell tests cover Fedora release gating, no-GNOME-mutation guarantees, backup creation, package source selection and allowlisted shell export.
- A Fedora 43/44 VM smoke test verifies both GNOME and Niri appear in GDM, DMS starts only in Niri, Kitty renders Nerd Font glyphs, and P10k works in Kitty.
- The module must document current package/source URLs and update rules.

## Sources

- DMS Fedora installation: <https://danklinux.com/docs/dankmaterialshell/installation>
- DMS project: <https://github.com/AvengeMedia/DankMaterialShell>
- Niri project: <https://github.com/YaLTeR/niri>
