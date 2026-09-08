#!/usr/bin/env bash
set -Eeuo pipefail

install_rpmfusion_repositories() {
  local version
  if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
    info 'RPM Fusion repositories already installed'
    return 0
  fi
  version="$(rpm -E %fedora)"
  network_run dnf 'Installing RPM Fusion repositories' sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${version}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${version}.noarch.rpm"
}
