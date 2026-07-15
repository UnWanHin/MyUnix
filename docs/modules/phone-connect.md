# Phone Connect (KDE Connect)

This optional module enables the installed DMS Phone Connect plugin through Fedora's KDE Connect service. It works with the KDE Connect mobile app over the same local network; pair each computer and phone separately.

## Install

```bash
./scripts/myunix install --module phone-connect
```

The module installs `kdeconnectd`, copies a Niri startup fragment to `~/.config/niri/myunix/kdeconnect.kdl`, and adds an optional include to the main Niri configuration. Log out and back into Niri after installation, then check discovery and paired devices:

```bash
kdeconnect-cli -l
```

Install Fedora's Nautilus integration at the same time when desired:

```bash
MYUNIX_PHONE_CONNECT_NAUTILUS=1 ./scripts/myunix install --module phone-connect
```

## Firewall confirmation

KDE Connect discovers and communicates with devices on the LAN over TCP and UDP ports `1714-1764`. When firewalld is active, an interactive install asks before opening those ports. For a deliberate noninteractive setup, pass both the confirmation and any optional integration choice explicitly:

```bash
MYUNIX_CONFIRM_KDECONNECT_FIREWALL=allow MYUNIX_PHONE_CONNECT_NAUTILUS=1 ./scripts/myunix install --module phone-connect
```

If you decline or omit the confirmation, no firewall change is made. Pairing may still work on a trusted LAN, but discovery can fail until the relevant firewall rules are allowed.

## Pairing

1. Install KDE Connect on the phone and connect both devices to the same LAN.
2. Open the DMS Phone Connect plugin or KDE Connect on the desktop.
3. Send and accept the pairing request, then approve only the phone permissions you want.

## Migration and privacy

`./scripts/myunix export` exports only the public Niri startup fragment. It never exports device identities, pairing certificates, phone files, clipboard contents, notification/SMS data, or private keys. A new computer intentionally requires a new pairing approval.

The module does not configure Valent, SSH agents, or SSH keys. DMS-generated files under `~/.config/niri/dms/` stay outside this module and are not edited.

Sources: [DMS Phone Connect plugin](https://github.com/AvengeMedia/dms-plugins/tree/master/DankKDEConnect) and [KDE Connect](https://community.kde.org/KDEConnect).
