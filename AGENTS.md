# MyUnix maintenance contract

This repository is the reproducible Fedora GNOME migration source of truth.

This is repository-local guidance: it governs work performed from this
repository. Put personal defaults shared across repositories in
`~/.codex/AGENTS.md`. Neither location monitors the operating system or runs
exports automatically; use a separately configured systemd timer, cron job, or
Codex automation when scheduled collection is needed.

## Maintenance rules

- Keep the repository current whenever a managed package, RPM source, GNOME shortcut, or input-method setting changes. Update the owning manifest or exported configuration and its documentation in the same change.
- Keep modules isolated: system bootstrap, DNF packages, downloaded RPMs, GNOME settings, input methods, and exporting must not absorb each other's responsibilities.
- Do not commit SSH keys, browser profiles, cookies, tokens, passwords, private keys, or other account data. Review staged diffs for secrets before every commit.
- Downloaded RPM entries must use HTTPS, include a pinned SHA-256 checksum, and be installed from a temporary directory only. Do not keep RPM binaries in the repository.
- Keep privileged work explicit. Only repository setup and package installation may use `sudo`; GNOME and input-method user settings must run as the target desktop user.
- Preserve idempotence: a module may be re-run without corrupting configuration. Record run state only below `~/.local/state/myunix/`, never in Git.
- For every new optional application, add its prompt metadata, installation source, verification command, and user-facing documentation.
- Before committing shell changes, run the project test suite, `bash -n` for every script, and ShellCheck when available. Keep README command examples aligned with the CLI.

## Change discipline

1. Make the smallest coherent module change.
2. Update the matching manifest/configuration and documentation.
3. Run validation and record any Fedora-version or desktop-session prerequisite.
4. Commit an atomic change with a descriptive message.
