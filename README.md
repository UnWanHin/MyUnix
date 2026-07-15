# MyUnix — Fedora GNOME migration

Recreate a Fedora GNOME workstation with modular, reviewable scripts. The repository manages software sources, selected GNOME shortcuts and public input-method configuration; it never stores SSH keys, credentials, tokens or browser profiles.

## On the old Fedora machine

```bash
./scripts/myunix doctor
./scripts/myunix export
git add modules && git commit -m 'chore: export Fedora settings'
```

Review the generated DNF candidate list and GNOME/input-method exports before committing.

## On the new Fedora GNOME machine

```bash
./scripts/myunix doctor
./scripts/myunix install          # menu: all, custom, retry, rerun
./scripts/myunix install --all    # default modules, no prompts
./scripts/myunix install --guided # choose modules and optional RPM apps
./scripts/myunix install --module gnome
./scripts/myunix install --module input-method
./scripts/myunix install --module niri-dms
./scripts/myunix install --module shell-config
./scripts/myunix install --module phone-connect
./scripts/myunix retry
```

`--guided` asks about the optional Niri + DMS, shared shell configuration and
Phone Connect modules after the GNOME baseline. `--all` deliberately keeps the
conservative GNOME-safe baseline and does not install Niri/DMS or replace the
login manager. The greeter replacement is always a separate guarded command.

Direct RPM applications are declared in `modules/rpm/apps.tsv`. Add only official HTTPS sources with a pinned SHA-256; packages are downloaded to a temporary directory with `wget`, verified, installed through DNF, and removed. See [module documentation](docs/modules/) for details.

After installing or importing input methods, log out and back in to let the active GNOME or Niri session reload its input-method services. The optional [shared shell configuration](docs/modules/shell-config.md) module manages portable Bash/Zsh settings through `~/.config/.sysrc` without mixing them into Niri's KDL configuration. [Phone Connect](docs/modules/phone-connect.md) recreates KDE Connect software and Niri startup without exporting paired-phone data.

For a navigable overview of the migration system, open this repository as an
Obsidian vault and start at the [Obsidian migration graph](docs/obsidian/README.md).
