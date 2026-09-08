#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/network.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/rpmfusion.sh"

dnf_module_dir() {
  printf '%s\n' "${MYUNIX_DNF_MODULE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
}

dnf_sources_manifest() {
  printf '%s\n' "${MYUNIX_DNF_SOURCES_MANIFEST:-$(dnf_module_dir)/sources.tsv}"
}

dnf_portable_manifest() {
  printf '%s\n' "${MYUNIX_DNF_PORTABLE_MANIFEST:-$(dnf_module_dir)/portable.txt}"
}

dnf_source_repo_dir() {
  printf '%s\n' "${MYUNIX_DNF_REPO_DIR:-/etc/yum.repos.d}"
}

dnf_source_keyring_dir() {
  printf '%s\n' "${MYUNIX_DNF_KEYRING_DIR:-/etc/pki/rpm-gpg}"
}

dnf_query_timeout_seconds() {
  local seconds=${MYUNIX_DNF_QUERY_TIMEOUT_SECONDS:-60}
  [[ "$seconds" =~ ^[1-9][0-9]*$ ]] || die 'MYUNIX_DNF_QUERY_TIMEOUT_SECONDS must be a positive integer'
  printf '%s\n' "$seconds"
}

dnf_source_has_repo_id() {
  local id=$1 repo_dir
  repo_dir="$(dnf_source_repo_dir)"
  [[ -d "$repo_dir" ]] || return 1
  grep -Rqs --include='*.repo' -Fx "[$id]" "$repo_dir"
}

dnf_source_template_repo_id() {
  local template=$1 repo_id
  repo_id="$(awk '/^\[[[:alnum:]_.-]+\]$/ { value = $0; sub(/^\[/, "", value); sub(/\]$/, "", value); print value; exit }' "$template")"
  [[ "$repo_id" =~ ^[[:alnum:]_.-]+$ ]] || die "Invalid DNF repository template: $template"
  printf '%s\n' "$repo_id"
}

install_dnf_source_repo() {
  local id=$1 template_relative=$2 module_dir template key_source key_target repo_target repo_id
  module_dir="$(dnf_module_dir)"
  template="$module_dir/$template_relative"
  key_source="$module_dir/keys/$id.asc"
  key_target="$(dnf_source_keyring_dir)/RPM-GPG-KEY-$id"
  repo_target="$(dnf_source_repo_dir)/myunix-$id.repo"
  [[ -f "$template" ]] || die "Missing DNF repository template: $template"
  repo_id="$(dnf_source_template_repo_id "$template")"

  if [[ -f "$key_source" ]]; then
    network_run dnf "Installing DNF signing key: $id" sudo install -Dm0644 "$key_source" "$key_target" || return $?
    network_run dnf "Importing DNF signing key: $id" sudo rpm --import "$key_target" || return $?
  fi

  if dnf_source_has_repo_id "$repo_id"; then
    info "DNF repository already configured: $repo_id"
    network_run dnf "Enabling DNF repository: $repo_id" sudo dnf config-manager setopt "${repo_id}.enabled=1" || return $?
    return 0
  fi
  network_run dnf "Installing DNF repository: $id" sudo install -Dm0644 "$template" "$repo_target" || return $?
}

install_dnf_source_copr() {
  local id=$1 project=$2
  network_run dnf "Enabling DNF COPR repository: $id" sudo dnf copr enable -y "$project"
}

install_dnf_sources_for_scope() {
  local requested_scope=$1 manifest id kind value scope extra matched=0
  manifest="$(dnf_sources_manifest)"
  validate_dnf_sources_manifest "$manifest" || die "Invalid DNF source manifest: $manifest"

  while IFS='|' read -r id kind value scope extra; do
    is_comment_or_blank "$id" && continue
    [[ "$scope" == "$requested_scope" ]] || continue
    matched=1
    case "$kind" in
      rpmfusion) install_rpmfusion_repositories || return $? ;;
      repo) install_dnf_source_repo "$id" "$value" || return $? ;;
      copr) install_dnf_source_copr "$id" "$value" || return $? ;;
    esac
  done < "$manifest"

  ((matched != 0)) || die "No DNF sources registered for scope: $requested_scope"
}

manifest_packages() {
  local manifest=$1 line
  validate_dnf_manifest "$manifest" || die "Invalid DNF manifest: $manifest"

  while IFS= read -r line || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    printf '%s\n' "$line"
  done < "$manifest"
}

verify_dnf_manifest_available() {
  local manifest=$1 package available missing=0

  while IFS= read -r package; do
    if ! available="$(timeout --foreground "$(dnf_query_timeout_seconds)" dnf repoquery --available --quiet --qf '%{name}' "$package" 2>/dev/null)" || ! grep -Fxq "$package" <<< "$available"; then
      printf 'Missing DNF package from enabled repositories: %s\n' "$package" >&2
      missing=1
    fi
  done < <(manifest_packages "$manifest")

  return "$missing"
}

install_dnf_manifest() {
  local manifest=$1 package
  local -a packages=()

  while IFS= read -r package; do
    packages+=("$package")
  done < <(manifest_packages "$manifest")

  ((${#packages[@]})) || return 0
  network_run dnf 'Installing DNF package manifest' sudo dnf install -y "${packages[@]}"
}

install_dnf_portable_profile() {
  local manifest
  manifest="$(dnf_portable_manifest)"
  install_dnf_sources_for_scope profile || return $?
  verify_dnf_manifest_available "$manifest" || return $?
  install_dnf_manifest "$manifest"
}

install_optional_dnf_manifest() {
  local manifest=$1 line reply
  validate_dnf_manifest "$manifest" || die "Invalid DNF manifest: $manifest"

  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    is_comment_or_blank "$line" && continue
    read -r -p "Install ${line}? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      network_run dnf "Installing optional DNF package: $line" sudo dnf install -y "$line"
    else
      info "Skip $line"
    fi
  done 3< "$manifest"
}
