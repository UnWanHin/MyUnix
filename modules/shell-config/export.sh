#!/usr/bin/env bash
set -Eeuo pipefail

export_shell_config() {
  local source_dir target_dir fragment exported=0
  source_dir="$(shell_config_target_dir)"
  target_dir="$(shell_config_source_dir)"

  if [[ -f "$source_dir/.sysrc" ]]; then
    mkdir -p "$target_dir"
    cp -a "$source_dir/.sysrc" "$target_dir/.sysrc"
    exported=1
  fi

  for fragment in env.rc aliases.rc functions.rc; do
    [[ -f "$source_dir/sysrc.d/$fragment" ]] || continue
    mkdir -p "$target_dir/sysrc.d"
    cp -a "$source_dir/sysrc.d/$fragment" "$target_dir/sysrc.d/$fragment"
    exported=1
  done

  if ((exported)); then
    info 'Shared shell configuration exported for review'
  else
    info 'No shared shell configuration found to export'
  fi
}
