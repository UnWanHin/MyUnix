# Zsh personalization

This module restores the reviewed Oh My Zsh presentation without copying a
whole home directory. `sources.tsv` pins official GitHub repositories to exact
commits for Oh My Zsh, Powerlevel10k, `zsh-autosuggestions`, and
`zsh-syntax-highlighting`. The installer refuses unmanaged directories and
modified managed checkouts rather than overwriting them.

```bash
./scripts/myunix install --module zsh-personalization
```

It places the sources below the standard `$HOME/.oh-my-zsh` tree, writes one
marker-delimited public block to `~/.zshrc`, and installs the reviewed
`~/.p10k.zsh`. Re-running it is idempotent; changed files are backed up below
`~/.local/state/myunix/backups/zsh-personalization/`.

`./scripts/myunix install --all` includes both `shell-config` and this module.
The shell-neutral aliases/functions remain owned by `shell-config`; this
module does not sync history, NVM, Ubuntu-only hooks, account data, tokens,
private keys, or arbitrary custom plugins.

When [Terminal Tools](terminal-tools.md) is selected, this module's managed
Zsh block also enables fzf key bindings and the `j`/`ji` zoxide commands while
leaving Oh My Zsh's existing `z` plugin intact.

Use `./scripts/myunix export` to copy only the reviewed Powerlevel10k file back
to the repository. Source revisions are updated deliberately by changing the
manifest after reviewing the upstream commit; no unpinned network checkout is
performed.
