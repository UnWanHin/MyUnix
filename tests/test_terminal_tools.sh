#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"
source "$PROJECT_ROOT/scripts/lib/manifest.sh"
source "$PROJECT_ROOT/modules/terminal-tools/install.sh"

validate_dnf_manifest "$PROJECT_ROOT/modules/terminal-tools/packages.txt"
for package in fzf tmux mosh zoxide bat btop ripgrep fd-find git-delta; do
  grep -Fxq "$package" "$PROJECT_ROOT/modules/terminal-tools/packages.txt"
done
grep -Fq '0d9dbfc26068b218e7ed84b104748cadc6e3cf733c0afd35465306fb39b9523c' "$PROJECT_ROOT/modules/terminal-tools/install.sh"
grep -Fq 'zoxide init zsh --cmd j' "$PROJECT_ROOT/modules/zsh-personalization/config/zshrc-oh-my-zsh.rc"
grep -Fq 'key-bindings.zsh' "$PROJECT_ROOT/modules/zsh-personalization/config/zshrc-oh-my-zsh.rc"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
printf '%s\n' 'unmanaged' > "$temporary/lazydocker"
chmod 0755 "$temporary/lazydocker"
run env MYUNIX_LAZYDOCKER_TARGET="$temporary/lazydocker" bash -c "source '$PROJECT_ROOT/modules/terminal-tools/install.sh'; install_terminal_tools_lazydocker"
assert_status 2
assert_output_contains 'Refusing to replace an unmanaged'
