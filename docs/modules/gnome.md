# GNOME settings

The GNOME module exports and restores only `/org/gnome/settings-daemon/plugins/media-keys/`, including custom keyboard shortcuts. Import saves the current scoped settings under `~/.local/state/myunix/backups/gnome/` before applying the tracked export and never elevates to root.
