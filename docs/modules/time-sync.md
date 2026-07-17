# System Time Sync

The baseline MyUnix installation and this standalone command configure Fedora's
clock safely:

```bash
./scripts/myunix install --module time-sync
```

The module installs `chrony` from Fedora, enables `chronyd`, waits for a time
source, corrects the current clock, and stores the hardware RTC in UTC. It
preserves the existing system timezone. It never selects a timezone from an IP
address, VPN, Wi-Fi network, DMS weather location, or city name.

This is a system-level setting and therefore uses explicit `sudo` only for the
DNF transaction, system service, chrony commands, and RTC conversion. It stores
no clock data, network identity, location, account data, or credentials in the
repository or user configuration.

## DMS Time And Weather

DMS **Auto Location** controls weather only and follows the active external IP.
A VPN can change its weather result but cannot change the Fedora system time or
timezone. In DMS, select **13:00** in **Settings -> Time & Weather -> Time
Format** for a 24-hour clock, which displays midnight as `00:57` rather than
`12:57 AM`.
