#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"

readonly DEVELOPMENT_TOOLCHAIN_JDK_VERSION='26.0.1'
readonly DEVELOPMENT_TOOLCHAIN_CMAKE_VERSION='4.4.0'
readonly DEVELOPMENT_TOOLCHAIN_ANACONDA_VERSION='2025.12-2'
readonly DEVELOPMENT_TOOLCHAIN_JDK_URL='https://download.java.net/java/GA/jdk26.0.1/458fda22e4c54d5ba572ab8d2b22eb83/8/GPL/openjdk-26.0.1_linux-x64_bin.tar.gz'
readonly DEVELOPMENT_TOOLCHAIN_CMAKE_URL='https://github.com/Kitware/CMake/releases/download/v4.4.0/cmake-4.4.0-linux-x86_64.sh'
readonly DEVELOPMENT_TOOLCHAIN_ANACONDA_URL='https://repo.anaconda.com/archive/Anaconda3-2025.12-2-Linux-x86_64.sh'
readonly DEVELOPMENT_TOOLCHAIN_JDK_SHA256='2f2802d57b5fc414f1ddf6648ba12cc9a6454cf67b32ac95407c018f2e6ab0b0'
readonly DEVELOPMENT_TOOLCHAIN_CMAKE_SHA256='6e7cdca8b054a3f6a5adcb1fa012e591e4c669bd744a009788681575aac96f50'

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
    jdk) base="jdk-${DEVELOPMENT_TOOLCHAIN_JDK_VERSION}" ;;
    cmake) base="cmake-${DEVELOPMENT_TOOLCHAIN_CMAKE_VERSION}" ;;
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
  printf '%s\n' curl tar gzip > "$manifest"
  if ! install_dnf_manifest "$manifest"; then
    rm -f "$manifest"
    return 1
  fi
  rm -f "$manifest"
}

development_toolchain_verify_sha256() {
  local file=$1 expected=$2 label=$3 actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    printf 'Checksum mismatch for %s\n' "$label" >&2
    return 1
  }
}

development_toolchain_download() {
  local label=$1 target=$2 url=$3 checksum=${4:-}
  network_run download "$label" curl --fail --location --progress-bar -o "$target" "$url"
  [[ -z "$checksum" ]] || development_toolchain_verify_sha256 "$target" "$checksum" "$label"
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

development_toolchain_install_jdk() {
  local scope=$1 prefix workdir
  prefix="$(development_toolchain_target_prefix "$scope" jdk)"
  if [[ ! -x "$prefix/bin/java" ]]; then
    workdir="$(mktemp -d)"
    development_toolchain_download 'Downloading OpenJDK 26.0.1' "$workdir/openjdk.tar.gz" "$DEVELOPMENT_TOOLCHAIN_JDK_URL" "$DEVELOPMENT_TOOLCHAIN_JDK_SHA256"
    if [[ "$scope" == system ]]; then
      sudo mkdir -p /opt
      sudo tar -xzf "$workdir/openjdk.tar.gz" -C /opt
    else
      mkdir -p "$(dirname "$prefix")"
      tar -xzf "$workdir/openjdk.tar.gz" -C "$(dirname "$prefix")"
    fi
    rm -rf "$workdir"
  fi
  [[ -x "$prefix/bin/java" ]] || die "OpenJDK installation was not found at $prefix"
  if [[ "$scope" == system ]]; then
    sudo alternatives --install /usr/bin/java java "$prefix/bin/java" 2601 \
      --slave /usr/bin/javac javac "$prefix/bin/javac" \
      --slave /usr/bin/jar jar "$prefix/bin/jar" \
      --slave /usr/bin/javadoc javadoc "$prefix/bin/javadoc" \
      --slave /usr/bin/jshell jshell "$prefix/bin/jshell"
    sudo alternatives --set java "$prefix/bin/java"
    printf '%s\n' "export JAVA_HOME=$prefix" 'export PATH="$JAVA_HOME/bin:$PATH"' | sudo tee /etc/profile.d/myunix-jdk26.sh >/dev/null
    sudo chmod 0644 /etc/profile.d/myunix-jdk26.sh
  else
    development_toolchain_link_command user "$prefix/bin/java" java
    development_toolchain_link_command user "$prefix/bin/javac" javac
  fi
}

development_toolchain_install_cmake() {
  local scope=$1 prefix workdir tool
  prefix="$(development_toolchain_target_prefix "$scope" cmake)"
  if [[ ! -x "$prefix/bin/cmake" ]]; then
    workdir="$(mktemp -d)"
    development_toolchain_download 'Downloading CMake 4.4.0' "$workdir/cmake-installer.sh" "$DEVELOPMENT_TOOLCHAIN_CMAKE_URL" "$DEVELOPMENT_TOOLCHAIN_CMAKE_SHA256"
    chmod +x "$workdir/cmake-installer.sh"
    if [[ "$scope" == system ]]; then
      sudo mkdir -p "$prefix"
      sudo "$workdir/cmake-installer.sh" --skip-license --prefix="$prefix"
    else
      mkdir -p "$prefix"
      "$workdir/cmake-installer.sh" --skip-license --prefix="$prefix"
    fi
    rm -rf "$workdir"
  fi
  [[ -x "$prefix/bin/cmake" ]] || die "CMake installation was not found at $prefix"
  for tool in cmake ctest cpack ccmake; do
    development_toolchain_link_command "$scope" "$prefix/bin/$tool" "$tool"
  done
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
  if development_toolchain_has_component "$components" jdk || development_toolchain_has_component "$components" cmake || development_toolchain_has_component "$components" anaconda; then
    has_portable=1
    development_toolchain_install_portable_prerequisites
  fi
  development_toolchain_has_component "$components" jdk && development_toolchain_install_jdk "$scope"
  development_toolchain_has_component "$components" cmake && development_toolchain_install_cmake "$scope"
  development_toolchain_has_component "$components" anaconda && development_toolchain_install_anaconda "$scope"
  ((has_portable == 0)) || [[ "$scope" != user ]] || development_toolchain_install_user_shell_config
  info "Development toolchain installed with ${scope} scope. Run $(development_toolchain_dir)/verify.sh to inspect versions."
}
