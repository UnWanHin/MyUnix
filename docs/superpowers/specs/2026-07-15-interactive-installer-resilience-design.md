# Interactive installer and input-method selection

## Status

Approved.

## Goal

Replace MyUnix's sequential `y/N` guided prompts with a keyboard-driven
installer entry point. One-click installation installs the full migration
baseline with English, Cangjie 5 and Pinyin; custom installation currently
selects only optional Chinese input methods while keeping English available.

## Decision

Use a dependency-free Bash TTY selector built from ANSI escape sequences and
single-key reads. It presents filled and empty circles, supports Up/Down,
Space and Enter, and works on a fresh Fedora installation without first
installing `gum`, `fzf` or another UI dependency.

The default `./scripts/myunix install` entry screen has two choices:

- One-click installation: full baseline, English + Cangjie + Pinyin.
- Custom installation: baseline modules plus an input-method multi-select.

`--all` remains the non-interactive equivalent of one-click installation.
`--guided` remains available for automation compatibility but opens the custom
input-method selector when run in a TTY.

## Input-method model

English is the system keyboard and is always retained. The custom menu shows
it as selected and locked. Cangjie and Pinyin are independent optional
capabilities:

- Cangjie: `ibus-table-chinese-cangjie`, `fcitx5-chinese-addons`, and
  `fcitx5-table-extra`.
- Pinyin: `ibus-libpinyin` and `fcitx5-chinese-addons`.

The installer resolves shared packages once, installs the selected packages,
and renders the public Fcitx profile with exactly the selected engines.
One-click selects both capabilities. Existing Fcitx configuration is backed up
before replacement as it is today.

Rime and Mozc are removed from the default input-method package set because
they are not English, Cangjie or Pinyin. They can be introduced later as
separate custom choices without changing the selection interface.

## Installation resilience

Network-bound work receives one shared wrapper:

- Default timeout: 30 minutes for DNF/COPR/plugin operations and 10 minutes
  for a direct RPM download.
- Default attempts: 3, with short increasing delays between attempts.
- Environment overrides: `MYUNIX_NETWORK_ATTEMPTS`,
  `MYUNIX_DNF_TIMEOUT_SECONDS`, and `MYUNIX_DOWNLOAD_TIMEOUT_SECONDS`.

The wrapper never retries configuration import or user-setting writes. Failed
modules remain recorded below `~/.local/state/myunix/`; `myunix retry` still
reruns only those modules.

When a network operation exhausts its attempts, the interactive installer
shows the failure, its last command category and the available action:
continue by skipping that module, retry it immediately, or stop the run. A
skip is recorded explicitly and does not prevent independent modules from
continuing. Non-interactive operation records the failure and continues with
independent modules, preserving the existing non-zero final exit status.

## Progress and failure behaviour

The installer prints module-level progress such as `[3/6] input-method` before
each module and reports elapsed seconds on success, skip or failure. It emits
plain status lines before each significant operation: repository setup,
package resolution, download attempt `1/3`, checksum verification, DNF
transaction, configuration import and plugin install. DNF and wget retain
their native package/download progress. Independent modules continue after a
skip or failure, then a final summary lists succeeded, skipped and failed
modules with the retry command.

## Boundaries

- The interactive selector runs only on a TTY. Non-interactive commands fail
  with an explicit instruction to use `--all` or `--module`.
- No UI library or downloaded executable is added.
- The greeter remains outside one-click and custom selection because replacing
  GDM requires its separate confirmation gate.
- Input-method selection stores no account data or private user text.

## Verification

Shell tests cover selector key handling, one-click selection defaults, custom
Cangjie/Pinyin package resolution, profile rendering, retry-attempt limits,
timeout argument propagation, module progress ordering and retained retry
state. The full project suite, Bash syntax checks, ShellCheck when available,
and README/module documentation checks run before a commit.
