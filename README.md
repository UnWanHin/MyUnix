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
./scripts/myunix install --module time-sync
./scripts/myunix install --module development-toolchain
./scripts/myunix install --module distrobox
./scripts/myunix install --module distrobox-ros2-humble
./scripts/myunix install --module distrobox-codex
./scripts/myunix retry
```

The first menu uses `↑`/`↓` to move, `Space` to toggle a choice and `Enter` to
confirm. One-click installs the conservative GNOME-safe baseline with the
English keyboard, Cangjie 5, Pinyin, and [Steam](docs/modules/steam.md) from
RPM Fusion. Custom installation first configures input methods, then offers
optional Steam, Niri + DMS, and Development Toolchain screens. `--all` is the
noninteractive equivalent of one-click. Neither path installs Niri/DMS or
replaces the login manager; the [greeter replacement](docs/modules/niri-dms-greeter.md)
is always a separate guarded command.

The baseline also configures [system time synchronization](docs/modules/time-sync.md): it installs Fedora's
`chrony`, enables the time service, corrects the clock, and stores the hardware clock in UTC without changing
the new computer's existing timezone.

For a scripted input-method choice, pass the selected capabilities explicitly:

```bash
MYUNIX_INPUT_CANGJIE=1 MYUNIX_INPUT_PINYIN=0 ./scripts/myunix install --module input-method
MYUNIX_TOOLCHAIN_SCOPE=user MYUNIX_TOOLCHAIN_COMPONENTS=jdk,cmake,anaconda \
  ./scripts/myunix install --module development-toolchain
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

Steam is deliberately separate from direct RPM applications: it is installed
from RPM Fusion by DNF and receives a user-level Niri compatibility launcher
with `-system-composer`.

The optional [Portal Login](docs/modules/portal-login.md) module adds the
NetworkManager tray applet to Niri/DMS and a generic **Wi-Fi Login** entry in
DMS Spotlight. It detects the current network's captive-portal page, then
opens it only after you select **Open sign-in page** in its notification; it
stores no Wi-Fi credentials or per-network redirect URLs.

The optional [Distrobox](docs/modules/distrobox.md) module installs only the
Fedora Distrobox package. It does not create a distribution, pull an image or
choose a container mirror.

For container-native Codex used with ROS and other Ubuntu-only toolchains, use
`./scripts/myunix install --module distrobox-codex`; it stores container
configuration under `/opt/distrobox/ubuntu22/.codex` and never copies
credentials from Fedora.

After installing or importing input methods, log out and back in to let the active GNOME or Niri session reload its input-method services. The optional [shared shell configuration](docs/modules/shell-config.md) module manages portable Bash/Zsh settings through `~/.config/.sysrc` without mixing them into Niri's KDL configuration. [Phone Connect](docs/modules/phone-connect.md) recreates KDE Connect software and Niri startup without exporting paired-phone data.

For a navigable overview of the migration system, open this repository as an
Obsidian vault and start at the [Obsidian migration graph](docs/obsidian/README.md).
