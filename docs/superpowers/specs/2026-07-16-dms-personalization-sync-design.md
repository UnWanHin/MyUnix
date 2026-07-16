# DMS Personalization Synchronization Design

## Goal

Synchronize portable DMS personalization without copying DMS machine state,
paired devices, account data, paths, caches, or generated session files.

## Categories

Public configuration lives below `modules/niri-dms/config/dms/`:

- `bar.json`: top-bar layout, widgets and visual bar options.
- `dock.json`: dock visibility, placement and visual layout.
- `appearance.json`: animation, typography, elevation, blur and shared visual
  preferences.
- `frame.json`: DMS connected-frame appearance and geometry options.

Each file is a top-level JSON object containing only its explicit allowlisted
keys. Import shallow-merges only that category into the current local
`settings.json`; it never replaces the full file.

## Exclusions

The sync must never export or import plugin settings, plugin metadata, phone
pairing data, Wi-Fi/Bluetooth/device pins, audio device pins, display/output
profiles, wallpaper and custom file paths, command strings, histories,
notifications, authentication, greeter settings, caches, generated KDL, or
timestamped backups.

## Behavior

`./scripts/myunix export` creates or updates the four category files from
`~/.config/DankMaterialShell/settings.json`. The Niri+DMS installer merges
them only when that DMS settings file already exists. It does not restart DMS;
the user can apply imported appearance changes by logging out/in or running
`dms restart` deliberately.
