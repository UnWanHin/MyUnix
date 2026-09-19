#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"
source "$PROJECT_ROOT/scripts/lib/core.sh"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT
mkdir -p "$temporary_dir/home"
printf '%s\n' '# existing user config' > "$temporary_dir/home/.zshrc"

printf '%s\n' '# no source repositories in this isolated marker test' > "$temporary_dir/empty-sources.tsv"
run env HOME="$temporary_dir/home" MYUNIX_ZSH_SOURCE_MANIFEST="$temporary_dir/empty-sources.tsv" MYUNIX_ZSH_P10K_SOURCE="$PROJECT_ROOT/modules/zsh-personalization/config/p10k.zsh" bash -c '
  source "'$PROJECT_ROOT'/modules/zsh-personalization/install.sh"
  install_zsh_personalization
  install_zsh_personalization
  cat "$HOME/.zshrc"
'
assert_status 0
assert_output_contains 'ZSH_THEME="powerlevel10k/powerlevel10k"'
assert_equals 1 "$(grep -c '^# >>> MyUnix Oh My Zsh personalization >>>$' "$temporary_dir/home/.zshrc")"
[[ -f "$temporary_dir/home/.p10k.zsh" ]] || {
  printf '%s\n' 'Expected Powerlevel10k configuration to be installed' >&2
  exit 1
}
grep -q 'oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh.git|a5ecff7560b2e26f612032c632a12c75a3048bd0' "$PROJECT_ROOT/modules/zsh-personalization/sources.tsv" || {
  printf '%s\n' 'Expected pinned Oh My Zsh source manifest entry' >&2
  exit 1
}
grep -q 'zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|1d85c692615a25fe2293bdd44b34c217d5d2bf04' "$PROJECT_ROOT/modules/zsh-personalization/sources.tsv" || {
  printf '%s\n' 'Expected pinned syntax-highlighting source manifest entry' >&2
  exit 1
}
