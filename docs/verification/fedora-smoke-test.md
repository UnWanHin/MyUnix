# Fedora smoke-test checklist

Run this checklist in a clean Fedora GNOME virtual machine before trusting a new manifest revision on a replacement computer.

1. Run `./scripts/myunix doctor`; it must report Fedora GNOME prerequisites.
2. Run `./scripts/myunix install --guided`; decline every choice, including the optional Niri/DMS, shell-config and Phone Connect prompts, and confirm no packages are installed. The destructive greeter must not be offered.
3. Run the guided flow again, select a single safe module, and confirm `~/.local/state/myunix/runs.tsv` records its result.
4. Add a deliberately incorrect RPM checksum to a disposable manifest entry; confirm the installer stops before DNF and leaves no RPM in the temporary directory.
5. Run `./scripts/myunix export`, inspect the diff, and verify that it contains only scoped GNOME settings, public Fcitx5 files, IBus dconf settings, one-package-per-line DNF candidates, Niri `config.kdl`, reviewed `dms/*.kdl` shortcuts and the separate public Phone Connect fragment. It must not contain DMS JSON state, phone pairing data, cache or backups.
6. Run `./scripts/myunix install --module gnome`; confirm a backup is created under `~/.local/state/myunix/backups/gnome/` before loading the saved hotkeys.
7. After input-method installation/import, log out and back in, then verify the GNOME input-source list and the Fcitx5/Rime/Mozc engines.
8. Run `./scripts/myunix retry` after a recorded failure; confirm only failed module identifiers are selected.
