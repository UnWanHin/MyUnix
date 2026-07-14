#!/usr/bin/env bash
set -Eeuo pipefail

is_comment_or_blank() {
  [[ -z "${1//[[:space:]]/}" || "$1" =~ ^[[:space:]]*# ]]
}

validate_dnf_manifest() {
  local file=$1 line
  [[ -r "$file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    [[ "$line" =~ ^[[:alnum:]@._+:-]+$ ]] || return 1
  done < "$file"
}

validate_rpm_manifest() {
  local file=$1 id name url checksum selection verify_command verify_argument extra
  [[ -r "$file" ]] || return 1

  while IFS='|' read -r id name url checksum selection verify_command verify_argument extra; do
    is_comment_or_blank "$id" && continue
    [[ -z "$name" || -n "$extra" ]] && return 1
    [[ "$id" =~ ^[[:alnum:]_-]+$ ]] || return 1
    [[ "$url" =~ ^https:// ]] || return 1
    [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    [[ "$selection" == default || "$selection" == optional ]] || return 1
    [[ "$verify_command" =~ ^[[:alnum:]_.+-]+$ ]] || return 1
    [[ "$verify_argument" =~ ^[[:alnum:]@._+:-]+$ ]] || return 1
  done < "$file"
}
