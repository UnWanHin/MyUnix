#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

run bash -c '
  dnf() {
    local package="${!#}"
    [[ "$package" == missing-package ]] && return 1
    printf "%s\\n" "$package"
  }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  manifest="$(mktemp)"
  printf "%s\n" git missing-package > "$manifest"
  verify_dnf_manifest_available "$manifest"
'
assert_status 1
assert_output_contains 'Missing DNF package from enabled repositories: missing-package'

run bash -c '
  dnf() { return 0; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  manifest="$(mktemp)"
  printf "%s\\n" empty-package > "$manifest"
  verify_dnf_manifest_available "$manifest"
'
assert_status 1
assert_output_contains 'Missing DNF package from enabled repositories: empty-package'

run env MYUNIX_DNF_QUERY_TIMEOUT_SECONDS=17 bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  dnf_query_timeout_seconds
'
assert_status 0
assert_equals 17 "$OUTPUT"

run bash -c '
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  validate_dnf_manifest "'"$PROJECT_ROOT"'/modules/niri-dms/packages.txt"
  rg -Fx dms "'"$PROJECT_ROOT"'/modules/niri-dms/packages.txt"
  rg -Fx niri "'"$PROJECT_ROOT"'/modules/niri-dms/packages.txt"
  rg -Fx quickshell "'"$PROJECT_ROOT"'/modules/niri-dms/packages.txt"
'
assert_status 0

run bash -c '
  rg -Fx wget2-wget "'"$PROJECT_ROOT"'/modules/dnf/core.txt"
  ! rg -Fx wget "'"$PROJECT_ROOT"'/modules/dnf/core.txt"
  rg -Fx "build-tools|package|wget2-wget" "'"$PROJECT_ROOT"'/modules/development-toolchain/packages.tsv"
  rg -Fx "build-tools|package|ShellCheck" "'"$PROJECT_ROOT"'/modules/development-toolchain/packages.tsv"
  rg -Fx ShellCheck "'"$PROJECT_ROOT"'/modules/development-toolchain/packages.txt"
  rg -Fx wget2-wget "'"$PROJECT_ROOT"'/modules/development-toolchain/packages.txt"
'
assert_status 0

temporary_bin="$(mktemp -d)"
mkdir -p "$temporary_bin/bin"
printf '%s\n' '#!/usr/bin/env bash' '[[ "$*" == *kdeconnectd* ]] && exit 1' 'printf "%s\n" "${!#}"' > "$temporary_bin/bin/dnf"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$temporary_bin/bin/dconf"
chmod +x "$temporary_bin/bin/dnf" "$temporary_bin/bin/dconf"
run env MYUNIX_TEST_MODE=fedora PATH="$temporary_bin/bin:$PATH" "$PROJECT_ROOT/scripts/myunix" doctor
assert_status 2
assert_output_contains 'Missing DNF package from enabled repositories: kdeconnectd'

temporary_export="$(mktemp -d)"
run env MYUNIX_DNF_EXPORTED_USERINSTALLED_TARGET="$temporary_export/exported-userinstalled.txt" bash -c '
  dnf() { printf "%s\n" zsh git zsh; }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/export.sh"
  export_userinstalled_dnf_candidates
  tail -n +1 "$MYUNIX_DNF_EXPORTED_USERINSTALLED_TARGET"
'
assert_status 0
assert_output_contains $'git\nzsh'

run env MYUNIX_DNF_EXPORTED_REPOSITORIES_TARGET="$temporary_export/exported-enabled-repositories.txt" bash -c '
  dnf() {
    printf "%s\\n" "repo id repo name" updates fedora updates
  }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/export.sh"
  export_enabled_dnf_repositories
  cat "$MYUNIX_DNF_EXPORTED_REPOSITORIES_TARGET"
'
assert_status 0
assert_output_contains $'fedora\nupdates'
