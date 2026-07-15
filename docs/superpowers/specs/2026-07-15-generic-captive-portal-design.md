# Generic Captive Portal Login

## Status

Approved for implementation.

## Goal

Make captive-network login practical in Niri + DMS without storing a
network-specific URL, login credentials, MAC address, or other connection
identifiers in MyUnix.

## Decision

Add a separate `portal-login` module. It installs Fedora's
`network-manager-applet` (`nm-applet`) for ordinary NetworkManager tray UI and
installs a user-owned `myunix-portal-login` helper plus a `Wi-Fi Login.desktop`
launcher. DMS Spotlight discovers the launcher, so `Mod+Space` then “Wi-Fi
Login” opens the portal flow without a terminal.

The helper is generic. It asks NetworkManager whether connectivity is
`portal`, requests the well-known HTTP probe `http://neverssl.com`, and
extracts either a standard HTTP `Location` header or a JavaScript location
assignment from the response. Only an `http://` or `https://` destination is
given to `xdg-open`. The dynamic destination is held only for that invocation;
it is not logged, exported or written to the repository.

When connectivity is already `full`, the helper reports that no sign-in is
needed. When no supported redirect can be found, it reports a clear error and
leaves the browser untouched.

## Alternatives

- **GNOME-style automatic notification:** DMS does not currently provide the
  desktop-shell captive-portal notification integration. This would require
  upstream DMS functionality rather than a portable repository module.
- **Automatic dispatcher that opens a browser on connect:** rejected. It would
  make any untrusted Wi-Fi connection open an arbitrary portal page without a
  user action.
- **`nm-applet` only:** useful for normal Wi-Fi management, but does not
  reliably open every captive portal, especially JavaScript redirects such as
  HUST_WIRELESS.

## Boundaries

- No HUST hostname, IP address, redirect token, account name or password is
  committed.
- The module is opt-in through `./scripts/myunix install --module portal-login`.
- It uses user-level files below `~/.local/bin` and
  `~/.local/share/applications`; package installation is the only privileged
  operation.
- It does not start a background process or alter NetworkManager connection
  profiles.

## Verification

Shell tests cover portal-state recognition, JavaScript and HTTP redirects,
scheme rejection, full-connectivity no-op behavior, launcher installation and
the package manifest. The full project suite and Bash syntax checks run before
commit.
