#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/modules/jetbrains-toolbox/install.sh"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/source/jetbrains-toolbox-1.0"
printf '%s\n' '#!/usr/bin/env bash' 'printf "JetBrains Toolbox test\\n"' > "$temporary/source/jetbrains-toolbox-1.0/jetbrains-toolbox"
chmod 0755 "$temporary/source/jetbrains-toolbox-1.0/jetbrains-toolbox"
tar -czf "$temporary/toolbox.tar.gz" -C "$temporary/source" jetbrains-toolbox-1.0

run env HOME="$temporary/home" MYUNIX_JETBRAINS_TOOLBOX_ARCHIVE="$temporary/toolbox.tar.gz" MYUNIX_JETBRAINS_TOOLBOX_ROOT="$temporary/home/.local/opt/jetbrains-toolbox" MYUNIX_JETBRAINS_TOOLBOX_BIN="$temporary/home/.local/bin/jetbrains-toolbox" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/jetbrains-toolbox/install.sh'; wrapper() { install_jetbrains_toolbox; }; wrapper; test -x '$temporary/home/.local/bin/jetbrains-toolbox'; cat '$temporary/home/.local/opt/jetbrains-toolbox/.myunix-managed'"
assert_status 0
assert_output_contains 'Managed by MyUnix'

mkdir -p "$temporary/root"
printf '%s\n' '#!/usr/bin/env bash' 'printf "JetBrains Toolbox root test\n"' > "$temporary/root/jetbrains-toolbox"
chmod 0755 "$temporary/root/jetbrains-toolbox"
tar -czf "$temporary/root-toolbox.tar.gz" -C "$temporary/root" jetbrains-toolbox
run env HOME="$temporary/home" MYUNIX_JETBRAINS_TOOLBOX_ARCHIVE="$temporary/root-toolbox.tar.gz" MYUNIX_JETBRAINS_TOOLBOX_ROOT="$temporary/home/.local/opt/jetbrains-toolbox-root" MYUNIX_JETBRAINS_TOOLBOX_BIN="$temporary/home/.local/bin/jetbrains-toolbox-root" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/jetbrains-toolbox/install.sh'; install_jetbrains_toolbox; test -x '$temporary/home/.local/bin/jetbrains-toolbox-root'"
assert_status 0

mkdir -p "$temporary/unsafe"
printf '%s\n' 'payload' > "$temporary/unsafe/payload"
tar -czf "$temporary/unsafe.tar.gz" -C "$temporary/unsafe" payload
run env HOME="$temporary/home" MYUNIX_JETBRAINS_TOOLBOX_ARCHIVE="$temporary/unsafe.tar.gz" MYUNIX_JETBRAINS_TOOLBOX_ROOT="$temporary/home/.local/opt/another" bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$PROJECT_ROOT/modules/jetbrains-toolbox/install.sh'; install_jetbrains_toolbox"
assert_status 2
assert_output_contains 'no expected executable'
