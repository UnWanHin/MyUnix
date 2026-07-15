#!/usr/bin/env bash
set -Eeuo pipefail

development_toolchain_verify_command() {
  local name=$1
  shift
  if command -v "$name" >/dev/null 2>&1; then
    printf '\n== %s ==\n' "$name"
    "$@"
  else
    printf '\n== %s ==\nnot found\n' "$name"
  fi
}

verify_development_toolchain() {
  development_toolchain_verify_command java java --version
  development_toolchain_verify_command javac javac --version
  development_toolchain_verify_command cmake cmake --version
  development_toolchain_verify_command ninja ninja --version
  development_toolchain_verify_command python3 python3 --version
  development_toolchain_verify_command conda conda --version
  development_toolchain_verify_command node node --version
  development_toolchain_verify_command go go version
  development_toolchain_verify_command rustc rustc --version
  development_toolchain_verify_command cargo cargo --version
  development_toolchain_verify_command gcc gcc --version
  development_toolchain_verify_command clang clang --version
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  verify_development_toolchain
fi
