#!/usr/bin/env bash
set -Eeuo pipefail

distrobox_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

install_distrobox() {
  is_fedora || die 'Fedora is required'
  install_dnf_manifest "$(distrobox_dir)/packages.txt"
  require_command distrobox
  info 'Distrobox installed. No container image or distribution was created.'
}
