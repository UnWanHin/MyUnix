# Captive Portal Feedback and Redirect Design

## Context

The Wi-Fi Login launcher correctly avoids opening a browser when NetworkManager
reports `full` connectivity, but DMS hides its terminal output. After a user
has authenticated, launching it appears to do nothing. Some captive networks
also report `limited` or `unknown` while their portal is still reachable, and
some portal pages use an HTML meta refresh instead of an HTTP Location header
or JavaScript assignment.

The repository's broad `config/` ignore rule had also excluded the portal
helper, desktop entry, and autostart entry. Existing installations still ran
their copied user files, but a clean checkout could not reproduce the module.

## Decision

The launcher remains user initiated. It will never open a browser merely
because a network connects.

When NetworkManager reports `portal`, `limited`, or `unknown`, the launcher
will perform the existing HTTP probe and extract the live portal destination
from one of:

- an HTTP `Location` header;
- JavaScript location assignment;
- an HTML meta refresh URL.

Only HTTP(S) destinations are accepted. A valid destination is passed to
`xdg-open` and a desktop notification reports that the portal is opening.

When connectivity is `full`, `none`, or otherwise unavailable, the launcher
will display a clear desktop notification instead of only writing to a hidden
terminal. Probe, validation, and browser-launch failures also show a concise
failure notification. `libnotify` is an explicit portal-login module package
dependency so `notify-send` is present on a rebuilt workstation.

The public portal configuration files are explicitly unignored and tracked so
the installer and its tests work from a clean checkout.

## Boundaries

- No HUST host, IP address, redirect token, account name, password, or browser
  profile is stored or committed.
- The launcher remains a user-level helper under `~/.local/bin`.
- The module does not alter NetworkManager connection profiles, install a
  dispatcher, or auto-open untrusted portal pages.
- GDM, greetd, Niri configuration, and ToDesk are out of scope.

## Verification

- Shell tests cover `full` notification without a probe, `limited` and
  `unknown` redirects, HTTP/JavaScript/meta-refresh parsing, rejected schemes,
  and browser-launch failure notification.
- Installer tests verify that `libnotify` is requested with
  `network-manager-applet`.
- Run the focused portal test, full project suite, Bash syntax checks, and
  ShellCheck when available before commit.
