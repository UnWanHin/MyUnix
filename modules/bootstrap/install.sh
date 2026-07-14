#!/usr/bin/env bash
set -Eeuo pipefail

install_bootstrap() {
  is_fedora || die 'Fedora is required'
  require_command rpm
  require_command dnf

  local version
  version="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${version}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${version}.noarch.rpm"
  sudo dnf makecache
}
