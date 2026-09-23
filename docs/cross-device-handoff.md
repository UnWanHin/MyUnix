# Cross-device handoff

MyUnix uses the `fedora` branch as the portable source of truth. The safe
workflow is always:

```text
active machine: export → review → commit → push
replacement machine: pull/clone → doctor → install
```

The repository is private, so the target machine needs GitHub access before it
can clone or pull. Use an already configured SSH key, or authenticate with
`gh auth login` and clone over HTTPS. Never copy `~/.ssh`, `~/.codex/auth.json`,
browser profiles, cookies, application logins, or subscription URLs into this
repository.

## First machine: publish the current workstation

Run this from the MyUnix checkout on the machine whose public settings should
become the shared baseline:

```bash
cd ~/Documents/Github/Projects/MyUnix
./scripts/myunix doctor
./scripts/myunix export
git diff -- modules docs tests
git status --short
git add modules docs tests README.md
git commit -m 'chore: export Fedora workstation settings'
git push origin fedora
```

`export` updates only the owning, reviewed module files. Always inspect the
diff and remove anything that is not portable before committing. The exported
DNF package and repository files are review snapshots; curate them into the
appropriate manifest instead of blindly installing every package ever seen on
the machine.

## Second machine: restore the shared baseline

For a new machine, clone the private branch and run the non-interactive
baseline install:

```bash
git clone -b fedora git@github.com:UnWanHin/MyUnix.git ~/MyUnix
cd ~/MyUnix
./scripts/myunix doctor
./scripts/myunix install --all
```

`install --all` is idempotent: rerunning it checks installed DNF packages,
reuses existing managed files with backups where needed, and does not copy
credentials. After importing input methods or session startup settings, log
out and back in once. If a module failed, use:

```bash
./scripts/myunix retry
```

If a repair is needed, use the confirmation-gated menu:

```bash
./scripts/myunix fix
```

## Bringing changes back to the first machine

After changing portable settings on the second machine, publish them with the
same export/review flow:

```bash
cd ~/MyUnix
./scripts/myunix export
git diff -- modules docs tests
git add modules docs tests README.md
git commit -m 'chore: export Fedora workstation settings'
git push origin fedora
```

Then update the first machine without overwriting uncommitted work:

```bash
cd ~/Documents/Github/Projects/MyUnix
git status --short
git pull --ff-only origin fedora
./scripts/myunix doctor
./scripts/myunix install --all
```

If `git status --short` is not empty, review or commit those local changes
before pulling. Resolve Git conflicts manually; do not use a destructive reset
to discard workstation settings.

## What is and is not synchronized

Portable public configuration includes reviewed DNF/RPM manifests, GNOME
shortcuts, Fcitx/IBus settings, Niri/DMS shortcuts and themes, Kitty and shell
fragments, Powerlevel10k configuration, and selected public KDE Connect/Niri
integration. Package installation is represented by manifests, not copied
installed binaries.

Machine-specific or private state stays local: monitor modes and positions,
DMS generated runtime files, JetBrains per-directory history, phone pairing
identities, Wi-Fi credentials, FlClash profiles/subscriptions, WeChat login
and chat data, Codex authentication, SSH keys, browser profiles, cookies and
tokens. A successful export must never contain those values.
