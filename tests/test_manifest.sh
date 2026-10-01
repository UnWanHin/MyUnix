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

tabby_record='tabby|Tabby|https://github.com/Eugeny/tabby/releases/download/v1.0.237/tabby-1.0.237-linux-x64.rpm|162a523b85e04c2118570edecc977c34a20c681ad8a34f63496081ddcae76e8d|optional|rpm|tabby-terminal'
grep -Fqx -- "$tabby_record" "$PROJECT_ROOT/modules/rpm/apps.tsv"
grep -Fxq obs-studio "$PROJECT_ROOT/modules/dnf/optional.txt"
grep -Fxq libreoffice "$PROJECT_ROOT/modules/dnf/optional.txt"
grep -Fq -- 'https://data.services.jetbrains.com/products/download?code=TBA&platform=linux' "$PROJECT_ROOT/modules/jetbrains-toolbox/install.sh" || {
  printf 'Expected official JetBrains Toolbox download URL\n' >&2
  exit 1
}

printf 'qq|QQ|https://example.test/qq.rpm|%064d|optional|echo|qq\n' 0 > "$tmp/unsafe-rpm.tsv"
if validate_rpm_manifest "$tmp/unsafe-rpm.tsv"; then
  printf 'Expected arbitrary verification command to be rejected\n' >&2
  exit 1
fi
