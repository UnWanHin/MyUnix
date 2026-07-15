#!/usr/bin/env bash
set -Eeuo pipefail

# Small dependency-free terminal selectors for the interactive installer.
# Output values go to stdout; the visual menu is drawn on stderr so callers can
# safely capture a selection with command substitution.

ui_is_interactive() {
  [[ "${MYUNIX_UI_TEST_MODE:-}" == 1 ]] && return 0
  [[ -t 0 && -t 1 ]]
}

ui_require_interactive() {
  ui_is_interactive || {
    printf 'ERROR: Interactive installation requires a terminal. Use --all or --module instead.\n' >&2
    return 2
  }
}

ui_read_key() {
  local key rest
  IFS= read -rsn1 key || return 1
  case "$key" in
    $'\n'|$'\r') printf 'enter\n' ;;
    ' ') printf 'space\n' ;;
    $'\003') return 130 ;;
    $'\e')
      IFS= read -rsn2 rest || { printf 'escape\n'; return 0; }
      case "$rest" in
        '[A') printf 'up\n' ;;
        '[B') printf 'down\n' ;;
        *) printf 'escape\n' ;;
      esac
      ;;
    *) printf '%s\n' "$key" ;;
  esac
}

ui_render() {
  local title=$1 cursor=$2 selected_name=$3 locked_name=$4
  shift 4
  local -n ui_selected_ref="$selected_name" ui_locked_ref="$locked_name"
  local -a options=("$@")
  local index marker pointer option
  [[ "${MYUNIX_UI_NO_RENDER:-}" == 1 ]] && return 0

  printf '\033[H\033[2J%s\n' "$title" >&2
  printf 'Use ↑/↓ to move, Space to toggle, Enter to confirm.\n\n' >&2
  for ((index = 0; index < ${#options[@]}; index++)); do
    option=${options[$index]}
    marker='○'
    [[ "${ui_selected_ref[$index]:-0}" == 1 ]] && marker='●'
    pointer=' '
    [[ "$index" == "$cursor" ]] && pointer='›'
    if [[ "${ui_locked_ref[$index]:-0}" == 1 ]]; then
      printf '%s %s %s (required)\n' "$pointer" "$marker" "$option" >&2
    else
      printf '%s %s %s\n' "$pointer" "$marker" "$option" >&2
    fi
  done
}

ui_choose_one() {
  local title=$1
  shift
  local -a selected=(1) locked=(0)
  local cursor=0 key count=$#
  ((count > 0)) || { printf 'ERROR: ui_choose_one requires options.\n' >&2; return 2; }
  ui_require_interactive || return $?

  while :; do
    ui_render "$title" "$cursor" selected locked "$@"
    key="$(ui_read_key)" || return $?
    case "$key" in
      up) cursor=$(( (cursor + count - 1) % count )) ;;
      down) cursor=$(( (cursor + 1) % count )) ;;
      enter) printf '%s\n' "$cursor"; return 0 ;;
    esac
  done
}

ui_choose_many() {
  local title=$1 locked_csv=$2
  shift 2
  local -a selected=() locked=()
  local cursor=0 key count=$# index
  local IFS=','
  local -a locked_indices=($locked_csv)
  ((count > 0)) || { printf 'ERROR: ui_choose_many requires options.\n' >&2; return 2; }
  ui_require_interactive || return $?

  for ((index = 0; index < count; index++)); do
    selected[$index]=0
    locked[$index]=0
  done
  for index in "${locked_indices[@]}"; do
    [[ "$index" =~ ^[0-9]+$ ]] || continue
    ((index < count)) || continue
    locked[$index]=1
    selected[$index]=1
  done

  while :; do
    ui_render "$title" "$cursor" selected locked "$@"
    key="$(ui_read_key)" || return $?
    case "$key" in
      up) cursor=$(( (cursor + count - 1) % count )) ;;
      down) cursor=$(( (cursor + 1) % count )) ;;
      space)
        if [[ "${locked[$cursor]}" != 1 ]]; then
          selected[$cursor]=$(( 1 - selected[$cursor] ))
        fi
        ;;
      enter)
        for ((index = 0; index < count; index++)); do
          [[ "${selected[$index]}" == 1 ]] && printf '%s\n' "$index"
        done
        return 0
        ;;
    esac
  done
}

ui_choose_failure_action() {
  local module=$1 choice
  choice="$(ui_choose_one "${module} failed — choose what to do" 'Retry current module' 'Skip/defer and continue' 'Stop installation')" || return $?
  case "$choice" in
    0) printf 'retry\n' ;;
    1) printf 'skip\n' ;;
    2) printf 'stop\n' ;;
  esac
}
