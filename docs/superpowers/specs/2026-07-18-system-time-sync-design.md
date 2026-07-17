# System Time Sync Design

## Context

The workstation clock was almost eight hours ahead of the configured NTP
source because the hardware RTC was stored as local time and the large offset
had not been stepped. DMS weather location and system time were initially
treated as the same concern, but they are independent: DMS Auto Location uses
the current external IP, while the desktop clock uses Fedora's system clock and
timezone.

## Decision

Add an optional `time-sync` MyUnix module for Fedora. It will:

1. Install the Fedora `chrony` package through the existing DNF manifest
   mechanism.
2. Enable and start `chronyd`, wait briefly for a usable source, then request
   a one-time `chronyc makestep` correction.
3. Store the hardware RTC in UTC with `timedatectl set-local-rtc 0`.
4. Preserve the machine's existing timezone. It must not infer or overwrite a
   timezone from an IP address, VPN exit, Wi-Fi network, DMS setting, or a
   location name.

The module runs privileged commands explicitly through `sudo`. It records only
its outcome below `~/.local/state/myunix/`; it does not save system clock data,
network identifiers, IP addresses, DMS session state, or credentials in Git.

## DMS Behavior

DMS Time & Weather settings may select a 12-hour or 24-hour display format.
They do not set Fedora's timezone or NTP source. DMS Auto Location remains a
weather-only preference that resolves the active external IP and can therefore
be affected by VPN routing. A VPN must not affect the system clock or timezone.

## Portability

The module has no user-name-specific paths. System actions target `chronyd` and
`timedatectl`; state uses `$HOME/.local/state/myunix/` through the existing
state helper. Tests inject command stubs and an arbitrary temporary `HOME` to
prove that installation does not depend on the local account name.

## Error Handling

Failure to install or start `chronyd` fails the module. A failed `waitsync` or
`makestep` reports an actionable error and does not silently claim correction.
The RTC conversion is performed only after successful clock correction. The
module is idempotent: rerunning it leaves a synchronized service enabled and an
UTC RTC unchanged.

## Verification

The test suite will verify the command sequence, Fedora DNF manifest coverage,
timezone preservation, UTC RTC selection, and the absence of user-name-specific
paths. Documentation will distinguish automatic NTP correction from DMS's
IP-based weather location.
