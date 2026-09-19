#!/usr/bin/env bash
set -Eeuo pipefail
if ! declare -F require_command >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/core.sh"
fi

if ! declare -p ZSH_PERSONALIZATION_BLOCK_START >/dev/null 2>&1; then
  readonly ZSH_PERSONALIZATION_BLOCK_START='# >>> MyUnix Oh My Zsh personalization >>>'
  readonly ZSH_PERSONALIZATION_BLOCK_END='# <<< MyUnix Oh My Zsh personalization <<<'
fi

zsh_personalization_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

zsh_source_manifest() {
  printf '%s\n' "${MYUNIX_ZSH_SOURCE_MANIFEST:-$(zsh_personalization_dir)/sources.tsv}"
}

zsh_block_source() {
  printf '%s\n' "${MYUNIX_ZSH_BLOCK_SOURCE:-$(zsh_personalization_dir)/config/zshrc-oh-my-zsh.rc}"
}

zsh_p10k_source() {
  printf '%s\n' "${MYUNIX_ZSH_P10K_SOURCE:-$(zsh_personalization_dir)/config/p10k.zsh}"
}

zsh_backup_dir() {
  if [[ -z "${MYUNIX_ZSH_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_ZSH_ACTIVE_BACKUP_DIR="${MYUNIX_ZSH_BACKUP_DIR:-$HOME/.local/state/myunix/backups/zsh-personalization/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_ZSH_ACTIVE_BACKUP_DIR"
}

backup_zsh_personalization_file() {
  local source_file=$1 relative_path=$2 destination
  [[ -e "$source_file" ]] || return 0
  destination="$(zsh_backup_dir)/$relative_path"
  [[ -e "$destination" ]] && return 0
  mkdir -p "$(dirname "$destination")"
  cp -a "$source_file" "$destination"
}

validate_zsh_source_record() {
  local id=$1 url=$2 revision=$3 destination=$4
  [[ "$id" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]] || die "Invalid Zsh source ID: $id"
  [[ "$url" =~ ^https://github\.com/[[:alnum:]_.-]+/[[:alnum:]_.-]+\.git$ ]] || die "Invalid Zsh source URL: $url"
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || die "Invalid Zsh source revision: $revision"
  [[ "$destination" != /* && "$destination" != *'..'* && "$destination" != *$'\n'* ]] || die "Invalid Zsh source destination: $destination"
}

ensure_zsh_source_checkout() {
  local id=$1 url=$2 revision=$3 relative_destination=$4 destination actual
  validate_zsh_source_record "$id" "$url" "$revision" "$relative_destination"
  destination="$HOME/$relative_destination"
  if [[ -e "$destination" && ! -d "$destination/.git" ]]; then
    die "Refusing to replace unmanaged Zsh source path: $destination"
  fi
  if [[ -d "$destination/.git" ]]; then
    [[ -z "$(git -C "$destination" status --porcelain)" ]] || die "Refusing to overwrite modified Zsh source: $destination"
    git -C "$destination" fetch --depth=1 origin "$revision"
  else
    mkdir -p "$(dirname "$destination")"
    git clone --no-checkout "$url" "$destination"
  fi
  git -C "$destination" checkout --detach "$revision"
  actual="$(git -C "$destination" rev-parse HEAD)"
  [[ "$actual" == "$revision" ]] || die "Zsh source revision verification failed for $id"
}

install_zsh_source_repositories() {
  local manifest id url revision destination
  manifest="$(zsh_source_manifest)"
  [[ -r "$manifest" ]] || die "Missing Zsh source manifest: $manifest"
  require_command git
  while IFS='|' read -r id url revision destination; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    ensure_zsh_source_checkout "$id" "$url" "$revision" "$destination"
  done < "$manifest"
}

validate_zsh_personalization_block() {
  local rc_file=$1 starts ends
  [[ -e "$rc_file" ]] || return 0
  starts="$(grep -Fxc "$ZSH_PERSONALIZATION_BLOCK_START" "$rc_file" || true)"
  ends="$(grep -Fxc "$ZSH_PERSONALIZATION_BLOCK_END" "$rc_file" || true)"
  [[ "$starts" == "$ends" ]] || die "Malformed MyUnix Oh My Zsh block in $rc_file"
}

install_zsh_personalization_block() {
  local rc_file=$HOME/.zshrc block temporary
  block="$(zsh_block_source)"
  [[ -f "$block" ]] || die "Missing Zsh personalization block: $block"
  validate_zsh_personalization_block "$rc_file"
  temporary="$(mktemp "${rc_file}.myunix.XXXXXX")"
  if [[ -e "$rc_file" ]]; then
    awk -v start="$ZSH_PERSONALIZATION_BLOCK_START" -v end="$ZSH_PERSONALIZATION_BLOCK_END" '
      $0 == start { in_block = 1; next }
      $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$rc_file" > "$temporary"
  fi
  printf '%s\n' "$ZSH_PERSONALIZATION_BLOCK_START" >> "$temporary"
  cat "$block" >> "$temporary"
  printf '%s\n' "$ZSH_PERSONALIZATION_BLOCK_END" >> "$temporary"
  if [[ -e "$rc_file" ]] && cmp -s "$temporary" "$rc_file"; then
    rm -f "$temporary"
    return 0
  fi
  backup_zsh_personalization_file "$rc_file" '.zshrc'
  mv "$temporary" "$rc_file"
}

install_zsh_p10k_config() {
  local source target=$HOME/.p10k.zsh
  source="$(zsh_p10k_source)"
  [[ -f "$source" ]] || die "Missing Powerlevel10k configuration: $source"
  if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
    return 0
  fi
  backup_zsh_personalization_file "$target" '.p10k.zsh'
  install -m 0600 "$source" "$target"
}

install_zsh_personalization() {
  require_command zsh
  install_zsh_source_repositories
  install_zsh_personalization_block
  install_zsh_p10k_config
  info 'Oh My Zsh, Powerlevel10k, and public Zsh plugins installed'
}
