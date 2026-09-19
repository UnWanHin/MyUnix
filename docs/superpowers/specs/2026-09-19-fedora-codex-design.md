# Fedora Native Codex CLI Design

## Goal

Make the Fedora host's official npm Codex CLI reproducible through MyUnix's
one-click installation. Ubuntu/Distrobox Codex remains a separate module and
is not changed by this feature.

## Design

Add an isolated `codex-fedora` module with a Fedora package manifest for
`nodejs` and `npm`. The module runs `npm install --global --no-audit --no-fund
@openai/codex` through the existing retry/timeout wrapper, then verifies the
`codex` command. Re-running refreshes the npm package.

The module is included in `install --all` before `codex-super-bullet`, so the
SuperBullet launcher has a native executable. It never copies credentials,
`auth.json`, API keys, or tokens; users run `codex login` themselves.

## Verification

- Stubbed shell test covers DNF, npm, and Codex verification.
- CLI and one-click-flow tests cover module dispatch and ordering.
- Run all tests, shell syntax checks, and a staged secret review.
