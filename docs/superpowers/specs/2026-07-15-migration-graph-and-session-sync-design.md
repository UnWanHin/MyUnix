# MyUnix migration graph and Niri/DMS session synchronization

## Status

Approved direction: Obsidian native Graph View, with versioned notes below
`docs/obsidian/`. No localhost web server is part of this migration baseline.

## Goal

Make the local `fedora` working tree a complete, reviewable migration source
for the user's Fedora GNOME + Niri/DMS workstation. The repository must show
the relationship between packages, modules, public desktop settings and
recovery commands without capturing private desktop or phone data.

## Chosen approach

Use Obsidian-compatible Markdown links as the source graph. Opening the
repository as an Obsidian vault makes the graph interactive and immediately
reflects changes to the tracked notes. The repository does not track
`.obsidian/`, run an HTTP service, install a browser preview tool, or expose a
local API.

This is preferred over a localhost documentation site because it remains
offline, has no Node.js runtime or generated site artefacts, and directly
serves the migration workflow.

## Graph structure

`docs/obsidian/` contains only portable documentation:

- `README.md`: vault entry point, graph-view instructions and scope.
- `workstation.md`: the relationship hub for Fedora, GNOME, Niri/DMS and
  package sources.
- `modules.md`: links every MyUnix module to its manifest, importer, exporter,
  tests and user-facing guide.
- `session.md`: Niri configuration, DMS-managed `*.kdl` files, Fcitx5 and
  desktop-launcher adapters.
- `recovery.md`: repeatable export, install, doctor and retry commands.

Each note uses normal `[[wiki links]]`, a small Mermaid overview and tags, so
Obsidian's native Graph View is dynamic while Git continues to store plain
Markdown.

## Synchronization boundaries

### Niri and DMS

The Niri/DMS exporter owns only publicly reproducible configuration:

- `~/.config/niri/config.kdl`
- `~/.config/niri/dms/*.kdl` required for layout, bindings, outputs, cursor,
  colours and window rules

It excludes timestamped backups and generated transient files. DMS shortcuts
are therefore exported from `dms/binds.kdl`; the auto-generated Alt-Tab file
remains documented but is not hand-edited. The separate `phone-connect` module
is the only owner of `~/.config/niri/myunix/kdeconnect.kdl`.

### DMS application state

The baseline installs DMS and recreates the reviewed plugin set from a public
plugin-ID manifest, but does not export `DankMaterialShell/settings.json`,
plugin settings, wallpaper paths, recent-data caches, or KDE Connect
pairing/device identities. Those files can contain machine-specific paths or
private state. The reusable DMS behaviour is kept in Niri/DMS KDL configuration
and module documentation.

### Packages and sources

DNF manifests contain only package names that resolve from the enabled,
documented Fedora/RPM Fusion/COPR sources for the current Fedora release.
Direct RPM entries remain in their separate HTTPS + checksum registry.
Niri/DMS stays a guarded optional module because it uses its documented COPR
source and GNOME remains installed.

## Installation workflow

`--guided` offers the existing baseline modules plus explicit optional choices
for Niri/DMS, shared shell configuration and Phone Connect. The greeter remains
a separately-confirmed destructive replacement path. `--all` remains
conservative and does not replace the GNOME session or login manager.

The export workflow updates the owned public configuration, then provides a
reviewable diff. Installation creates backups under
`~/.local/state/myunix/backups/` before changing user configuration.

## Verification

The change adds or extends shell tests for the Niri/DMS export allowlist,
guided-module selection and package-manifest validation. Before synchronization
the repository runs its test suite, Bash syntax checks, ShellCheck when
available, Niri configuration validation, DNF package-resolution checks and
`git diff --check`.

No commits or push occur until those local checks pass and the staged diff has
been checked for private data. The user explicitly authorized a push to
`fedora` after this verification.
