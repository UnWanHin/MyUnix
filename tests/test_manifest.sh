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
validate_rpm_manifest "$PROJECT_ROOT/modules/rpm/apps.tsv"

tabby_record='tabby|Tabby|https://github.com/Eugeny/tabby/releases/download/v1.0.235/tabby-1.0.235-linux-x64.rpm|0dd56a3c2a43547e5ae23cd87a8a205b3b91d3bf6685cd8e380c79cf1154a0c9|optional|rpm|tabby-terminal'
grep -Fqx -- "$tabby_record" "$PROJECT_ROOT/modules/rpm/apps.tsv"

printf 'qq|QQ|https://example.test/qq.rpm|%064d|optional|echo|qq\n' 0 > "$tmp/unsafe-rpm.tsv"
if validate_rpm_manifest "$tmp/unsafe-rpm.tsv"; then
  printf 'Expected arbitrary verification command to be rejected\n' >&2
  exit 1
fi
