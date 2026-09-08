#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

run env MYUNIX_TEST_MODE=nonfedora "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 2
assert_output_contains 'Fedora is required'

temporary_bin="$(mktemp -d)"
trap 'rm -rf -- "$temporary_bin"' EXIT
mkdir -p "$temporary_bin/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "${!#}"' > "$temporary_bin/bin/dnf"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$temporary_bin/bin/dconf"
chmod +x "$temporary_bin/bin/dnf" "$temporary_bin/bin/dconf"

run env MYUNIX_TEST_MODE=fedora PATH="$temporary_bin/bin:$PATH" "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 0
assert_output_contains 'Fedora GNOME prerequisites verified'
