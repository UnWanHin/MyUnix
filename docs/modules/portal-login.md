# Portal Login

This optional Niri/DMS module fills the captive-portal UI gap normally handled
by GNOME Shell or KDE Plasma. It installs Fedora's `network-manager-applet`
and an XDG autostart entry that starts `nm-applet --indicator` after login.
The indicator provides ordinary NetworkManager Wi-Fi controls in the DMS tray.

```bash
./scripts/myunix install --module portal-login
```

Log out and back into Niri after installation. When a Wi-Fi network needs a
web sign-in, open DMS Spotlight with `Mod+Space`, search **Wi-Fi Login**, and
press Enter.

## Generic captive-portal detection

The launcher checks NetworkManager's current connectivity. Only when it is
`portal` does it request `http://neverssl.com`, extract a standard HTTP
`Location` redirect or a JavaScript location assignment, validate that it is
HTTP(S), then pass it to `xdg-open`.

This works for HUST, hotels, airports and other portal Wi-Fi networks because
the destination is discovered live. MyUnix does not contain a HUST address,
does not auto-open a browser on every network connection, and does not save
redirect tokens, device addresses, account names or passwords.

For terminal troubleshooting only, the same helper is available as:

```bash
myunix-portal-login
```

If it says no supported redirect was found, open the network's portal page
through the normal `nm-applet` controls or report the response shape before
adding any network-specific handling.
