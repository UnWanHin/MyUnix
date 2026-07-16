# MyUnix modules

Each module owns one kind of configuration. This keeps package installation,
desktop settings and exported state from overwriting one another.

| Module | Responsibility | Guide |
| --- | --- | --- |
| bootstrap | RPM Fusion repositories | [[../modules/bootstrap|bootstrap]] |
| dnf | Fedora package manifests | [[../modules/dnf|dnf]] |
| rpm | checksum-pinned downloaded RPMs | [[../modules/rpm|rpm]] |
| gnome | GNOME media-key shortcuts | [[../modules/gnome|gnome]] |
| input-method | IBus/Fcitx5 and app launch adapters | [[../modules/input-method|input method]] |
| steam | RPM Fusion Steam plus Niri system-composer launcher | [[../modules/steam|steam]] |
| niri-dms | optional Niri, DMS, reviewed plugin IDs, KDL session files, optional `Mod+F8` touchpad shortcut and categorized public personalization | [[../modules/niri-dms|niri dms]] |
| shell-config | Bash/Zsh common `.sysrc` fragments | [[../modules/shell-config|shell config]] |
| phone-connect | KDE Connect package, firewall gate and Niri fragment | [[../modules/phone-connect|phone connect]] |
| portal-login | generic captive-portal launcher for Niri/DMS | [[../modules/portal-login|portal login]] |
| development-toolchain | Fedora and user-scoped compiler/runtime components | [[../modules/development-toolchain|development toolchain]] |
| distrobox | container tooling for Ubuntu and other distributions | [[../modules/distrobox|distrobox]] |

The guarded `niri-dms-greeter` module, `distrobox-ros2-humble`, and
`distrobox-codex` are explicit follow-on modules. They are intentionally kept
outside the baseline because they alter login-session behaviour or create
specialized container environments. Start from [[installation-map]] to see
which installer mode exposes each capability.

The Niri/DMS and Phone Connect modules cooperate through an optional Niri
include, but Phone Connect remains the owner of its `kdeconnect.kdl` fragment.
See [[session]] and [[recovery]].

#modules #ownership #migration
