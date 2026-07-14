#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/manifest.sh"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

printf 'qq|QQ|https://example.test/qq.rpm|bad|optional|rpm|qq\n' > "$tmp/rpm.tsv"
if validate_rpm_manifest "$tmp/rpm.tsv"; then
  printf 'Expected malformed checksum to be rejected\n' >&2
  exit 1
fi

printf 'git\n# comment\nwget\n' > "$tmp/dnf.txt"
validate_dnf_manifest "$tmp/dnf.txt"
