# DNF packages

`core.txt` contains the repeatable baseline installed by `--all`. `optional.txt` is offered one package at a time when you run `./scripts/myunix install --guided` and select the DNF module. It currently includes VLC and FFmpeg. Keep one DNF package name per line; comments begin with `#`.

`./scripts/myunix doctor` verifies that every package in the core and optional
DNF manifests, plus the input-method and Phone Connect manifests, resolves
from the currently enabled repositories. A missing package is an error: update
the manifest or enable and document its required repository; do not mask it
with `--skip-unavailable`.

`./scripts/myunix export` writes one package per line to
`modules/dnf/exported-userinstalled.txt`. It is a review list of packages DNF
currently marks as user-installed, not an automatic install manifest: it can
include Fedora workstation dependencies and should be curated into `core.txt`
or `optional.txt` before a new computer uses it.

After changing either file, run `./scripts/myunix doctor`, test the installation on Fedora, and commit the manifest and any related documentation together.
