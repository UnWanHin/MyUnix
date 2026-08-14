# JetBrains project launcher design

## Status

Approved for implementation review.

## Goal

Provide one portable Bash/Zsh command, `jet`, that opens a directory in a
locally installed JetBrains IDE.  The selection must reflect installed IDEs at
the time of invocation and remember the last IDE used for each directory.

## Scope

- Define `jet` in the shared `functions.rc` fragment so it is available in
  Bash and Zsh after the Shell Config module is installed.
- Discover executable JetBrains launchers afresh on every invocation.
- Prefer the JetBrains Toolbox launcher directory and also inspect standard
  manual-install launcher locations.  Optional extra roots are supplied with
  an environment variable rather than a user-name-specific repository path.
- Present numbered choices.  If the target directory has a previously used,
  still-available IDE, present it first as `(last)` and accept an empty Enter
  as that selection.
- Persist only per-directory launcher identity under
  `~/.local/state/myunix/jetbrains/`; this state is intentionally not exported
  or committed.
- Add `alias jetcode=jet` as a discoverable compatibility spelling while
  keeping `jet` as the primary command.

## Non-goals

- Do not install, remove, update, or configure JetBrains IDEs.
- Do not store project contents, credentials, recent-file history, or an IDE
  list in Git.
- Do not modify shell-specific Oh My Zsh, completion, or Toolbox settings.

## Interface

```text
jet [DIRECTORY]
jetcode [DIRECTORY]
```

`DIRECTORY` defaults to the current directory and is resolved to a physical
absolute path before it is passed to the selected launcher.  The function
prints a numbered menu of detected IDEs.  The user enters a number; when a
valid remembered choice exists, pressing Enter chooses it.  Invalid input does
not launch an IDE and explains the valid choices.

## Discovery and state flow

1. Discover executable launchers from the Toolbox scripts directory on every
   call, then discover executable `bin/*.sh` launchers below standard manual
   JetBrains user and system roots.  The Toolbox app tree is not recursively
   scanned because it contains internal helper scripts that are not project
   launchers.  An optional colon-separated `MYUNIX_JETBRAINS_PATHS` extends
   the search roots for manual installations.
2. Deduplicate launchers by their resolved executable path and derive labels
   from JetBrains `product-info.json` metadata when available.  Include the
   product version in the label so parallel versions remain distinguishable;
   otherwise fall back to the launcher and installation-directory names.  Sort
   labels deterministically.
3. Derive a safe hash from the resolved target directory and read the matching
   state file, if present.  Its content is only the selected launcher path.
4. If that launcher is still discovered, move it to menu item 1 and mark it
   `(last)`.
5. Run the selected launcher with the resolved directory, then write state
   only after the launcher accepts the invocation.

## Error handling

- A nonexistent or non-directory target fails before discovery.
- If no launcher is found, the command explains where it searched and how to
  install a Toolbox command or set `MYUNIX_JETBRAINS_PATHS`.
- A stale remembered launcher is ignored and replaced after a successful new
  selection.
- A cancelled prompt or invalid menu value leaves the previous state intact.

## Testing

Focused shell tests will use temporary fake launchers and state directories to
prove dynamic discovery, remembered-choice ordering, blank-Enter selection,
stale-state fallback, and no-launch behavior for invalid choices.  Existing
shell-config tests continue to verify export/import boundaries.

## Portability and privacy

All repository content uses `$HOME`, XDG paths, and runtime discovery; it does
not encode `hiraeth`, a local IDE version, or a local installation path.  The
per-directory state is local to the machine and is not part of MyUnix export.
