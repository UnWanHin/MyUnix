# DMS Plugin and Zsh Personalization Synchronization Design

## Status

Approved in conversation.

## Goal

Make a fresh Fedora migration restore the visible DMS desktop and the reviewed
Zsh experience without copying identity, credentials, histories, device
pairing, display state, or other machine-local data.

## DMS first-install behavior

The existing categorized DMS settings remain the source of truth for the bar,
dock, appearance, frame, and time/weather preferences.  The installer must
create `~/.config/DankMaterialShell/settings.json` as a private empty JSON
object when DMS has not created it yet, then merge the reviewed categories.
Existing settings retain their unknown local keys and are backed up only when
they are changed.  A new file has no previous state to back up.

## DMS plugins

Plugin revisions are captured in `modules/niri-dms/config/dms/plugins.lock.json`
using `dms plugins lock`.  Installation restores that lock after DMS itself is
installed; the small public plugin ID manifest remains a fallback when no lock
is available.  This avoids silently receiving a different plugin revision on a
new machine.

Only the public `dankActions` section of DMS `plugin_settings.json` is
portable.  Its reviewed actions are exported to a separate allowlisted JSON
file and shallow-merged on import.  The KDE Connect selected-device identity,
plugin metadata, caches, first-launch state, monitor configuration, Firefox
CSS, and every unlisted plugin setting stay local.

## Shell layers

`shell-config` continues to own portable Bash/Zsh-neutral aliases,
functions, and environment fragments.  It becomes part of `install --all`.
A separate `zsh-personalization` module owns only:

- pinned public Git source definitions for Oh My Zsh, Powerlevel10k,
  zsh-autosuggestions, and zsh-syntax-highlighting;
- a marker-delimited Oh My Zsh block in `~/.zshrc`; and
- the reviewed `~/.p10k.zsh` presentation file.

The module never clones an arbitrary URL, copies a whole `.oh-my-zsh` tree,
or imports shell history, NVM, Ubuntu-only hooks, credentials, or tokens.
It checks out the exact approved commits from the manifest and manages only
the named theme/plugin paths below the standard Oh My Zsh custom directory.

## Testing and recovery

Shell tests use temporary homes and stubs; they never fetch from the network.
They prove a missing DMS settings file gains the bar settings, existing files
are merged safely, plugin locks are restored, and Zsh marker blocks remain
idempotent.  Changed user files are backed up under
`~/.local/state/myunix/backups/` before replacement.
