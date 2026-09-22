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

## Repairing the runtime

Choose **Development tools → Fedora native Codex CLI** in the interactive
`./scripts/myunix fix` menu when `node`, `npm`, or `codex` is missing. The
repair reuses this module's installer after showing a diagnosis and plan. It
checks commands only; it never reads or changes `~/.codex/auth.json`, provider
settings, login state, or browser credentials.
