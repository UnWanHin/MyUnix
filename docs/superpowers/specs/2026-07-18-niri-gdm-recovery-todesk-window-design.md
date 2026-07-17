# Niri GDM Recovery and ToDesk Window Design

## Context

The workstation booted to a black screen after `greetd` was configured as the
display manager for DMS Greeter. The previous-boot journal showed the greeter
exiting without creating a session five times, followed by `start-limit-hit`.
Niri configuration validation passed and the kernel graphics stack initialized
normally, so neither the kernel nor Niri configuration was the cause.

ToDesk runs as an XWayland client with app ID `ToDesk`. Niri classifies it as a
floating window. It has no MyUnix or DMS window rule that forces a fixed size.
The Niri interactive resize gesture (`Mod` plus right-mouse drag) was tested
and the ToDesk main window remained `520 x 331`, so the application is
rejecting resize requests.

## Decisions

### Keep GDM as the normal installation default

The regular Niri + DMS module must continue to leave Fedora GDM in place. The
separate `niri-dms-greeter` module remains explicitly guarded because it
replaces the system display manager. It is not offered by either one-click or
custom installation.

The incident record documents the evidence and recovery command: disable
`greetd`, enable GDM as the display manager, restore `graphical.target`, then
reboot. The greeter documentation will link to that record and state that a
working Niri session does not prove a greeter session is working.

### Investigate ToDesk's own main-window mode without synchronizing it

The packaged launcher already includes `GDK_BACKEND=x11`; `rpm -V todesk`
reports no local file modifications. Therefore ToDesk runs on Niri through the
official package's XWayland path, not through a GNOME-specific compatibility
change.

ToDesk's private configuration exposes an undocumented
`settingnewmaindlgmode=0` value and the binary contains an old/new main-dialog
feature. The only proposed experiment is to back up the private configuration,
change that one value to `1`, restart ToDesk, and retest its size behavior. If
it does not make the window resizable, restore the backup and do not introduce
a compositor workaround. If it works, record the observation but do not export
the private ToDesk configuration into MyUnix.

### ToDesk experiment result

The mode was temporarily changed from `0` to `1` after a private local backup
was created. The restarted process did not yield a newly verifiable resizable
window: Niri continued to report the ToDesk window at `520 x 330.86`. The
application emitted a CrashReport during this launch, but emitted the same
CrashReport after the configuration was restored, so the crash cannot be
attributed to this setting alone. The experiment therefore did not demonstrate
a working improvement; `settingnewmaindlgmode` was restored to `0`, and its
private configuration remains outside MyUnix.

### Current ToDesk crash result

The official `todesk-4.8.6.2-235.x86_64` client reproducibly exits with
`SIGSEGV` approximately 24 to 26 seconds after launch. Recreating its private
configuration and launching without the GTK/Qt input-method environment
variables produces the same result. The coredump points to the bundled HTML UI
(`html::element::determine_style` from `gtk4view::idle_callback`), not Niri,
GDM, the package files, or the input method. The official Linux download page
currently provides the same release, so reinstalling cannot change this
result. Keep the current package entry for reproducibility, but treat a vendor
update or an explicitly approved compatibility downgrade as prerequisites for
a functional ToDesk client.

## Verification

- `rpm -V todesk` reports no local package modifications before the experiment.
- After changing only `settingnewmaindlgmode`, relaunch ToDesk and verify both
  its Niri-reported dimensions and interactive resize behavior.
- Restore the backup immediately if the new main-dialog mode fails to start or
  remains fixed-size.
- The repository test suite, Bash syntax checks, and ShellCheck (when
  available) pass before commit.
- Manual desktop verification: GDM remains the display manager and ToDesk
  continues to start through its packaged XWayland launcher.

## Out Of Scope

- Replacing or patching the ToDesk binary.
- Downgrading ToDesk without an explicit approval and a compatible RPM source.
- Automatically enabling or disabling display managers during ordinary
  Niri/DMS installation.
- Changing graphics drivers or kernels.
