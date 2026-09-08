# DNF packages

`core.txt` contains the small repeatable base. `portable.txt` is the curated
workstation profile installed by `--all` and the one-click menu. It restores
the normal command-line tools plus ChatGPT desktop, VS Code and GitHub CLI
without copying any account state. `optional.txt` records reviewed packages
such as VLC and FFmpeg; custom installation does not currently prompt for
them. Keep one package name per line; comments begin with `#`.

`sources.tsv` is the source registry. `profile` entries are enabled before
`portable.txt` is resolved. It uses RPM Fusion plus signed repository templates
for ChatGPT and VS Code. `niri-dms` entries are enabled only by the optional
Niri + DMS module; this keeps its COPRs out of a GNOME-only installation while
making the exact DMS Git and Niri sources reproducible. `catalog` entries, such
as Google Chrome and the historical PyCharm COPR, are recorded but deliberately
not enabled by one-click installation because no profile package requires them.

RPM Fusion setup is implemented once in the shared bootstrap helper. The
bootstrap module initializes it first, while the portable profile uses that
same helper when the DNF module is invoked independently.

The registry is intentionally not a raw copy of every enabled repository. It
contains only reviewed, portable sources. `repos/*.repo` holds static public
repository definitions, and `keys/chatgpt.asc` is OpenAI's public RPM signing
key, not an authentication credential. Direct RPM applications remain in the
separate `modules/rpm/` registry.

DNF transactions are retried up to three times and receive a 30-minute timeout
by default. The installer prints the transaction status and attempt number;
set `MYUNIX_NETWORK_ATTEMPTS` or `MYUNIX_DNF_TIMEOUT_SECONDS` to override
those values for one run.

`./scripts/myunix doctor` verifies packages that Fedora sources must already
provide, then validates the portable profile and source registry syntax without
modifying the computer. During installation, MyUnix enables the profile sources
and verifies every portable package before installing it. A missing package is
an error: update the manifest or its documented source; do not mask it with
`--skip-unavailable`.

`./scripts/myunix export` writes two review snapshots:

- `exported-userinstalled.txt` lists every package DNF currently considers
  user-installed.
- `exported-enabled-repositories.txt` lists every currently enabled repository
  ID.

Neither snapshot is replayed automatically. They can include kernels,
firmware, hardware drivers, installer dependencies or historical sources.
Review meaningful additions into `portable.txt`, `sources.tsv`, or the owning
feature module before another computer uses them.

Do not put kernels, firmware, bootloaders, hardware-specific drivers, Wi-Fi
profiles, paired devices, SSH keys, tokens, browser state or credentials in a
portable DNF profile. After changing a profile or source, run
`./scripts/myunix doctor`, test the installation on Fedora, and commit the
manifest and documentation together.
