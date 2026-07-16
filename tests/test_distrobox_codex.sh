#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

module="$PROJECT_ROOT/modules/distrobox-codex/install.sh"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$module'; distrobox_codex_container_name"
assert_status 0
assert_equals 'ubuntu22' "$OUTPUT"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$module'; MYUNIX_CODEX_CONTAINER=ubuntu-dev; distrobox_codex_container_name"
assert_status 0
assert_equals 'ubuntu-dev' "$OUTPUT"

run bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$module'; distrobox_codex_home"
assert_status 0
assert_equals '/opt/distrobox/ubuntu22/.codex' "$OUTPUT"

temporary_state="$(mktemp -d)"
run env MYUNIX_TEST_MODE=fedora XDG_STATE_HOME="$temporary_state" bash -c '
  distrobox() {
    local argument status_file=
    printf "distrobox %s\\n" "$*"
    for argument in "$@"; do
      case "$argument" in
        MYUNIX_CODEX_STATUS_FILE=*) status_file="${argument#*=}" ;;
      esac
    done
    mkdir -p "$(dirname "$status_file")"
    printf succeeded > "$status_file"
  }
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$module"'"
  install_distrobox_codex
'
assert_status 0
assert_output_contains 'distrobox enter ubuntu22 -- env'
assert_output_contains 'MYUNIX_CODEX_HOME=/opt/distrobox/ubuntu22/.codex'
assert_output_contains 'bash'

bootstrap="$PROJECT_ROOT/modules/distrobox-codex/container-bootstrap.sh"
run test -f "$bootstrap"
assert_status 0
run grep -F 'https://nodejs.org/dist/index.json' "$bootstrap"
assert_status 0
run grep -F 'SHASUMS256.txt' "$bootstrap"
assert_status 0
run grep -F 'sha256sum --check' "$bootstrap"
assert_status 0
run grep -F '@openai/codex' "$bootstrap"
assert_status 0
run grep -F '/usr/local/bin/codex' "$bootstrap"
assert_status 0
run grep -F 'MYUNIX_CODEX_HOME' "$bootstrap"
assert_status 0
run grep -F 'export CODEX_HOME=' "$bootstrap"
assert_status 0

run grep -F 'source "$ROOT/modules/distrobox-codex/install.sh"' "$PROJECT_ROOT/scripts/myunix"
assert_status 0
run grep -F 'distrobox-codex) install_distrobox_codex' "$PROJECT_ROOT/scripts/myunix"
assert_status 0
