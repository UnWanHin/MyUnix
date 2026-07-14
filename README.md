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
./scripts/myunix retry
```

Direct RPM applications are declared in `modules/rpm/apps.tsv`. Add only official HTTPS sources with a pinned SHA-256; packages are downloaded to a temporary directory with `wget`, verified, installed through DNF, and removed. See [module documentation](docs/modules/) for details.

After installing or importing input methods, log out and back in to let GNOME reload the input-source services.
