#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/niri-dms/install.sh"

run env MYUNIX_FEDORA_RELEASE=42 bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/niri-dms/install.sh'; require_dms_supported_fedora"
assert_status 2
assert_output_contains 'DMS is supported only on Fedora 43 or 44'
