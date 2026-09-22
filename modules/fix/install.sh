#!/usr/bin/env bash
set -Eeuo pipefail

# The repair dispatcher owns selection and confirmation.  Individual repair
# modules register their read-only diagnosis, plan, bounded apply step, and
# focused verifier through fix_register_repair below.
FIX_CATEGORY_LABELS=(
  'Input method and application compatibility'
  'Niri + DMS session'
  'Desktop application integration'
  'Network and captive portal'
  'Development tools'
)

declare -a FIX_REPAIR_ID_LIST=()
declare -A FIX_REPAIR_CATEGORY_MAP=()
declare -A FIX_REPAIR_LABEL_MAP=()
declare -A FIX_REPAIR_NOTE_MAP=()

fix_register_repair() {
  local repair_id=$1 category=$2 label=$3 note=${4:-}
  local registered_id valid_category=0

  [[ -n "$repair_id" && "$repair_id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
    printf 'ERROR: Invalid repair identifier: %s\n' "$repair_id" >&2
    return 2
  }
  [[ -n "$category" && -n "$label" ]] || {
    printf 'ERROR: Repair registration requires a category and label: %s\n' "$repair_id" >&2
    return 2
  }
  for registered_id in "${FIX_CATEGORY_LABELS[@]}"; do
    if [[ "$registered_id" == "$category" ]]; then
      valid_category=1
      break
    fi
  done
  ((valid_category == 1)) || {
    printf 'ERROR: Invalid repair category for %s: %s\n' "$repair_id" "$category" >&2
    return 2
  }
  for registered_id in "${FIX_REPAIR_ID_LIST[@]}"; do
    [[ "$registered_id" != "$repair_id" ]] || {
      printf 'ERROR: Duplicate repair identifier: %s\n' "$repair_id" >&2
      return 2
    }
  done

  FIX_REPAIR_ID_LIST+=("$repair_id")
  FIX_REPAIR_CATEGORY_MAP["$repair_id"]=$category
  FIX_REPAIR_LABEL_MAP["$repair_id"]=$label
  FIX_REPAIR_NOTE_MAP["$repair_id"]=$note
}

fix_repair_ids() {
  ((${#FIX_REPAIR_ID_LIST[@]} == 0)) || printf '%s\n' "${FIX_REPAIR_ID_LIST[@]}"
}

fix_repair_category() {
  local repair_id=$1
  [[ -n "${FIX_REPAIR_CATEGORY_MAP[$repair_id]:-}" ]] || return 1
  printf '%s\n' "${FIX_REPAIR_CATEGORY_MAP[$repair_id]}"
}

fix_repair_label() {
  local repair_id=$1
  [[ -n "${FIX_REPAIR_LABEL_MAP[$repair_id]:-}" ]] || return 1
  printf '%s\n' "${FIX_REPAIR_LABEL_MAP[$repair_id]}"
}

fix_repair_note() {
  local repair_id=$1
  [[ -n "${FIX_REPAIR_NOTE_MAP[$repair_id]:-}" ]] || return 1
  printf '%s\n' "${FIX_REPAIR_NOTE_MAP[$repair_id]}"
}

fix_choose_category() {
  local choice
  choice="$(ui_choose_one 'MyUnix repair' "${FIX_CATEGORY_LABELS[@]}")" || return $?
  [[ "$choice" =~ ^[0-9]+$ && "$choice" -lt "${#FIX_CATEGORY_LABELS[@]}" ]] || {
    printf 'ERROR: Invalid repair category selection: %s\n' "$choice" >&2
    return 2
  }
  printf '%s\n' "${FIX_CATEGORY_LABELS[$choice]}"
}

fix_choose_repair() {
  local category=$1 repair_id choice
  local -a repair_ids=() repair_labels=()

  while IFS= read -r repair_id; do
    [[ -n "$repair_id" ]] || continue
    [[ "$(fix_repair_category "$repair_id" 2>/dev/null || true)" == "$category" ]] || continue
    repair_ids+=("$repair_id")
    repair_labels+=("$(fix_repair_label "$repair_id")")
  done < <(fix_repair_ids)

  if ((${#repair_ids[@]} == 0)); then
    printf 'No repairs are registered for %s.\n' "$category" >&2
    return 1
  fi

  choice="$(ui_choose_one "$category" "${repair_labels[@]}")" || return $?
  [[ "$choice" =~ ^[0-9]+$ && "$choice" -lt "${#repair_ids[@]}" ]] || {
    printf 'ERROR: Invalid repair selection: %s\n' "$choice" >&2
    return 2
  }
  printf '%s\n' "${repair_ids[$choice]}"
}

fix_run_selected() {
  local repair_id=$1 label diagnosis_output plan_output candidate
  local diagnose_fn="fix_diagnose_$repair_id"
  local plan_fn="fix_plan_$repair_id"
  local apply_fn="fix_apply_$repair_id"
  local verify_fn="fix_verify_$repair_id"

  if ! declare -F "$diagnose_fn" >/dev/null 2>&1; then
    printf 'ERROR: Repair has no diagnosis function: %s\n' "$repair_id" >&2
    return 2
  fi
  if ! declare -F "$plan_fn" >/dev/null 2>&1; then
    printf 'ERROR: Repair has no plan function: %s\n' "$repair_id" >&2
    return 2
  fi
  if ! declare -F "$apply_fn" >/dev/null 2>&1; then
    printf 'ERROR: Repair has no apply function: %s\n' "$repair_id" >&2
    return 2
  fi
  if ! declare -F "$verify_fn" >/dev/null 2>&1; then
    printf 'ERROR: Repair has no verifier function: %s\n' "$repair_id" >&2
    return 2
  fi

  label=$repair_id
  if candidate="$(fix_repair_label "$repair_id" 2>/dev/null)" && [[ -n "$candidate" ]]; then
    label=$candidate
  fi

  printf '%s\n' "$label"
  printf '%s\n' 'Diagnosis:'
  if diagnosis_output="$("$diagnose_fn")"; then
    [[ -z "$diagnosis_output" ]] || printf '%s\n' "$diagnosis_output"
    printf '%s\n' 'diagnosis clean; no change needed'
    return 0
  fi
  [[ -z "$diagnosis_output" ]] || printf '%s\n' "$diagnosis_output"

  if ! plan_output="$("$plan_fn")"; then
    printf 'ERROR: Could not render the repair plan: %s\n' "$repair_id" >&2
    return 1
  fi
  printf '%s\n' 'Plan:'
  [[ -z "$plan_output" ]] || printf '%s\n' "$plan_output"

  if ! ui_confirm 'Apply this repair?'; then
    printf '%s\n' 'cancelled'
    return 0
  fi

  if ! "$apply_fn"; then
    printf '%s\n' 'repair failed' >&2
    return 1
  fi
  if ! "$verify_fn"; then
    printf '%s\n' 'repair failed: verification did not pass' >&2
    return 1
  fi
  printf '%s\n' 'repaired and verified'
}

run_fix() {
  local category repair_id
  ui_require_interactive repair || return $?
  category="$(fix_choose_category)" || return $?
  repair_id="$(fix_choose_repair "$category")" || return $?
  fix_run_selected "$repair_id"
}
