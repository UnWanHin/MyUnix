#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
for test_file in "$root"/test_*.sh; do
  bash "$test_file"
done
