#!/usr/bin/env bash
set -Eeuo pipefail

dnf_export_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

export_userinstalled_dnf_candidates() {
  local target
  target="${MYUNIX_DNF_EXPORTED_USERINSTALLED_TARGET:-$(dnf_export_module_dir)/exported-userinstalled.txt}"
  require_command dnf
  mkdir -p "$(dirname "$target")"
  # LC_ALL=C keeps the committed snapshot stable across session locales.
  dnf repoquery --userinstalled --qf '%{name}\n' | awk 'NF' | LC_ALL=C sort -u > "$target"
  info 'DNF user-installed package candidates exported for review'
}

export_enabled_dnf_repositories() {
  local target
  target="${MYUNIX_DNF_EXPORTED_REPOSITORIES_TARGET:-$(dnf_export_module_dir)/exported-enabled-repositories.txt}"
  require_command dnf
  mkdir -p "$(dirname "$target")"
  dnf repolist --enabled --quiet | awk '$1 != "repo" && NF { print $1 }' | LC_ALL=C sort -u > "$target"
  info 'Enabled DNF repository IDs exported for review'
}
