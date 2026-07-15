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
./scripts/myunix install          # keyboard menu: one-click or custom
./scripts/myunix install --all    # one-click baseline, no menu
./scripts/myunix install --guided # custom input-method selector (TTY)
./scripts/myunix install --module gnome
./scripts/myunix install --module input-method
./scripts/myunix install --module niri-dms
./scripts/myunix install --module shell-config
./scripts/myunix install --module phone-connect
./scripts/myunix install --module portal-login
./scripts/myunix retry
```

The first menu uses `↑`/`↓` to move, `Space` to toggle a choice and `Enter` to
confirm. One-click installs the conservative GNOME-safe baseline with the
English keyboard, Cangjie 5 and Pinyin. Custom installation currently
customizes only input methods: English stays selected, while Cangjie 5 and
Pinyin can be selected independently. `--all` is the noninteractive
equivalent of one-click. Neither path installs Niri/DMS or replaces the login
manager; the greeter replacement is always a separate guarded command.

For a scripted input-method choice, pass the selected capabilities explicitly:

```bash
MYUNIX_INPUT_CANGJIE=1 MYUNIX_INPUT_PINYIN=0 ./scripts/myunix install --module input-method
```

Each module prints `[current/total]` progress; network operations print their
attempt number and retain native DNF/wget progress. In a terminal, a failed
module offers retry, skip/defer or stop. Deferred and failed modules can later
be rerun with `./scripts/myunix retry`. Noninteractive installation continues
independent modules but exits nonzero if one failed. The defaults are three
attempts, a 30-minute DNF/COPR/plugin timeout and a 10-minute direct-RPM
download timeout. Override them only when necessary:

```bash
MYUNIX_NETWORK_ATTEMPTS=5 MYUNIX_DNF_TIMEOUT_SECONDS=2400 ./scripts/myunix install --all
MYUNIX_DOWNLOAD_TIMEOUT_SECONDS=900 ./scripts/myunix install --module rpm
```

Direct RPM applications are declared in `modules/rpm/apps.tsv`. Add only official HTTPS sources with a pinned SHA-256; packages are downloaded to a temporary directory with `wget`, verified, installed through DNF, and removed. See [module documentation](docs/modules/) for details.

The optional [Portal Login](docs/modules/portal-login.md) module adds the
NetworkManager tray applet to Niri/DMS and a generic **Wi-Fi Login** entry in
DMS Spotlight. It opens the current network's captive-portal page only after
you select it; it stores no Wi-Fi credentials or per-network redirect URLs.

After installing or importing input methods, log out and back in to let the active GNOME or Niri session reload its input-method services. The optional [shared shell configuration](docs/modules/shell-config.md) module manages portable Bash/Zsh settings through `~/.config/.sysrc` without mixing them into Niri's KDL configuration. [Phone Connect](docs/modules/phone-connect.md) recreates KDE Connect software and Niri startup without exporting paired-phone data.

For a navigable overview of the migration system, open this repository as an
Obsidian vault and start at the [Obsidian migration graph](docs/obsidian/README.md).
