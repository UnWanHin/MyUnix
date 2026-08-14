# Shared shell configuration

This optional user-level module gives Bash and Zsh one shared entry point:
`~/.config/.sysrc`. Both `~/.bashrc` and `~/.zshrc` receive an idempotent,
marker-delimited source block; the module never replaces their existing
shell-specific configuration.

```text
~/.config/
├── .sysrc
└── sysrc.d/
    ├── env.rc
    ├── aliases.rc
    ├── functions.rc
    └── development-toolchain.rc  # managed by the optional toolchain module
```

`env.rc` owns portable `export` statements, `aliases.rc` owns aliases, and
`functions.rc` owns functions that work in both Bash and Zsh. `.sysrc` loads
all readable `sysrc.d/*.rc` fragments in lexical order, so independent MyUnix
modules can own their own public fragment. Keep each file public and portable:
do not add passwords, tokens, private keys, shell history, browser data, or
machine-specific device paths.

## Install or reapply

```bash
./scripts/myunix install --module shell-config
```

The command copies the reviewed files from `modules/shell-config/config/`,
backs up any replaced shared file or modified rc file under
`~/.local/state/myunix/backups/shell-config/<timestamp>/`, and can be run again
without duplicating the source blocks. It leaves any other files in
`~/.config/sysrc.d/` untouched.

## Export for a future machine

After reviewing your public changes, export the three managed fragments and
the entry point:

```bash
./scripts/myunix export
git diff -- modules/shell-config
```

The exporter copies only `.sysrc`, `env.rc`, `aliases.rc`, and `functions.rc`.
The optional Development Toolchain module supplies its own reviewed fragment;
the shell exporter deliberately does not capture arbitrary extra user
fragments. Review the diff before committing, especially environment values.

## JetBrains project launcher

After this module is installed, `jet` discovers currently available JetBrains
launchers every time it runs. It works with JetBrains Toolbox commands and
standard manual-install locations, so IDEs added or removed later are reflected
without editing MyUnix.

```bash
jet .
jet ~/path/to/project
jetcode .
```

The numbered selector remembers the IDE last used for each project directory.
That entry appears first as `(last)` on the next invocation; press Enter to
reuse it, or enter another number to change it. `jetcode` is an alias for
`jet`.

For a manual installation outside the standard locations, set the optional
colon-separated `MYUNIX_JETBRAINS_PATHS` environment variable to its parent
directory. The local selections are stored below
`${XDG_STATE_HOME:-~/.local/state}/myunix/jetbrains/last/`. They contain only
the chosen launcher path, are not exported by MyUnix, and do not include
project contents or account data.

## Boundaries and recovery

Oh My Zsh, Powerlevel10k, Zsh plugins, Bash completion, and NVM remain in
their shell-specific rc files. Niri is separate: its configuration and Wayland
input-method environment are KDL files under `~/.config/niri/`, managed by the
Niri + DMS module rather than `.sysrc`.

To remove the integration, delete only the lines between the MyUnix shared
shell configuration markers in the relevant `~/.bashrc` or `~/.zshrc`. Restore
a timestamped backup if a manual change needs to be undone.
