# Phone Connect design

**Status:** approved in conversation; awaiting written-spec review

## Goal

Add a reproducible Fedora Niri + DMS Phone Connect module using KDE Connect,
the backend supported by the installed DMS Phone Connect plugin. The module
recreates software and desktop-session integration without exporting paired
devices, transferred files, trust data, or private keys.

## Boundaries

- Use Fedora's `kdeconnectd` package as the desktop service. Do not use
  Valent, because its documented SFTP route requires SSH-agent configuration
  that is outside this workstation's no-key-migration scope.
- Offer `kde-connect-nautilus` as the optional Nautilus integration package.
- The Niri integration is a separate fragment at
  `~/.config/niri/myunix/kdeconnect.kdl`. It starts `kdeconnectd` at login.
  The phone-connect module owns this fragment; it does not edit DMS-generated
  `dms/*.kdl` files.
- Niri's managed base config includes the fragment with `optional=true`, so
  the Niri+DMS module can be reinstalled without removing the integration.
- If firewalld is active, the installer asks explicitly before opening the
  KDE Connect LAN range `1714-1764/tcp` and `1714-1764/udp`. Noninteractive
  execution requires `MYUNIX_CONFIRM_KDECONNECT_FIREWALL=allow`; any other
  value skips firewall mutation and prints pairing guidance.
- Package installation and the approved firewall change may use `sudo`.
  Niri configuration and verification always run as the desktop user.

## Module layout

```text
modules/phone-connect/
  packages.txt                    # Fedora core and optional package records
  install.sh                      # install, user config, firewall confirmation
  export.sh                       # exports only public reviewed fragment
  config/niri/myunix/kdeconnect.kdl
docs/modules/phone-connect.md
tests/test_phone_connect.sh
```

The CLI exposes the module only through
`./scripts/myunix install --module phone-connect`. It is excluded from default
`install --all`, since it opens LAN reachability only after a dedicated user
confirmation.

## Installation flow

1. Install `kdeconnectd`.
2. In guided mode, ask whether to install `kde-connect-nautilus`; allow the
   environment variable `MYUNIX_PHONE_CONNECT_NAUTILUS=1` to select it without
   interaction.
3. Copy the Niri fragment, backing up a replaced fragment below
   `~/.local/state/myunix/backups/phone-connect/<timestamp>/`.
4. Ensure the base Niri config has exactly one optional include for the
   fragment, preserving all other content and backing up the file before a
   change.
5. If `firewalld` is active, obtain explicit approval before applying the two
   permanent port-range rules and reloading the firewall. If unavailable or
   declined, do not fail the module; tell the user that discovery/pairing may
   fail until the LAN ports are allowed.
6. Verify `kdeconnectd` and `kdeconnect-cli` are available, then tell the user
   to log out/in to Niri and pair the phone from the KDE Connect mobile app on
   the same local network.

## Export and privacy

The exporter copies only the public Niri fragment back to the module source.
It never exports KDE Connect device identities, pairing certificates, incoming
files, clipboard data, notification data, SMS data, or SSH-related material.
Pairing is deliberately performed per machine after migration.

## Verification

- Shell tests prove package selection, Niri fragment backup/import, exactly
  one include after re-runs, and firewall confirmation gating.
- Tests stub `sudo`, `dnf`, `firewall-cmd`, and system commands so no test
  changes the host firewall.
- Completion requires the project suite, Bash syntax checks, ShellCheck when
  available, and a documented post-install verification command:
  `kdeconnect-cli -l`.

## Sources

- DMS Phone Connect plugin: <https://github.com/AvengeMedia/dms-plugins/tree/master/DankKDEConnect>
- KDE Connect community documentation: <https://community.kde.org/KDEConnect>
- DMS plugin source records the required LAN range as TCP/UDP `1714-1764`.
