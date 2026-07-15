#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

toolchain_module="$PROJECT_ROOT/modules/development-toolchain/install.sh"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$toolchain_module'; development_toolchain_normalize_components 'jdk,jdk,cmake'"
assert_status 0
assert_equals $'jdk\ncmake' "$OUTPUT"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$toolchain_module'; development_toolchain_resolve_dnf_packages 'jdk,cmake,ninja,rust'"
assert_status 0
assert_output_contains 'java-latest-openjdk-headless'
assert_output_contains 'java-latest-openjdk-devel'
assert_output_contains 'cmake'
assert_output_contains 'ninja-build'
assert_output_contains 'rust'
assert_output_contains 'cargo'
[[ "$OUTPUT" != *java-25-openjdk-devel* ]] || {
  printf '%s\n' 'Version-pinned OpenJDK unexpectedly remains in the manifest' >&2
  exit 1
}

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$toolchain_module'; development_toolchain_validate_scope invalid"
assert_status 2
assert_output_contains 'Invalid development-toolchain scope'

run env HOME=/tmp/myunix-toolchain-home bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$toolchain_module'; development_toolchain_target_prefix user anaconda"
assert_status 0
assert_equals '/tmp/myunix-toolchain-home/.local/opt/anaconda3' "$OUTPUT"

temporary_home="$(mktemp -d)"
mkdir -p "$temporary_home/.config/sysrc.d"
printf '%s\n' 'old toolchain config' > "$temporary_home/.config/sysrc.d/development-toolchain.rc"
run env HOME="$temporary_home" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$toolchain_module'; development_toolchain_install_user_shell_config; cat \"\$HOME/.config/sysrc.d/development-toolchain.rc\""
assert_status 0
assert_output_contains 'anaconda3'
find "$temporary_home/.local/state/myunix/backups/development-toolchain" -name development-toolchain.rc -print -quit | grep -q . || {
  printf '%s\n' 'Expected toolchain shell-config backup' >&2
  exit 1
}

run bash -c "
  export MYUNIX_TEST_MODE=fedora
  source '$PROJECT_ROOT/scripts/lib/core.sh'
  source '$toolchain_module'
  development_toolchain_install_dnf_components() { printf 'dnf=%s\\n' \"\$1\"; }
  development_toolchain_install_portable_prerequisites() { printf 'prerequisites\\n'; }
  development_toolchain_install_anaconda() { printf 'anaconda=%s\\n' \"\$1\"; }
  development_toolchain_install_user_shell_config() { printf 'user-shell\\n'; }
  install_development_toolchain user jdk,cmake,anaconda
"
assert_status 0
assert_output_contains 'dnf=jdk,cmake,anaconda'
assert_output_contains 'prerequisites'
assert_output_contains 'anaconda=user'
assert_output_contains 'user-shell'
