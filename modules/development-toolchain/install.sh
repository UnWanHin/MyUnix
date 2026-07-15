#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

readonly DEVELOPMENT_TOOLCHAIN_ANACONDA_VERSION='2025.12-2'
readonly DEVELOPMENT_TOOLCHAIN_ANACONDA_URL='https://repo.anaconda.com/archive/Anaconda3-2025.12-2-Linux-x86_64.sh'

development_toolchain_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

development_toolchain_packages_path() {
  printf '%s\n' "${MYUNIX_TOOLCHAIN_PACKAGES:-$(development_toolchain_dir)/packages.tsv}"
}

development_toolchain_component_names() {
  awk -F'|' '!/^#/ && NF == 3 && !seen[$1]++ { print $1 }' "$(development_toolchain_packages_path)"
}

development_toolchain_validate_scope() {
  case "$1" in
    system|user) ;;
    *) die "Invalid development-toolchain scope: $1" ;;
  esac
}

development_toolchain_default_components() {
  development_toolchain_component_names | paste -sd, -
}

development_toolchain_normalize_components() {
  local components=${1:-} component
  local -a requested=()
  local -A available=() seen=()
  while IFS= read -r component; do
    available[$component]=1
  done < <(development_toolchain_component_names)
  [[ -n "$components" ]] || components="$(development_toolchain_default_components)"
  IFS=',' read -r -a requested <<< "$components"
  for component in "${requested[@]}"; do
    [[ -n "${available[$component]:-}" ]] || die "Unknown development-toolchain component: $component"
    [[ -n "${seen[$component]:-}" ]] && continue
    seen[$component]=1
    printf '%s\n' "$component"
  done
}

development_toolchain_resolve_dnf_packages() {
  local components=$1 component kind value
  local -A selected=() seen=()
  while IFS= read -r component; do
    selected[$component]=1
  done < <(development_toolchain_normalize_components "$components")
  while IFS='|' read -r component kind value; do
    [[ -z "$component" || "$component" == \#* ]] && continue
    [[ -n "${selected[$component]:-}" && "$kind" == package ]] || continue
    [[ -n "${seen[$value]:-}" ]] && continue
    seen[$value]=1
    printf '%s\n' "$value"
  done < "$(development_toolchain_packages_path)"
}

development_toolchain_target_prefix() {
  local scope=$1 component=$2 base
  development_toolchain_validate_scope "$scope"
  case "$component" in
    anaconda) base='anaconda3' ;;
    *) die "Component has no portable installation prefix: $component" ;;
  esac
  if [[ "$scope" == system ]]; then
    printf '/opt/%s\n' "$base"
  else
    printf '%s/.local/opt/%s\n' "$HOME" "$base"
  fi
}

development_toolchain_backup_dir() {
  if [[ -z "${MYUNIX_TOOLCHAIN_ACTIVE_BACKUP_DIR:-}" ]]; then
    MYUNIX_TOOLCHAIN_ACTIVE_BACKUP_DIR="${MYUNIX_TOOLCHAIN_BACKUP_DIR:-$HOME/.local/state/myunix/backups/development-toolchain/$(date +%Y%m%d-%H%M%S)}"
  fi
  printf '%s\n' "$MYUNIX_TOOLCHAIN_ACTIVE_BACKUP_DIR"
}

development_toolchain_install_user_shell_config() {
  local source_file target_file backup_file
  source_file="$(development_toolchain_dir)/config/sysrc.d/development-toolchain.rc"
  target_file="${XDG_CONFIG_HOME:-$HOME/.config}/sysrc.d/development-toolchain.rc"
  [[ -f "$source_file" ]] || die "Missing development-toolchain shell configuration: $source_file"
  if [[ -f "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    return 0
  fi
  if [[ -e "$target_file" ]]; then
    backup_file="$(development_toolchain_backup_dir)/sysrc.d/development-toolchain.rc"
    mkdir -p "$(dirname "$backup_file")"
    cp -a "$target_file" "$backup_file"
  fi
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
}

development_toolchain_has_component() {
  local components=$1 wanted=$2 component
  while IFS= read -r component; do
    [[ "$component" == "$wanted" ]] && return 0
  done < <(development_toolchain_normalize_components "$components")
  return 1
}

development_toolchain_install_dnf_components() {
  local components=$1 manifest
  if development_toolchain_has_component "$components" build-tools; then
    network_run dnf 'Installing Fedora Development Tools group' sudo dnf group install -y 'Development Tools'
  fi
  manifest="$(mktemp)"
  development_toolchain_resolve_dnf_packages "$components" > "$manifest"
  if [[ -s "$manifest" ]]; then
    if ! install_dnf_manifest "$manifest"; then
      rm -f "$manifest"
      return 1
    fi
  fi
  rm -f "$manifest"
}

development_toolchain_install_portable_prerequisites() {
  local manifest
  manifest="$(mktemp)"
  printf '%s\n' curl > "$manifest"
  if ! install_dnf_manifest "$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  rm -f "$manifest"
}

development_toolchain_download() {
  local label=$1 target=$2 url=$3
  network_run download "$label" curl --fail --location --progress-bar -o "$target" "$url"
}

development_toolchain_link_command() {
  local scope=$1 target=$2 command_name=$3
  if [[ "$scope" == system ]]; then
    sudo ln -sfn "$target" "/usr/local/bin/$command_name"
  else
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$target" "$HOME/.local/bin/$command_name"
  fi
}

development_toolchain_install_anaconda() {
  local scope=$1 prefix workdir
  prefix="$(development_toolchain_target_prefix "$scope" anaconda)"
  if [[ ! -x "$prefix/condabin/conda" ]]; then
    workdir="$(mktemp -d)"
    development_toolchain_download 'Downloading Anaconda 2025.12-2' "$workdir/anaconda-installer.sh" "$DEVELOPMENT_TOOLCHAIN_ANACONDA_URL"
    if [[ "$scope" == system ]]; then
      sudo bash "$workdir/anaconda-installer.sh" -b -p "$prefix"
    else
      bash "$workdir/anaconda-installer.sh" -b -p "$prefix"
    fi
    rm -rf "$workdir"
  fi
  [[ -x "$prefix/condabin/conda" ]] || die "Anaconda installation was not found at $prefix"
  development_toolchain_link_command "$scope" "$prefix/condabin/conda" conda
  if [[ "$scope" == system ]]; then
    printf '%s\n' ". $prefix/etc/profile.d/conda.sh" | sudo tee /etc/profile.d/myunix-anaconda.sh >/dev/null
    sudo chmod 0644 /etc/profile.d/myunix-anaconda.sh
  fi
}

install_development_toolchain() {
  local scope=${1:-${MYUNIX_TOOLCHAIN_SCOPE:-system}} components=${2:-${MYUNIX_TOOLCHAIN_COMPONENTS:-}} has_portable=0
  is_fedora || die 'Fedora is required'
  development_toolchain_validate_scope "$scope"
  components="$(development_toolchain_normalize_components "$components" | paste -sd, -)"
  development_toolchain_install_dnf_components "$components"
  if development_toolchain_has_component "$components" anaconda; then
    has_portable=1
    development_toolchain_install_portable_prerequisites
  fi
  development_toolchain_has_component "$components" anaconda && development_toolchain_install_anaconda "$scope"
  ((has_portable == 0)) || [[ "$scope" != user ]] || development_toolchain_install_user_shell_config
  info "Development toolchain installed with ${scope} scope. Run $(development_toolchain_dir)/verify.sh to inspect versions."
}
