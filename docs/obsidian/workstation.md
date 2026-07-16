# Fedora workstation

[[MyUnix migration graph|MyUnix]] manages a Fedora workstation that keeps
GNOME available while allowing an optional Niri + DMS session.

For an at-a-glance list of what is installed automatically versus selected
later, open [[installation-map]].

```mermaid
flowchart TD
  Fedora[Fedora base] --> Bootstrap[RPM Fusion / bootstrap]
  Fedora --> DNF[DNF manifests]
  Fedora --> RPM[Direct RPM registry]
  Fedora --> GNOME[GNOME shortcuts]
  Fedora --> Niri[Niri + DMS]
  Niri --> Fcitx[Fcitx5 / Cangjie]
  Niri --> Phone[KDE Connect]
  Shell[Shared shell config] --> Recovery[Export / install / retry]
```

## Main paths

- [[modules]] owns installation sources and module boundaries.
- [[session]] records desktop-session configuration and shortcuts.
- [[recovery]] gives the commands for migration and repair.

## Documentation links

- [[../modules/bootstrap|Bootstrap and RPM Fusion]]
- [[../modules/dnf|DNF packages]]
- [[../modules/rpm|Direct RPM applications]]
- [[../modules/gnome|GNOME shortcuts]]
- [[../modules/niri-dms|Niri + DMS]]
- [[../modules/input-method|Chinese input]]
- [[../modules/phone-connect|Phone Connect]]

#fedora #gnome #niri #dms
