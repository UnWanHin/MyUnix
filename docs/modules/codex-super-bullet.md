# Codex SuperBullet

SuperBullet is a user-level Codex operating policy for substantive coding,
build, debugging, migration, and system-configuration work. It is separate
from `distrobox-codex`: the latter provisions Codex inside Ubuntu 22.04,
whereas this module configures the host Codex session and can be reused from
any project path.

Install it on Fedora with:

```bash
./scripts/myunix install --module codex-super-bullet
```

The module writes only public templates and a launcher:

- `${CODEX_HOME:-$HOME/.codex}/AGENTS.md` — default-on policy and truthful
  output rules;
- `${CODEX_HOME:-$HOME/.codex}/super-bullet.config.toml` — a profile layered by
  `codex -p super-bullet`, selecting `gpt-5.6-luna` at maximum reasoning and
  enabling the verified `multi_agent` feature;
- `${CODEX_HOME:-$HOME/.codex}/skills/super-bullet/SKILL.md` — reusable mode
  reference;
- `$HOME/.local/bin/super-bullet` — command-line entry point.

The profile inherits the existing base provider and stored auth. No key,
`auth.json`, browser profile, SSH key, or token is copied or synchronized.
The global policy is always loaded from `AGENTS.md`; use the launcher when you
need to guarantee that the executor is actually Luna rather than merely
assuming the base Codex model.

## Launcher

```bash
super-bullet run                         # interactive Luna execution
super-bullet exec "run the tests"        # Luna, then read-only Sol review
super-bullet review                       # Sol-only read-only review
MYUNIX_SUPER_BULLET_REVIEW_EFFORT=max \
  super-bullet review
```

The launcher prints `SuperBullet: active — Luna execution` only before a real
Luna phase and `SuperBullet: active — Sol validation` only before a real Sol
review. A failed Luna phase skips the review and returns Luna's status. If Luna
creates commits, Sol reviews the exact range from the pre-task `HEAD`; otherwise
it uses the uncommitted worktree. Sol is invoked with `gpt-5.6-sol`, high/max
reasoning, and `--disable multi_agent`; it never edits or auto-fixes findings.
This Codex CLI does not allow a custom prompt together with `--uncommitted`, so
`super-bullet review` intentionally takes no prompt.

## Conversation override

The global policy is enabled by default for substantive work. Say `关闭
SuperBullet` or `停用 SuperBullet` to disable it for the current turn or
conversation; say `开启 SuperBullet` to enable it again. Simple explanations
and ordinary read-only questions must not claim SuperBullet activity.

Existing `AGENTS.md` content is preserved. Re-running the module replaces only
the managed SuperBullet block and keeps a timestamped copy of replaced files
under `${XDG_STATE_HOME:-$HOME/.local/state}/myunix/backups/codex-super-bullet/`.
