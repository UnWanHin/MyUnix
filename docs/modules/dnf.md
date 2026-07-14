# DNF packages

`core.txt` contains the repeatable baseline installed by `--all`. `optional.txt` contains packages offered by guided installation. Keep one DNF package name per line; comments begin with `#`.

After changing either file, run `./scripts/myunix doctor`, test the installation on Fedora, and commit the manifest and any related documentation together.
