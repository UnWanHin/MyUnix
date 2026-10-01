# Proxy Watchdog

This optional user-level module keeps the GNOME system proxy and the shell
proxy environment in sync with a local HTTP proxy client (FlClash/mihomo on
`127.0.0.1:7890` by default). It exists because three separate failures had the
same visible symptom — "the browser works but a native app cannot reach
OpenAI":

- the CLI tools had no proxy environment at all and connected directly from a
  blocked region, so the OAuth token exchange returned
  `unsupported_country_region_territory` (`HTTP 403`);
- the ChatGPT desktop app ignores the GNOME system proxy, so its token
  exchange went out direct even while Firefox worked;
- the watchdog started before the proxy client after a reboot, flipped the
  system proxy to `none`, and early-launched applications cached that value.

```bash
./scripts/myunix install --module proxy
```

The module never runs `sudo`. Every artifact is applied as the target desktop
user, and it is not part of the one-click `--all` profile because it changes
the session-wide system proxy.

## What it installs

| Target | Purpose |
| --- | --- |
| `~/.local/bin/proxy-watchdog.sh` | Reconciles the GNOME system proxy with proxy-client liveness every 5 s |
| `~/.local/bin/chatgpt-proxied` | Launches the ChatGPT desktop app through the proxy client |
| `~/.config/sysrc.d/proxy.rc` | Sourced by `~/.config/.sysrc`; exports CLI proxy variables only while the client answers |
| `~/.config/systemd/user/proxy-watchdog.service` | `Restart=on-failure` user service for the watchdog |
| `~/.config/autostart/proxy-watchdog.desktop` | XDG autostart fallback for sessions without a user systemd bus |
| `~/.local/share/applications/chatgpt.desktop` | Managed override of the ChatGPT launcher; generated from `/usr/share/applications/chatgpt.desktop` |

The autostart entry stores the resolved absolute helper path because the Niri
session `PATH` starts with `/usr/local/bin` and `/usr/bin` and does **not**
include `~/.local/bin`. The desktop override is generated from the installed
system entry so menu categories and MIME types stay current; the system file is
never modified. Both the service and the autostart entry may be present — the
helper's pidfile makes the second instance exit immediately.

When `./scripts/myunix install --module proxy` runs inside a user session it
also runs `systemctl --user daemon-reload` and
`systemctl --user enable --now proxy-watchdog.service`. If no user systemd bus
is reachable it prints the exact command instead of failing.

## How the watchdog decides

Each poll probes `http://127.0.0.1:7890/`, reads the real
`org.gnome.system.proxy mode`, and reconciles the two:

| Proxy client | System proxy | Action |
| --- | --- | --- |
| up | `none` or unset | set `manual` plus `http`/`https`/`socks` host and port |
| down | `manual` | set `none` so GUI apps fall back to a direct connection |
| up | `manual` | no write |

`STARTUP_GRACE` (default 90 s) delays only the `manual` → `none` direction, so
an application launched early after a reboot keeps the proxy that is about to
come back. Repairs towards `manual` are never delayed. A failed `gsettings`
write is never reported as success; the poll retries and logs one line instead
of looping on the log file. `ignore-hosts` is never touched.

Log: `~/.cache/proxy-watchdog.log`. Override the endpoint with
`PROXY_HOST`/`PROXY_PORT`, the interval with `POLL_SECS`, and the boot grace
with `STARTUP_GRACE` in the unit or autostart environment. Set `DRY_RUN=1` to
log the intended `gsettings` calls without writing them.

## ChatGPT desktop app

The desktop app is an Electron UI plus a Rust app-server daemon; neither
follows the GNOME system proxy. `chatgpt-proxied` forces the proxy twice — as
environment variables for the Rust side and as
`--proxy-server`/`--proxy-bypass-list` for the Chromium side — and falls back
to a direct launch when no client is listening. `~/.codex/config.toml` provider
selection, `auth.json` and any long-lived token stay outside this module: no
credential, account identifier or subscription URL is stored in Git.

## Verification

```bash
systemctl --user status proxy-watchdog
systemctl --user is-enabled proxy-watchdog
gsettings get org.gnome.system.proxy mode
tail -n 20 ~/.cache/proxy-watchdog.log
```

Both `enabled` and `active` are expected, and the mode should follow the proxy
client. If the mode is `'none'` while the client is running, check
`~/.cache/proxy-watchdog.log` for a `gsettings write error`. The watchdog only
controls the GNOME proxy; it never starts, stops or reconfigures the proxy
client itself, and therefore cannot repair a client whose own "system proxy"
switch is off.
