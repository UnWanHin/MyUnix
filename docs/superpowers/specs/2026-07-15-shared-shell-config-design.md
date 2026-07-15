# Shared shell configuration design

**Status:** approved in conversation; awaiting written-spec review

## Goal

Manage public, portable Bash/Zsh settings through one user entry point:
`~/.config/.sysrc`.  The entry point loads small category files from
`~/.config/sysrc.d/`, so a future workstation can recreate the shared shell
environment without mixing it with Zsh-only presentation settings or Niri KDL.

## Boundaries

- `~/.config/.sysrc` is the only shared file sourced directly by both
  `~/.bashrc` and `~/.zshrc`.
- `~/.config/sysrc.d/` holds POSIX-shell fragments.  Initial categories are
  `env.rc`, `aliases.rc`, and `functions.rc`.
- `env.rc` may contain safe, common `export` statements such as PATH additions,
  editor preference, and shell-session input-method variables.  It must not
  contain secrets, credentials, tokens, private keys, shell history, or
  machine-specific device paths.
- `aliases.rc` and `functions.rc` contain only Bash/Zsh compatible syntax.
- Oh My Zsh, Powerlevel10k, Zsh plugins, Bash completion, and NVM stay in their
  respective existing rc files; the shared system does not replace them.
- Niri remains KDL below `~/.config/niri/`.  Niri must not source shell code.
  Its Wayland session environment stays in its explicit `environment {}` block,
  synchronized only where documented (for example Fcitx settings).

## Repository module

Create a `shell-config` module with one responsibility: import/export reviewed
public shared-shell files and install one idempotent source stanza in each
selected shell rc file.

```text
modules/shell-config/
  install.sh                 # imports files and manages source stanzas
  export.sh                  # exports reviewed public files for migration
  config/
    .sysrc
    sysrc.d/
      env.rc
      aliases.rc
      functions.rc
docs/modules/shell-config.md
tests/test_shell_config.sh
```

The importer copies from `modules/shell-config/config/` to `~/.config/`, backs
up replaced files and edited rc files below
`~/.local/state/myunix/backups/shell-config/<timestamp>/`, and replaces a
marker-delimited MyUnix source stanza rather than appending duplicates.  It
does not delete unmanaged files in `~/.config/sysrc.d/`.

The exporter copies only `.sysrc` and reviewed `sysrc.d/*.rc` fragments back
to the module directory.  It rejects unsupported file names and does not
export secrets or whole home-directory rc files.

## Source stanza

The generated blocks in `.bashrc` and `.zshrc` are equivalent to:

```sh
# >>> MyUnix shared shell configuration >>>
[ -r "$HOME/.config/.sysrc" ] && . "$HOME/.config/.sysrc"
# <<< MyUnix shared shell configuration <<<
```

`.sysrc` is quiet and tolerant of absent optional fragments.  It determines
its own directory at runtime, then sources the fixed ordered allowlist:
`env.rc`, `aliases.rc`, `functions.rc`.

## Safety and verification

- Configuration installation is user-scoped and never uses `sudo`.
- All file operations are idempotent and preserve backups before replacement.
- Shell tests cover source-stanza insertion/replacement, no duplicate blocks,
  backup creation, safe fragment import/export, and leaving Niri KDL untouched.
- Before completion run the project test suite, `bash -n` for scripts, and
  ShellCheck when it is installed.

## User workflow

After installation, add portable personal settings by editing the category
file that owns them, then run `./scripts/myunix export` to copy reviewed public
settings into this repository.  Re-run
`./scripts/myunix install --module shell-config` on a new machine.
