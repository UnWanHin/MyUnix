#!/usr/bin/env bash
set -Eeuo pipefail

input_method_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

install_input_methods() {
  install_dnf_manifest "$(input_method_dir)/packages.txt"
  info 'Input method packages installed. Log out and back in before configuring GNOME input sources.'
}
