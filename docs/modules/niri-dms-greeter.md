# Niri + DMS Greeter

`niri-dms-greeter` is an explicit experimental module that replaces Fedora's
GDM login manager with greetd and DMS Greeter. It is intentionally excluded
from one-click and custom installation. The normal Niri + DMS module keeps GDM
enabled and lets you select Niri from GDM's session chooser.

Run it only after Niri + DMS works through GDM:

```bash
MYUNIX_CONFIRM_GREETER=replace-gdm ./scripts/myunix install --module niri-dms-greeter
```

The module backs up the prior GDM/greetd enablement state and `/etc/greetd/config.toml`
under `/var/lib/myunix/backups/niri-dms-greeter/`. Reboot after installation and
verify that a login screen appears before relying on the greeter.

## Recovery

If the machine boots to a black screen and the previous boot journal contains
`greeter exited without creating a session` or `start-limit-hit`, boot to a TTY
and restore Fedora's GDM:

```bash
sudo systemctl disable greetd.service
sudo systemctl enable --force gdm.service
sudo systemctl set-default graphical.target
sudo reboot
```

If a MyUnix greeter backup path is available, use the managed rollback instead:

```bash
./scripts/myunix rollback niri-dms-greeter /var/lib/myunix/backups/niri-dms-greeter/<timestamp>
```

Do not reset Niri configuration or switch kernels merely because direct
`niri` starts with an empty desktop. Direct invocation bypasses `niri-session`
and the DMS session startup path.
