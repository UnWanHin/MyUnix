#!/usr/bin/env bash
set -Eeuo pipefail

# User-level proxy integration for a local HTTP proxy client (FlClash/mihomo
# on 127.0.0.1:7890 by default). This module never runs sudo: every artifact
# lives below $HOME and is applied as the target desktop user.

proxy_module_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

proxy_bin_dir() {
  printf '%s\n' "${MYUNIX_PROXY_BIN_DIR:-$HOME/.local/bin}"
}

proxy_config_home() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

proxy_data_home() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

proxy_system_applications_dir() {
  printf '%s\n' "${MYUNIX_SYSTEM_APPLICATIONS_DIR:-/usr/share/applications}"
}

proxy_backup_dir() {
  if [[ -z "${MYUNIX_PROXY_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_PROXY_ACTIVE_BACKUP_DIR="${MYUNIX_PROXY_BACKUP_DIR:-$HOME/.local/state/myunix/backups/proxy/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_PROXY_ACTIVE_BACKUP_DIR"
}

proxy_backup_existing() {
  local target_file=$1 backup_file
  [[ -e "$target_file" || -L "$target_file" ]] || return 0
  backup_file="$(proxy_backup_dir)/$(basename "$target_file")"
  [[ -e "$backup_file" ]] && return 0
  mkdir -p "$(dirname "$backup_file")" || return $?
  cp -a "$target_file" "$backup_file"
}

# Replace a target with content read from stdin. The comparison happens before
# the backup so an unchanged file never produces a backup or a rewrite.
proxy_install_stream() {
  local target_file=$1 mode=$2 temporary status
  mkdir -p "$(dirname "$target_file")" || return $?
  temporary="$(mktemp "${target_file}.myunix.XXXXXX")" || return $?
  cat > "$temporary" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  chmod "$mode" "$temporary" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  if [[ -f "$target_file" ]] && cmp -s "$temporary" "$target_file"; then
    rm -f "$temporary"
    return 0
  fi
  proxy_backup_existing "$target_file" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  mv -T "$temporary" "$target_file" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
}

proxy_install_source_file() {
  local source_file=$1 target_file=$2 mode=$3 status temporary
  [[ -f "$source_file" ]] || die "Missing proxy source file: $source_file"
  if [[ -f "$target_file" ]] && cmp -s "$source_file" "$target_file" \
      && [[ "$(stat -Lc '%a' "$target_file")" == "$mode" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$target_file")" || return $?
  temporary="$(mktemp "${target_file}.myunix.XXXXXX")" || return $?
  install -m "$mode" "$source_file" "$temporary" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  proxy_backup_existing "$target_file" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
  mv -T "$temporary" "$target_file" || {
    status=$?
    rm -f "$temporary"
    return "$status"
  }
}

install_proxy_user_files() {
  local module_dir bin_dir config_dir
  module_dir="$(proxy_module_dir)"
  bin_dir="$(proxy_bin_dir)"
  config_dir="$(proxy_config_home)"

  proxy_install_source_file \
    "$module_dir/config/bin/proxy-watchdog.sh" \
    "$bin_dir/proxy-watchdog.sh" 755 || return $?
  proxy_install_source_file \
    "$module_dir/config/bin/chatgpt-proxied" \
    "$bin_dir/chatgpt-proxied" 755 || return $?
  proxy_install_source_file \
    "$module_dir/config/sysrc.d/proxy.rc" \
    "$config_dir/sysrc.d/proxy.rc" 644 || return $?
  proxy_install_source_file \
    "$module_dir/config/systemd/user/proxy-watchdog.service" \
    "$config_dir/systemd/user/proxy-watchdog.service" 644
}

# XDG autostart entries cannot rely on ~/.local/bin being on the session PATH
# (the Niri session PATH starts with /usr/local/bin and /usr/bin), so the
# absolute helper path is resolved here instead of being stored in Git.
install_proxy_autostart() {
  local target
  target="$(proxy_config_home)/autostart/proxy-watchdog.desktop"
  proxy_install_stream "$target" 644 <<EOF
[Desktop Entry]
Type=Application
Name=Proxy Watchdog
Comment=Keep the GNOME system proxy in sync with the local proxy client
Exec=$(proxy_bin_dir)/proxy-watchdog.sh
Terminal=false
X-GNOME-Autostart-enabled=true
X-MyUnix-Managed=true
EOF
}

# The ChatGPT desktop app ignores the GNOME system proxy, so its launcher is
# redirected through chatgpt-proxied. The system entry stays untouched; only a
# managed user override is generated from it, mirroring the Steam module.
install_proxy_chatgpt_launcher() {
  local source target
  source="$(proxy_system_applications_dir)/chatgpt.desktop"
  target="$(proxy_data_home)/applications/chatgpt.desktop"
  if [[ ! -f "$source" ]]; then
    info 'ChatGPT desktop entry not found; skipping the proxied launcher override.'
    return 0
  fi
  proxy_install_stream "$target" 644 < <(
    awk -v exec_line="Exec=$(proxy_bin_dir)/chatgpt-proxied %U" '
      /^\[Desktop Entry\]$/ {
        print
        print "X-MyUnix-Managed=true"
        next
      }
      /^Comment=/ {
        print "Comment=ChatGPT by OpenAI (proxied through the local proxy client)"
        next
      }
      /^Exec=/ {
        print exec_line
        next
      }
      { print }
    ' "$source"
  )
}

# Prefer the restart-on-failure user service. The autostart entry stays as the
# fallback for sessions without a user systemd bus; the helper's pidfile makes
# the overlap harmless because the second instance exits immediately.
install_proxy_watchdog_service() {
  local unit_name=proxy-watchdog.service
  if ! command -v systemctl >/dev/null 2>&1; then
    info 'systemctl is unavailable; the autostart entry starts the proxy watchdog instead.'
    return 0
  fi
  if ! systemctl --user daemon-reload >/dev/null 2>&1; then
    info "No user systemd bus. Start the watchdog with: systemctl --user enable --now $unit_name"
    return 0
  fi
  if systemctl --user enable --now "$unit_name" >/dev/null 2>&1; then
    info "Proxy watchdog user service enabled: $unit_name"
  else
    info "Enable the proxy watchdog inside your session with: systemctl --user enable --now $unit_name"
  fi
  return 0
}

install_proxy() {
  is_fedora || die 'Fedora is required'
  require_command curl || return $?
  if ! command -v gsettings >/dev/null 2>&1; then
    info 'gsettings is unavailable; the watchdog will only probe the proxy client.'
  fi
  install_proxy_user_files || return $?
  install_proxy_autostart || return $?
  install_proxy_chatgpt_launcher || return $?
  install_proxy_watchdog_service || return $?
  info 'Proxy Watchdog installed. Start a new shell to load ~/.config/sysrc.d/proxy.rc.'
}
