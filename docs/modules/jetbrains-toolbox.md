# JetBrains Toolbox

JetBrains Toolbox is an optional user-level desktop application. It is not the
same as Fedora's `toolbox` container command.

In guided installation, open **Custom installation → Optional desktop
applications** and select **JetBrains Toolbox**. It can also be installed
directly:

```bash
./scripts/myunix install --module jetbrains-toolbox
```

The module downloads JetBrains' official HTTPS Linux archive, rejects unsafe
archive paths, locates the Toolbox executable regardless of the archive's
top-level directory layout, installs it under `~/.local/opt/jetbrains-toolbox`,
and creates `~/.local/bin/jetbrains-toolbox`. It does not use `sudo` or install
IDEs for you. Start Toolbox once, sign in if needed, and install
CLion/PyCharm/IDEA from Toolbox. Re-running the module skips the download when
the managed launcher is already present, while also repairing the user-level
`~/.local/share/applications/jetbrains-toolbox.desktop` entry and its Toolbox
icon path when necessary.

After installing an IDE, use the synchronized `jet` command. It rescans
Toolbox launchers on every invocation, so newly installed or removed IDEs are
picked up automatically:

```bash
jet .
jetcode .
```

The Toolbox binary itself is installed locally and is not copied into Git;
only the installer behavior and `jet` shell function are synchronized.

For a missing or stale desktop entry/icon, choose **Desktop application
integration → JetBrains Toolbox desktop integration** in
`./scripts/myunix fix`. It checks the managed archive marker, executable
launcher symlink, desktop command, and archive icon path. After confirmation,
it backs up an existing desktop entry below
`~/.local/state/myunix/backups/jetbrains-toolbox/`, regenerates registration,
and refreshes the desktop database. It never downloads/reinstalls Toolbox,
launches it, or scans account data or IDE caches. If the managed launcher is
unusable or missing, it stops and directs you to the explicit installer.
No logout is needed; refresh DMS if its application cache is stale.
