# Terminal productivity tools

Install this optional module on Fedora with:

```bash
./scripts/myunix install --module terminal-tools
```

It uses Fedora DNF for `fzf`, `tmux`, `mosh`, `zoxide`, `bat`, `btop`,
`ripgrep`, `fd-find` (command `fd`) and `git-delta` (command `delta`). Fedora
does not currently package lazydocker, so the module downloads the official
`jesseduffield/lazydocker` v0.25.2 x86_64 release, verifies the pinned SHA-256,
extracts only its executable in a temporary directory and installs it at
`/usr/local/bin/lazydocker`. The module refuses to replace an existing
unmanaged `lazydocker` executable.

The Zsh personalization block enables fzf's packaged key bindings and
initializes zoxide as `j` so it does not override Oh My Zsh's existing `z`
plugin. Run `./scripts/myunix install --module zsh-personalization` if the
managed block has not been refreshed, then start a new terminal. `Ctrl-R`
opens fuzzy history search, `Ctrl-T` inserts selected file paths and `Alt-C`
fuzzy-jumps to a directory. Use `j query` to jump to a frequently visited
directory and `ji query` to choose among matches interactively.

| Tool | Everyday use | Compared with Zsh / Oh My Zsh |
| --- | --- | --- |
| `fzf` | `Ctrl-R`, `Ctrl-T`, `Alt-C` | Adds interactive fuzzy filtering; Zsh globbing and completion remain available. |
| `tmux` | `tmux new -s work`; detach `Ctrl-B`, `D`; `tmux attach -t work` | Persistent panes and sessions; independent of the shell. |
| `mosh user@host` | Remote shell that survives roaming and sleep | Complements SSH; SSH authenticates first, then mosh uses UDP. |
| `zoxide` | `j proj` or `zi proj` | Frecency navigation is more forgiving than `cd`; exact Zsh completion still wins for known paths. |
| `bat file` | Highlighted, numbered file output | A readable `cat` alternative, not a shell matcher. |
| `btop` | `btop` | Interactive resource/process monitor; unrelated to Zsh. |
| `rg pattern` | Recursive content search respecting ignore files | Searches file contents; Zsh globs select path names. |
| `fd pattern` | `fd config ~/.config` | Simpler file search than `find`; complements globbing. |
| `delta` | `git -c core.pager=delta diff` | Better Git diffs; MyUnix does not change global Git config automatically. |
| `lazydocker` | `lazydocker` | Container TUI, not a shell feature. Officially requires Docker; this host has Podman and no Docker, so a Docker-compatible endpoint may be needed. |

These tools are strongest where Zsh has no native equivalent: fuzzy selection,
persistent terminal panes, resumable remote sessions, content indexing,
resource dashboards and visual Git diffs. They layer on top of Zsh rather than
replacing its patterns, completion or history.

`--all` leaves this optional collection out. Custom installation offers it as
**Terminal productivity tools**. The package ownership for all listed tools,
including `fzf` and `tmux`, lives in this module.
