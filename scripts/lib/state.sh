#!/usr/bin/env bash
set -Eeuo pipefail

state_file() {
  printf '%s/runs.tsv\n' "$(state_dir)"
}

state_mark() {
  local item=$1 status=$2 file tmp
  case "$status" in succeeded|skipped|failed|deferred) ;; *) die "Invalid item status: $status" ;; esac
  mkdir -p "$(state_dir)"
  file="$(state_file)"
  tmp="$(mktemp "$(state_dir)/runs.tsv.XXXXXX")"
  [[ -f "$file" ]] && awk -F'|' -v item="$item" '$1 != item { print }' "$file" > "$tmp"
  printf '%s|%s\n' "$item" "$status" >> "$tmp"
  mv "$tmp" "$file"
}

state_failed_items() {
  local file
  file="$(state_file)"
  [[ -f "$file" ]] || return 0
  awk -F'|' '$2 == "failed" || $2 == "deferred" { print $1 }' "$file" | sort
}

state_reset() {
  rm -f -- "$(state_file)"
}
