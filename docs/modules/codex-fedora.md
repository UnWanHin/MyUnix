# Fedora native Codex CLI

The `codex-fedora` module installs Fedora's `nodejs` and `npm` packages, then
installs the current official `@openai/codex` package globally with npm.

It is included in the noninteractive one-click flow:

```bash
./scripts/myunix install --all
```

To install it separately:

```bash
./scripts/myunix install --module codex-fedora
codex --version
codex login
```

The module is host-native and independent of `distrobox-codex`. Re-running it
refreshes the npm package and verifies the resulting executable. MyUnix never
copies `auth.json`, API keys, tokens, SSH keys, or browser credentials; run
`codex login` explicitly on each new machine.
