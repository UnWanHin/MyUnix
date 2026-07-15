#!/usr/bin/env bash
set -Eeuo pipefail

dnf_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

export_userinstalled_dnf_candidates() {
  local target
  target="${MYUNIX_DNF_EXPORTED_USERINSTALLED_TARGET:-$(dnf_module_dir)/exported-userinstalled.txt}"
  require_command dnf
  mkdir -p "$(dirname "$target")"
  dnf repoquery --userinstalled --qf '%{name}\n' | awk 'NF' | sort -u > "$target"
  info 'DNF user-installed package candidates exported for review'
}
