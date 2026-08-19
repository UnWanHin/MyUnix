# ChatGPT Desktop and GitHub CLI Optional Install Design

## Status

Approved on 2026-08-19.

## Context

The Fedora workstation now uses two additional developer-facing applications:

- ChatGPT desktop for Linux, which contains the Codex desktop workspace and is
  distributed by OpenAI as a signed x86_64 RPM.
- GitHub CLI (`gh`), which is distributed by the Fedora `updates` repository.

Both are useful on this workstation but must not be installed by MyUnix's
one-click baseline. The repository must remain safe to publish: GitHub CLI
tokens, ChatGPT account data, browser data, system keyring entries, SSH keys,
and user names are all local state and are excluded from Git.

## Decision

Expose both applications only in the custom installation flow.

### GitHub CLI

- Keep `gh` in a DNF-owned manifest because Fedora supplies and updates it.
- Show it as a named optional developer application in the custom installer.
- Verify installation with `gh --version`.
- Document `gh auth login` as a user-owned, post-install action. Do not attempt
  to export, import, or configure authentication material.

### ChatGPT desktop / Codex App

- Keep the desktop app in `modules/rpm/apps.tsv` because OpenAI distributes an
  official RPM outside Fedora repositories.
- Pin the currently verified official HTTPS download and SHA-256. The existing
  RPM installer already downloads only to a temporary directory, verifies the
  digest, invokes DNF, and deletes the package.
- Verify its RPM identity with `rpm -q chatgpt`.
- Record that the first installation creates OpenAI's signed DNF repository.
  Later package updates use its installed OpenPGP key; MyUnix does not add a
  broad third-party repository itself.
- Document the Wayland/Fcitx note separately as an operational prerequisite,
  not as an unverified automatic launch flag.

## Installer behaviour

Custom installation asks for desktop applications in one selection screen:

- Steam
- ChatGPT desktop (includes Codex)
- GitHub CLI

The selected applications run after the core baseline. A failed selection uses
the existing retry, skip/defer, and stop behaviour. `--all` remains unchanged:
it installs neither ChatGPT desktop nor GitHub CLI.

## Tests and verification

- Extend the RPM manifest test to require the ChatGPT record's official HTTPS
  URL, 64-character SHA-256, optional status, and `chatgpt` verification.
- Extend the installer-flow tests to prove the custom selection invokes only
  the chosen optional applications and that the one-click path excludes both.
- Extend the DNF manifest/doctor coverage for `gh`.
- Run the project test suite, `bash -n` for every shell script, ShellCheck when
  available, staged secret review, and a local `gh --version` / `rpm -q
  chatgpt` verification before commit.

## Alternatives considered

### Add both to one-click installation

Rejected because the desktop package uses about 1 GiB installed and neither
application is a universal migration prerequisite.

### Manage ChatGPT only through the generated OpenAI DNF repository

Rejected because first-time installation would depend on a repository file
created outside MyUnix. The pinned official RPM makes the initial bootstrap
auditable and reproducible; the official signed repository then handles normal
updates.

### Export authenticated state

Rejected because tokens, keyring records, cookies, and SSH credentials are
private account material and must never enter the migration repository.
