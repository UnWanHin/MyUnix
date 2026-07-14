#!/usr/bin/env bash
set -Eeuo pipefail

fedora_release() { printf '%s\n' "${MYUNIX_FEDORA_RELEASE:-$(rpm -E %fedora)}"; }

require_dms_supported_fedora() {
  local release
  release="$(fedora_release)"
  [[ "$release" == 43 || "$release" == 44 ]] || die 'DMS is supported only on Fedora 43 or 44'
}

install_niri_dms() {
  is_fedora || die 'Fedora is required'
  require_dms_supported_fedora
  sudo dnf copr enable -y avengemedia/danklinux
  sudo dnf copr enable -y avengemedia/dms
  sudo dnf install -y dms niri quickshell kitty hyfetch zsh
  info 'Niri + DMS installed. Select Niri from the login-session chooser after enabling the Greeter module.'
}
