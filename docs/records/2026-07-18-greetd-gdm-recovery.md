# DMS Greeter black-screen recovery record

## Symptoms

After selecting the DMS Greeter/greetd display manager, graphical boot reached
a black screen. Booting once with kernel argument `3` reached a TTY. Niri
configuration validation reported only an optional missing touchpad binding and
ended with `config is valid`.

## Root cause

The previous graphical boot journal showed `dms-greeter` exiting before it
created a session. Greetd retried it five times, then stopped with
`start-limit-hit`. GDM had been disabled, so no login-manager fallback
remained.

Kernel and graphics logs did not show a kernel panic. The Intel graphics stack
initialized its framebuffer, and Niri could start manually. An empty desktop
from direct `niri` invocation is expected because it bypasses `niri-session`
and DMS startup; it is not proof that the Niri configuration is broken.

## Verified recovery

The recovery changed only the display-manager selection:

```bash
sudo systemctl disable greetd.service
sudo systemctl enable --force gdm.service
sudo systemctl set-default graphical.target
sudo reboot
```

After reboot, GDM presents Niri as a selectable Wayland session. The normal
MyUnix Niri + DMS installation already follows this conservative policy and
does not install the greeter replacement. The separate greeter module remains
an explicit opt-in with a managed rollback.
