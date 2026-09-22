#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
mapfile -t test_files < <(printf '%s\n' "$root"/test_*.sh | sort)
for test_file in "${test_files[@]}"; do
  bash "$test_file"
done
