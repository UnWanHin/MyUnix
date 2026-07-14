#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
  set +e
  OUTPUT="$("$@" 2>&1)"
  STATUS=$?
  set -e
}

assert_status() {
  [[ "$STATUS" == "$1" ]] || {
    printf 'Expected status %s, got %s. Output:\n%s\n' "$1" "$STATUS" "$OUTPUT" >&2
    exit 1
  }
}

assert_output_contains() {
  [[ "$OUTPUT" == *"$1"* ]] || {
    printf 'Expected output to contain %q. Output:\n%s\n' "$1" "$OUTPUT" >&2
    exit 1
  }
}

assert_equals() {
  [[ "$2" == "$1" ]] || {
    printf 'Expected %q, got %q\n' "$1" "$2" >&2
    exit 1
  }
}
