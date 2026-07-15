#!/usr/bin/env bash
set -Eeuo pipefail

readonly SHELL_CONFIG_BLOCK_START='# >>> MyUnix shared shell configuration >>>'
readonly SHELL_CONFIG_BLOCK_END='# <<< MyUnix shared shell configuration <<<'

shell_config_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

shell_config_source_dir() {
  printf '%s\n' "${MYUNIX_SHELL_CONFIG_SOURCE:-$(shell_config_dir)/config}"
}

shell_config_target_dir() {
  printf '%s\n' "${MYUNIX_SHELL_CONFIG_TARGET_DIR:-$HOME/.config}"
}

shell_config_backup_dir() {
  if [[ -z "${MYUNIX_SHELL_CONFIG_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_SHELL_CONFIG_ACTIVE_BACKUP_DIR="${MYUNIX_SHELL_CONFIG_BACKUP_DIR:-$HOME/.local/state/myunix/backups/shell-config/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_SHELL_CONFIG_ACTIVE_BACKUP_DIR"
}

backup_shell_config_file() {
  local source_file=$1 relative_path=$2 backup_file
  [[ -e "$source_file" ]] || return 0

  backup_file="$(shell_config_backup_dir)/$relative_path"
  [[ -e "$backup_file" ]] && return 0
  mkdir -p "$(dirname "$backup_file")"
  cp -a "$source_file" "$backup_file"
}

copy_shell_config_file() {
  local source_file=$1 target_file=$2 relative_path=$3
  if [[ -e "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    return 0
  fi

  backup_shell_config_file "$target_file" "$relative_path"
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
}

import_shell_config() {
  local source_dir target_dir fragment
  source_dir="$(shell_config_source_dir)"
  target_dir="$(shell_config_target_dir)"

  [[ -f "$source_dir/.sysrc" ]] || die "Missing shared shell entry point: $source_dir/.sysrc"
  copy_shell_config_file "$source_dir/.sysrc" "$target_dir/.sysrc" '.sysrc'
  for fragment in env.rc aliases.rc functions.rc; do
    [[ -f "$source_dir/sysrc.d/$fragment" ]] || die "Missing shared shell fragment: $source_dir/sysrc.d/$fragment"
    copy_shell_config_file "$source_dir/sysrc.d/$fragment" "$target_dir/sysrc.d/$fragment" "sysrc.d/$fragment"
  done
}

validate_shell_config_block() {
  local rc_file=$1 starts ends
  [[ -e "$rc_file" ]] || return 0
  starts="$(grep -Fxc "$SHELL_CONFIG_BLOCK_START" "$rc_file" || true)"
  ends="$(grep -Fxc "$SHELL_CONFIG_BLOCK_END" "$rc_file" || true)"
  [[ "$starts" == "$ends" ]] || die "Malformed MyUnix shared-shell block in $rc_file"
}

install_shell_rc_source() {
  local rc_file=$1 temporary_file
  mkdir -p "$(dirname "$rc_file")"
  validate_shell_config_block "$rc_file"
  temporary_file="$(mktemp "${rc_file}.myunix.XXXXXX")"

  if [[ -e "$rc_file" ]]; then
    awk -v start="$SHELL_CONFIG_BLOCK_START" -v end="$SHELL_CONFIG_BLOCK_END" '
      $0 == start { in_block = 1; next }
      $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$rc_file" > "$temporary_file"
  fi

  printf '%s\n%s\n%s\n' \
    "$SHELL_CONFIG_BLOCK_START" \
    '[ -r "$HOME/.config/.sysrc" ] && . "$HOME/.config/.sysrc"' \
    "$SHELL_CONFIG_BLOCK_END" >> "$temporary_file"

  if [[ -e "$rc_file" ]] && cmp -s "$temporary_file" "$rc_file"; then
    rm -f "$temporary_file"
    return 0
  fi

  backup_shell_config_file "$rc_file" "shell/${rc_file##*/}"
  mv "$temporary_file" "$rc_file"
}

install_shell_config() {
  import_shell_config
  install_shell_rc_source "$HOME/.bashrc"
  install_shell_rc_source "$HOME/.zshrc"
  info 'Shared Bash/Zsh configuration installed at ~/.config/.sysrc'
}
