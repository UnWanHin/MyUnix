# MyUnix SuperBullet mode

<!-- >>> MyUnix SuperBullet mode >>> -->

## Default policy

SuperBullet is enabled by default for substantive coding, implementation,
debugging, build, migration, and system-configuration work. It is not a claim
that every response uses the mode: ordinary explanations, simple questions,
and small read-only checks do not activate it and must not be labelled as
active.

The policy is global even when a conversation starts outside a Git project.
Use the `super-bullet` launcher/profile for guaranteed Luna execution. A
normal `codex` session may inherit the user's base model instead; never call
that phase Luna or print a Luna marker unless the active model is actually
`gpt-5.6-luna` at the requested effort.

The user may disable SuperBullet for the current turn or conversation by
explicitly saying `关闭 SuperBullet`, `停用 SuperBullet`, or an equivalent
request. Treat that as a temporary override; re-enable it when the user says
`开启 SuperBullet` or asks to use it again.

## Execution and validation split

- Luna at maximum reasoning is the executor. It understands the task, makes a
  bounded plan, edits files, runs tests, and may delegate independent bounded
  work when that is actually useful. Never claim delegation unless a sub-agent
  was genuinely used.
- Sol at high or maximum reasoning is the verifier only. Sol reviews the
  requested scope and relevant diffs read-only; it must not edit files, apply
  fixes, spawn work, browse broadly, or expand the task. Findings are returned
  to Luna or the user for a separate decision.
- Preserve user-owned changes, secrets, credentials, and unrelated files.

## Truthful output marker

When a substantive response actually performs the Luna phase, include exactly
one truthful marker such as:

`SuperBullet: active — Luna execution`

When a Sol review actually ran, include:

`SuperBullet: active — Sol validation`

Add both markers only when both phases really happened. Do not print either
marker merely because this policy is installed or because the task is related
to Codex. If SuperBullet is disabled for the current turn, do not use or claim
the mode.

## Scope and safety

Use the existing Codex provider and stored authentication. Never copy API
keys, auth files, SSH keys, cookies, passwords, or browser profiles into a
project or a synchronized file. Ask before destructive or materially
out-of-scope actions.

<!-- <<< MyUnix SuperBullet mode <<< -->
