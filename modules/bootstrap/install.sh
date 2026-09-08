#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/rpmfusion.sh"

install_bootstrap() {
  is_fedora || die 'Fedora is required'
  require_command rpm
  require_command dnf

  install_rpmfusion_repositories || return $?
  network_run dnf 'Refreshing DNF metadata' sudo dnf makecache
}
