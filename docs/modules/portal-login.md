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

The launcher checks NetworkManager's current connectivity. When it is
`portal`, `limited`, or `unknown`, it requests `http://neverssl.com`, extracts
a standard HTTP `Location` redirect, JavaScript location assignment, or HTML
meta-refresh URL, and validates that it is HTTP(S). It then presents a desktop
notification with **Open sign-in page**. The browser opens only after you
select that action. The destination is therefore discovered from the current
network rather than being hard-coded.

When connectivity is already `full`, Wi-Fi Login does not open a browser
because there is no portal to sign into. It instead shows a desktop
notification that the network is already connected. Missing connectivity,
probe failures, unsafe redirects, and browser-launch failures also show a
clear notification rather than silently doing nothing.

This works for HUST, hotels, airports and other portal Wi-Fi networks because
the destination is discovered live. MyUnix does not contain a HUST address,
does not auto-open a browser, including when the Wi-Fi Login entry is
selected, and does not save redirect tokens, device addresses, account names
or passwords.

For terminal troubleshooting only, the same helper is available as:

```bash
myunix-portal-login
```

If it reports that no sign-in page was found, open the network's portal page
through the normal `nm-applet` controls or report the response shape before
adding any network-specific handling.
