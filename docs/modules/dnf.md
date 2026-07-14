# DNF packages

`core.txt` contains the repeatable baseline installed by `--all`. `optional.txt` is offered one package at a time when you run `./scripts/myunix install --guided` and select the DNF module. It currently includes VLC and FFmpeg. Keep one DNF package name per line; comments begin with `#`.

After changing either file, run `./scripts/myunix doctor`, test the installation on Fedora, and commit the manifest and any related documentation together.
