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
  local function_suffix=${repair_id//-/_}
  local diagnose_fn="fix_diagnose_$function_suffix"
  local plan_fn="fix_plan_$function_suffix"
  local apply_fn="fix_apply_$function_suffix"
  local verify_fn="fix_verify_$function_suffix"

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

fix_wechat_fcitx_profile_path() {
  printf '%s\n' "${MYUNIX_FCITX_PROFILE:-$HOME/.config/fcitx5/profile}"
}

fix_wechat_launcher_override_path() {
  local desktop_file=$1
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$desktop_file"
}

fix_wechat_installed_launcher_variants() {
  if declare -F input_method_installed_launcher_variants >/dev/null 2>&1; then
    input_method_installed_launcher_variants wechat
    return
  fi

  local system_dir flatpak_user_dir source_dir desktop_file
  system_dir="${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
  flatpak_user_dir="${MYUNIX_FLATPAK_USER_APPLICATIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications}"
  while IFS='|' read -r source_dir desktop_file; do
    [[ -f "$source_dir/$desktop_file" ]] || continue
    printf '%s|%s|qt-fcitx\n' "$desktop_file" "$source_dir/$desktop_file"
  done < <(
    printf '%s\n' "$system_dir|wechat.desktop"
    printf '%s\n' "$flatpak_user_dir|com.tencent.WeChat.desktop"
    if [[ -n "${MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR:-}" ]]; then
      printf '%s|%s\n' "$MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR" com.tencent.WeChat.desktop
    else
      printf '%s|%s\n' /var/lib/flatpak/exports/share/applications com.tencent.WeChat.desktop
      printf '%s|%s\n' /usr/share/flatpak/exports/share/applications com.tencent.WeChat.desktop
    fi
  )
}

fix_diagnose_wechat_cangjie() {
  local missing=0 profile launcher desktop_file source_launcher variants
  profile="$(fix_wechat_fcitx_profile_path)"

  if command -v fcitx5 >/dev/null 2>&1; then
    printf '%s\n' '  - fcitx5: installed'
  else
    printf '%s\n' '  - fcitx5: missing'
    missing=1
  fi
  if command -v rpm >/dev/null 2>&1 && rpm -q fcitx5-chinese-addons >/dev/null 2>&1 && rpm -q fcitx5-table-extra >/dev/null 2>&1; then
    printf '%s\n' '  - Cangjie engine packages: installed'
  else
    printf '%s\n' '  - Cangjie engine packages: missing'
    missing=1
  fi
  if [[ -f "$profile" ]] && grep -Fqx 'Name=cangjie5' "$profile"; then
    printf '%s\n' "  - Fcitx5 Cangjie profile: present ($profile)"
  else
    printf '%s\n' "  - Fcitx5 Cangjie profile: missing ($profile)"
    missing=1
  fi

  variants="$(fix_wechat_installed_launcher_variants)"
  if [[ -z "$variants" ]]; then
    printf '%s\n' '  - WeChat launcher source: no supported RPM or Flatpak launcher installed'
    missing=1
  else
    while IFS='|' read -r desktop_file source_launcher _; do
      [[ -n "$desktop_file" && -n "$source_launcher" ]] || continue
      launcher="$(fix_wechat_launcher_override_path "$desktop_file")"
      if [[ -f "$launcher" ]]; then
        printf '%s\n' "  - WeChat launcher override: present ($launcher; source $source_launcher)"
      else
        printf '%s\n' "  - WeChat launcher override: missing ($launcher; source $source_launcher)"
        missing=1
      fi
    done <<< "$variants"
  fi
  return "$missing"
}

fix_plan_wechat_cangjie() {
  cat <<'EOF'
Install the Cangjie Fcitx5 packages and regenerate the public Fcitx5 profile, then install managed WeChat launcher overrides for each installed RPM or Flatpak launcher variant.
No Niri configuration is diagnosed or rewritten by this repair; use the Niri + DMS module for a missing session fragment.
Log out and back in to reload Fcitx5 and application environment variables.
EOF
}

fix_apply_wechat_cangjie() {
  install_input_methods 1 "${MYUNIX_INPUT_PINYIN:-1}"
  install_input_method_app_overrides
}

fix_verify_wechat_cangjie() {
  local profile variants desktop_file source_launcher launcher
  profile="$(fix_wechat_fcitx_profile_path)"
  [[ -f "$profile" ]] && grep -Fqx 'Name=cangjie5' "$profile" || return 1
  variants="$(fix_wechat_installed_launcher_variants)"
  [[ -n "$variants" ]] || return 1
  while IFS='|' read -r desktop_file source_launcher _; do
    [[ -n "$desktop_file" && -n "$source_launcher" ]] || continue
    launcher="$(fix_wechat_launcher_override_path "$desktop_file")"
    [[ -f "$launcher" ]] || return 1
  done <<< "$variants"
}

fix_niri_config_path() {
  printf '%s\n' "${MYUNIX_NIRI_CONFIG:-${MYUNIX_NIRI_CONFIG_DIR:-$HOME/.config/niri}/config.kdl}"
}

fix_niri_config_dir() {
  printf '%s\n' "${MYUNIX_NIRI_CONFIG_DIR:-$(dirname "$(fix_niri_config_path)")}"
}

fix_niri_touchpad_fragment_path() {
  printf '%s\n' "${MYUNIX_NIRI_TOUCHPAD_STATE_FILE:-$(fix_niri_config_dir)/myunix/touchpad.kdl}"
}

fix_niri_touchpad_binding_path() {
  printf '%s\n' "$(fix_niri_config_dir)/myunix/touchpad-bind.kdl"
}

fix_niri_toggle_helper_path() {
  printf '%s\n' "${MYUNIX_NIRI_DMS_BIN_DIR:-$HOME/.local/bin}/niri-touchpad-toggle"
}

fix_niri_module_touchpad_fragment_path() {
  printf '%s\n' "${MYUNIX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/modules/niri-dms/config/niri/myunix/touchpad.kdl"
}

fix_niri_include_present() {
  local config=$1 fragment=$2
  case "$fragment" in
    touchpad)
      grep -Eq '^[[:space:]]*include[[:space:]]+"myunix/touchpad\.kdl"([[:space:]]|$)' "$config"
      ;;
    binding)
      grep -Eq '^[[:space:]]*include[[:space:]]+optional[[:space:]]*=[[:space:]]*true[[:space:]]+"myunix/touchpad-bind\.kdl"([[:space:]]|$)' "$config"
      ;;
    *)
      return 2
      ;;
  esac
}

fix_niri_config_backup_dir() {
  printf '%s\n' "${MYUNIX_NIRI_REPAIR_BACKUP_DIR:-$HOME/.local/state/myunix/backups/niri-dms-repair/$(date +%Y%m%d-%H%M%S)}"
}

fix_niri_restore_missing_includes() {
  local config=${1:-$(fix_niri_config_path)} temporary backup_dir changed=0
  [[ -f "$config" ]] || return 1

  temporary="$(mktemp "${config}.myunix.XXXXXX")"
  cp -a "$config" "$temporary" || {
    rm -f "$temporary"
    return 1
  }
  if ! fix_niri_include_present "$temporary" touchpad; then
    printf '\n%s\n' 'include "myunix/touchpad.kdl"' >> "$temporary"
    changed=1
  fi
  if ! fix_niri_include_present "$temporary" binding; then
    printf '\n%s\n' 'include optional=true "myunix/touchpad-bind.kdl"' >> "$temporary"
    changed=1
  fi
  if ((changed == 1)); then
    backup_dir="$(fix_niri_config_backup_dir)"
    mkdir -p "$backup_dir"
    cp -a "$config" "$backup_dir/config.kdl" || {
      rm -f "$temporary"
      return 1
    }
    mv "$temporary" "$config"
  else
    rm -f "$temporary"
  fi
}

fix_niri_restore_touchpad_fragment() {
  local target source
  target="$(fix_niri_touchpad_fragment_path)"
  [[ -s "$target" ]] && return 0
  source="$(fix_niri_module_touchpad_fragment_path)"
  [[ -s "$source" ]] || {
    printf 'MyUnix Niri touchpad fragment source is unavailable: %s\n' "$source" >&2
    return 1
  }
  mkdir -p "$(dirname "$target")"
  cp -a "$source" "$target"
}

fix_niri_restore_toggle_helper() {
  local target
  target="$(fix_niri_toggle_helper_path)"
  [[ -x "$target" ]] && return 0
  declare -F install_niri_dms_touchpad_toggle >/dev/null 2>&1 || {
    printf '%s\n' 'Niri touchpad helper installer is unavailable.' >&2
    return 1
  }
  install_niri_dms_touchpad_toggle
}

fix_niri_binding_is_healthy() {
  local binding
  binding="$(fix_niri_touchpad_binding_path)"
  [[ -s "$binding" ]] \
    && grep -Fq 'Mod+F8' "$binding" \
    && grep -Fq 'niri-touchpad-toggle' "$binding"
}

fix_niri_restore_toggle_binding() {
  fix_niri_binding_is_healthy && return 0
  declare -F configure_niri_dms_touchpad_toggle_binding >/dev/null 2>&1 || {
    printf '%s\n' 'Niri touchpad binding helper is unavailable.' >&2
    return 1
  }
  MYUNIX_NIRI_DMS_TOUCHPAD_TOGGLE=1 configure_niri_dms_touchpad_toggle_binding
}

fix_reload_niri_if_running() {
  command -v niri >/dev/null 2>&1 || return 0
  niri msg action load-config-file >/dev/null 2>&1 || true
}

fix_diagnose_niri_config() {
  local config missing=0 validation_output fragment
  config="$(fix_niri_config_path)"

  if [[ -f "$config" ]]; then
    printf '%s\n' "  - Niri config: present ($config)"
  else
    printf '%s\n' "  - Niri config: missing ($config)"
    return 1
  fi

  if command -v niri >/dev/null 2>&1; then
    if validation_output="$(niri validate 2>&1)"; then
      printf '%s\n' '  - Niri validation: valid'
    else
      printf '%s\n' '  - Niri validation: invalid'
      [[ -z "$validation_output" ]] || printf '%s\n' "$validation_output"
      missing=1
    fi
  else
    printf '%s\n' '  - Niri validation: unavailable (niri command missing)'
  fi

  for fragment in touchpad binding; do
    if fix_niri_include_present "$config" "$fragment"; then
      printf '%s\n' "  - MyUnix $fragment include: present"
    else
      printf '%s\n' "  - MyUnix $fragment include: missing"
      missing=1
    fi
  done
  if [[ -s "$(fix_niri_touchpad_fragment_path)" ]]; then
    printf '%s\n' "  - MyUnix touchpad fragment: present ($(fix_niri_touchpad_fragment_path))"
  else
    printf '%s\n' "  - MyUnix touchpad fragment: missing ($(fix_niri_touchpad_fragment_path))"
    missing=1
  fi
  if [[ -s "$(fix_niri_touchpad_binding_path)" ]]; then
    printf '%s\n' "  - MyUnix touchpad binding: present ($(fix_niri_touchpad_binding_path))"
  else
    printf '%s\n' "  - MyUnix touchpad binding: missing ($(fix_niri_touchpad_binding_path))"
    missing=1
  fi
  return "$missing"
}

fix_plan_niri_config() {
  cat <<'EOF'
Validate the active Niri configuration and restore only missing MyUnix-owned touchpad fragments, binding, and include lines.
An invalid user config is reported with its validation output and is never replaced or rewritten by this repair.
No mouse settings, DMS private state, credentials, or session profiles are changed.
Reload Niri manually if the session is not running while the repair is applied.
EOF
}

fix_apply_niri_config() {
  local config validation_output
  config="$(fix_niri_config_path)"
  [[ -f "$config" ]] || return 1
  if command -v niri >/dev/null 2>&1 && ! validation_output="$(niri validate 2>&1)"; then
    printf '%s\n' 'Niri config is invalid; leaving the user config unchanged.' >&2
    [[ -z "$validation_output" ]] || printf '%s\n' "$validation_output" >&2
    return 1
  fi
  fix_niri_restore_touchpad_fragment || return $?
  fix_niri_restore_toggle_binding || return $?
  fix_niri_restore_missing_includes || return $?
  fix_reload_niri_if_running
}

fix_verify_niri_config() {
  fix_diagnose_niri_config >/dev/null
}

fix_diagnose_dms_service() {
  local missing=0
  if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' '  - systemctl: missing'
    return 1
  fi
  if systemctl --user is-enabled dms.service >/dev/null 2>&1; then
    printf '%s\n' '  - dms.service: enabled'
  else
    printf '%s\n' '  - dms.service: disabled or unavailable'
    missing=1
  fi
  if systemctl --user is-active dms.service >/dev/null 2>&1; then
    printf '%s\n' '  - dms.service: active'
  else
    printf '%s\n' '  - dms.service: inactive or unavailable'
    missing=1
  fi
  return "$missing"
}

fix_plan_dms_service() {
  cat <<'EOF'
Enable the existing user-level dms.service and start it for the current desktop user.
This repair uses systemctl --user only, never sudo, and does not reinstall DMS or change private DMS state.
Log out and back in if the service needs to be picked up by a new session.
EOF
}

fix_apply_dms_service() {
  declare -F enable_dms_user_service >/dev/null 2>&1 || {
    printf '%s\n' 'DMS user-service helper is unavailable.' >&2
    return 1
  }
  enable_dms_user_service || return $?
  systemctl --user start dms.service
}

fix_verify_dms_service() {
  systemctl --user is-enabled dms.service >/dev/null 2>&1 \
    && systemctl --user is-active dms.service >/dev/null 2>&1
}

fix_diagnose_touchpad_toggle() {
  local missing=0 config helper binding
  config="$(fix_niri_config_path)"
  helper="$(fix_niri_toggle_helper_path)"
  binding="$(fix_niri_touchpad_binding_path)"

  if [[ -x "$helper" ]]; then
    printf '%s\n' "  - Niri touchpad helper: present ($helper)"
  else
    printf '%s\n' "  - Niri touchpad helper: missing ($helper)"
    missing=1
  fi
  if [[ -f "$config" ]] && fix_niri_include_present "$config" touchpad; then
    printf '%s\n' '  - Niri touchpad include: present'
  else
    printf '%s\n' '  - Niri touchpad include: missing'
    missing=1
  fi
  if [[ -f "$config" ]] && fix_niri_include_present "$config" binding; then
    printf '%s\n' '  - Niri touchpad binding include: present'
  else
    printf '%s\n' '  - Niri touchpad binding include: missing'
    missing=1
  fi
  if fix_niri_binding_is_healthy; then
    printf '%s\n' "  - Niri Mod+F8 binding: present ($binding)"
  else
    printf '%s\n' "  - Niri Mod+F8 binding: missing or incomplete ($binding)"
    missing=1
  fi
  return "$missing"
}

fix_plan_touchpad_toggle() {
  cat <<'EOF'
Restore only the MyUnix Niri touchpad helper, Mod+F8 binding, and their managed config include lines.
The repair does not alter mouse or trackpoint settings, DMS private state, credentials, or application profiles.
When Niri is running it will opportunistically request `niri msg action load-config-file`; otherwise reload Niri in the next session.
EOF
}

fix_apply_touchpad_toggle() {
  fix_niri_restore_toggle_helper || return $?
  fix_niri_restore_toggle_binding || return $?
  fix_niri_restore_missing_includes || return $?
  fix_reload_niri_if_running
}

fix_verify_touchpad_toggle() {
  fix_diagnose_touchpad_toggle >/dev/null
}

fix_flclash_desktop_entry_path() {
  if declare -F flclash_desktop_entry_path >/dev/null 2>&1; then
    flclash_desktop_entry_path
  else
    printf '%s\n' "${MYUNIX_FLCLASH_DESKTOP_ENTRY:-${XDG_DATA_HOME:-$HOME/.local/share}/applications/flclash.desktop}"
  fi
}

fix_diagnose_flclash_launcher() {
  local missing=0 entry
  if command -v rpm >/dev/null 2>&1 && rpm -q FlClash >/dev/null 2>&1; then
    printf '%s\n' '  - FlClash RPM: installed'
  else
    printf '%s\n' '  - FlClash RPM: missing'
    missing=1
  fi
  if declare -F flclash_desktop_entry_exists >/dev/null 2>&1 && flclash_desktop_entry_exists; then
    entry="$(fix_flclash_desktop_entry_path)"
    printf '%s\n' "  - FlClash desktop launcher: present ($entry or the system entry)"
  else
    entry="$(fix_flclash_desktop_entry_path)"
    printf '%s\n' "  - FlClash desktop launcher: missing ($entry)"
    missing=1
  fi
  return "$missing"
}

fix_plan_flclash_launcher() {
  cat <<'EOF'
If the FlClash RPM is installed, create only the managed user desktop launcher and refresh the desktop application database when available.
This repair never reinstalls FlClash and never reads or changes FlClash profiles, subscriptions, or account state.
No logout is required; restart or refresh DMS if its launcher cache does not update immediately.
EOF
}

fix_apply_flclash_launcher() {
  command -v rpm >/dev/null 2>&1 && rpm -q FlClash >/dev/null 2>&1 || {
    printf '%s\n' 'FlClash is not installed; no automatic reinstaller is provided.' >&2
    return 1
  }
  declare -F install_flclash_desktop_entry >/dev/null 2>&1 || {
    printf '%s\n' 'FlClash desktop registration helper is unavailable.' >&2
    return 1
  }
  install_flclash_desktop_entry
}

fix_verify_flclash_launcher() {
  command -v rpm >/dev/null 2>&1 && rpm -q FlClash >/dev/null 2>&1 || return 1
  declare -F flclash_desktop_entry_exists >/dev/null 2>&1 || return 1
  flclash_desktop_entry_exists
}

fix_portal_login_bin_path() {
  printf '%s\n' "${MYUNIX_PORTAL_LOGIN_BIN_DIR:-$HOME/.local/bin}/myunix-portal-login"
}

fix_portal_login_desktop_path() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/myunix-portal-login.desktop"
}

fix_portal_login_autostart_path() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/myunix-nm-applet.desktop"
}

fix_diagnose_portal_login() {
  local missing=0 path
  if command -v nm-applet >/dev/null 2>&1; then
    printf '%s\n' '  - nm-applet: installed'
  else
    printf '%s\n' '  - nm-applet: missing'
    missing=1
  fi
  for path in "$(fix_portal_login_bin_path)" "$(fix_portal_login_desktop_path)" "$(fix_portal_login_autostart_path)"; do
    if [[ -f "$path" ]]; then
      printf '%s\n' "  - managed portal-login file: present ($path)"
    else
      printf '%s\n' "  - managed portal-login file: missing ($path)"
      missing=1
    fi
  done
  return "$missing"
}

fix_plan_portal_login() {
  cat <<'EOF'
Install the managed NetworkManager applet package and restore the portal-login command, Wi-Fi Login desktop entry, and user autostart entry.
The repair does not save or change Wi-Fi credentials or captive-portal account data.
Log out and back in so the user autostart entry is loaded.
EOF
}

fix_apply_portal_login() {
  install_portal_login
}

fix_verify_portal_login() {
  command -v nm-applet >/dev/null 2>&1 \
    && [[ -x "$(fix_portal_login_bin_path)" ]] \
    && [[ -f "$(fix_portal_login_desktop_path)" ]] \
    && [[ -f "$(fix_portal_login_autostart_path)" ]]
}

fix_diagnose_codex_fedora() {
  local missing=0 command_name
  for command_name in node npm codex; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf '%s\n' "  - $command_name: available"
    else
      printf '%s\n' "  - $command_name: missing"
      missing=1
    fi
  done
  return "$missing"
}

fix_plan_codex_fedora() {
  cat <<'EOF'
Install Fedora's nodejs/npm packages and refresh the official @openai/codex CLI through the existing Fedora Codex installer.
This repair never reads or changes ~/.codex/auth.json, provider settings, login state, or browser credentials.
No logout is required; start a new shell if its command search path is stale.
EOF
}

fix_apply_codex_fedora() {
  install_codex_fedora
}

fix_verify_codex_fedora() {
  local command_name
  for command_name in node npm codex; do
    command -v "$command_name" >/dev/null 2>&1 || return 1
  done
}

fix_toolchain_component_commands() {
  case "$1" in
    build-tools) printf '%s\n' gcc gdb make ;;
    jdk) printf '%s\n' java javac ;;
    cmake) printf '%s\n' cmake ;;
    ninja) printf '%s\n' ninja ;;
    rust) printf '%s\n' rustc cargo ;;
    python) printf '%s\n' python3 ;;
    anaconda) printf '%s\n' conda ;;
    node) printf '%s\n' node npm ;;
    go) printf '%s\n' go ;;
    gcc) printf '%s\n' gcc ;;
    clang) printf '%s\n' clang ;;
    *) return 1 ;;
  esac
}

fix_toolchain_component_names() {
  if declare -F development_toolchain_component_names >/dev/null 2>&1; then
    development_toolchain_component_names
  else
    printf '%s\n' build-tools jdk cmake ninja rust python anaconda node go gcc clang
  fi
}

fix_diagnose_development_toolchain() {
  local missing=0 component command_name all_present
  while IFS= read -r component; do
    all_present=1
    while IFS= read -r command_name; do
      if ! command -v "$command_name" >/dev/null 2>&1; then
        all_present=0
        missing=1
      fi
    done < <(fix_toolchain_component_commands "$component")
    if ((all_present == 1)); then
      printf '%s\n' "  - $component: available"
    else
      printf '%s\n' "  - $component: missing one or more commands"
    fi
  done < <(fix_toolchain_component_names)
  return "$missing"
}

fix_plan_development_toolchain() {
  local scope=${MYUNIX_TOOLCHAIN_SCOPE:-system}
  local components=${MYUNIX_TOOLCHAIN_COMPONENTS:-all registered components}
  printf 'Install or refresh the managed development-toolchain components (%s scope: %s) using the existing toolchain installer.\n' "$components" "$scope"
  printf '%s\n' 'Only the selected toolchain packages and their managed shell fragment are changed; no unrelated user configuration is scanned.'
  printf '%s\n' 'No logout is required; start a new shell if shell configuration or PATH changes are reported.'
}

fix_apply_development_toolchain() {
  install_development_toolchain "${MYUNIX_TOOLCHAIN_SCOPE:-system}" "${MYUNIX_TOOLCHAIN_COMPONENTS:-}"
}

fix_verify_development_toolchain() {
  fix_diagnose_development_toolchain >/dev/null
}

if [[ -z "${FIX_REPAIR_CATEGORY_MAP[wechat-cangjie]:-}" ]]; then
  fix_register_repair \
    wechat-cangjie \
    "${FIX_CATEGORY_LABELS[0]}" \
    'WeChat / Cangjie compatibility' \
    'Log out and back in after applying the public Fcitx5 and launcher repair.'
  fix_register_repair \
    niri-config \
    "${FIX_CATEGORY_LABELS[1]}" \
    'Niri configuration validation' \
    'Invalid user configuration is reported without replacement; only missing MyUnix-owned fragments are restored.'
  fix_register_repair \
    dms-service \
    "${FIX_CATEGORY_LABELS[1]}" \
    'DMS user service' \
    'Enable and start dms.service for the current desktop user after confirmation.'
  fix_register_repair \
    touchpad-toggle \
    "${FIX_CATEGORY_LABELS[1]}" \
    'Niri touchpad toggle' \
    'Restore the MyUnix helper, Mod+F8 binding and managed includes; reload Niri when running.'
  fix_register_repair \
    flclash-launcher \
    "${FIX_CATEGORY_LABELS[2]}" \
    'FlClash desktop launcher' \
    'No logout is required; refresh DMS if its launcher cache is stale.'
  fix_register_repair \
    portal-login \
    "${FIX_CATEGORY_LABELS[3]}" \
    'Captive portal login integration' \
    'Log out and back in after restoring the user autostart entry.'
  fix_register_repair \
    codex-fedora \
    "${FIX_CATEGORY_LABELS[4]}" \
    'Fedora native Codex CLI' \
    'No logout is required; start a new shell if PATH changes.'
  fix_register_repair \
    development-toolchain \
    "${FIX_CATEGORY_LABELS[4]}" \
    'Development toolchain' \
    'No logout is required; start a new shell if shell configuration changes.'
fi
