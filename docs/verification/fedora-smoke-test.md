# Fedora smoke-test checklist

Run this checklist in a clean Fedora GNOME virtual machine before trusting a new manifest revision on a replacement computer.

1. Run `./scripts/myunix doctor`; it must report Fedora GNOME prerequisites.
2. Run `./scripts/myunix install`; confirm the first screen offers exactly one-click and custom installation. In custom mode, confirm English is selected and locked, then select Cangjie only with `Space` and `Enter`.
3. Confirm module lines show `[current/total]`, operation lines show attempts and `~/.local/state/myunix/runs.tsv` records each completed module.
4. Add a deliberately incorrect RPM checksum to a disposable manifest entry and run only the RPM module; confirm it stops before DNF and leaves no RPM in the temporary directory.
5. Run `./scripts/myunix export`, inspect the diff, and verify that it contains only scoped GNOME settings, public Fcitx5 files, IBus dconf settings, one-package-per-line DNF candidates, Niri `config.kdl`, reviewed `dms/*.kdl` shortcuts and the separate public Phone Connect fragment. It must not contain DMS JSON state, phone pairing data, cache or backups.
6. Run `./scripts/myunix install --module gnome`; confirm a backup is created under `~/.local/state/myunix/backups/gnome/` before loading the saved hotkeys.
7. After input-method installation/import, log out and back in, then verify the GNOME input-source list plus the Fcitx5 `cangjie5` and `pinyin` engines selected for the run.
8. Trigger a disposable module failure in a terminal. Confirm Retry reruns only that module, Skip records it as `deferred` and continues independent modules, Stop halts the run, and `./scripts/myunix retry` selects both failed and deferred module identifiers.
