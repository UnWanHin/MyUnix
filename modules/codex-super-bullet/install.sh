#!/usr/bin/env bash
set -Eeuo pipefail

readonly CODEX_SUPER_BULLET_BLOCK_START='<!-- >>> MyUnix SuperBullet mode >>> -->'
readonly CODEX_SUPER_BULLET_BLOCK_END='<!-- <<< MyUnix SuperBullet mode <<< -->'

codex_super_bullet_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

codex_super_bullet_source_dir() {
  printf '%s\n' "${MYUNIX_SUPER_BULLET_SOURCE_DIR:-$(codex_super_bullet_dir)/config}"
}

codex_super_bullet_home() {
  printf '%s\n' "${MYUNIX_CODEX_HOME:-${CODEX_HOME:-$HOME/.codex}}"
}

codex_super_bullet_bin_dir() {
  printf '%s\n' "${MYUNIX_SUPER_BULLET_BIN_DIR:-$HOME/.local/bin}"
}

codex_super_bullet_state_dir() {
  printf '%s\n' "${MYUNIX_SUPER_BULLET_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/myunix/backups/codex-super-bullet}"
}

codex_super_bullet_backup_dir() {
  if [[ -z "${MYUNIX_SUPER_BULLET_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_SUPER_BULLET_ACTIVE_BACKUP_DIR="${MYUNIX_SUPER_BULLET_BACKUP_DIR:-$(codex_super_bullet_state_dir)/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_SUPER_BULLET_ACTIVE_BACKUP_DIR"
}

backup_codex_super_bullet_file() {
  local target=$1 relative_path=$2 backup_file
  [[ -e "$target" ]] || return 0
  backup_file="$(codex_super_bullet_backup_dir)/$relative_path"
  [[ -e "$backup_file" ]] && return 0
  mkdir -p "$(dirname "$backup_file")"
  cp -a "$target" "$backup_file"
}

copy_codex_super_bullet_file() {
  local source_file=$1 target_file=$2 relative_path=$3 executable=${4:-0}
  if [[ -e "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    ((executable == 0)) || chmod +x "$target_file"
    return 0
  fi
  backup_codex_super_bullet_file "$target_file" "$relative_path"
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
  ((executable == 0)) || chmod +x "$target_file"
}

install_codex_super_bullet_agents() {
  local source_file="$1" target_file="$2" temporary_file starts ends
  mkdir -p "$(dirname "$target_file")"
  if [[ ! -e "$target_file" ]]; then
    cp -a "$source_file" "$target_file"
    return 0
  fi

  starts="$(grep -Fxc "$CODEX_SUPER_BULLET_BLOCK_START" "$target_file" || true)"
  ends="$(grep -Fxc "$CODEX_SUPER_BULLET_BLOCK_END" "$target_file" || true)"
  [[ "$starts" == "$ends" ]] || die "Malformed SuperBullet block in $target_file"
  temporary_file="$(mktemp "${target_file}.myunix.XXXXXX")"
  awk -v start="$CODEX_SUPER_BULLET_BLOCK_START" -v end="$CODEX_SUPER_BULLET_BLOCK_END" '
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    !in_block { lines[++count] = $0 }
    END {
      while (count > 0 && lines[count] == "") count--
      for (i = 1; i <= count; i++) print lines[i]
    }
  ' "$target_file" > "$temporary_file"
  [[ ! -s "$temporary_file" ]] || printf '\n' >> "$temporary_file"
  awk -v start="$CODEX_SUPER_BULLET_BLOCK_START" '$0 == start { found = 1 } found { print }' "$source_file" >> "$temporary_file"
  if cmp -s "$temporary_file" "$target_file"; then
    rm -f "$temporary_file"
    return 0
  fi
  backup_codex_super_bullet_file "$target_file" 'AGENTS.md'
  mv "$temporary_file" "$target_file"
}

install_codex_super_bullet() {
  local source_dir home bin_dir
  is_fedora || die 'Fedora is required'
  source_dir="$(codex_super_bullet_source_dir)"
  home="$(codex_super_bullet_home)"
  bin_dir="$(codex_super_bullet_bin_dir)"

  [[ -f "$source_dir/AGENTS.md" ]] || die "Missing SuperBullet AGENTS template: $source_dir/AGENTS.md"
  [[ -f "$source_dir/super-bullet.config.toml" ]] || die 'Missing SuperBullet profile template'
  [[ -f "$source_dir/skills/super-bullet/SKILL.md" ]] || die 'Missing SuperBullet skill template'
  [[ -f "$(codex_super_bullet_dir)/bin/super-bullet" ]] || die 'Missing SuperBullet launcher'

  install_codex_super_bullet_agents "$source_dir/AGENTS.md" "$home/AGENTS.md"
  copy_codex_super_bullet_file "$source_dir/super-bullet.config.toml" "$home/super-bullet.config.toml" 'super-bullet.config.toml'
  copy_codex_super_bullet_file "$source_dir/skills/super-bullet/SKILL.md" "$home/skills/super-bullet/SKILL.md" 'skills/super-bullet/SKILL.md'
  copy_codex_super_bullet_file "$(codex_super_bullet_dir)/bin/super-bullet" "$bin_dir/super-bullet" 'bin/super-bullet' 1
  info "Codex SuperBullet installed under $home; launcher: $bin_dir/super-bullet"
}
