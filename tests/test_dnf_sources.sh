#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

mkdir -p "$temporary/module/repos" "$temporary/module/keys"
printf '%s\n' \
  'rpmfusion|rpmfusion|-|profile' \
  'chatgpt|repo|repos/chatgpt.repo|profile' \
  'niri|copr|yalter/niri|niri-dms' > "$temporary/module/sources.tsv"
printf '%s\n' \
  '[openai-chatgpt]' \
  'name=ChatGPT' \
  'baseurl=https://persistent.oaistatic.com/codex-app-prod/linux/rpm/$basearch' \
  'enabled=1' \
  'gpgcheck=1' \
  'repo_gpgcheck=1' \
  'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-chatgpt' > "$temporary/module/repos/chatgpt.repo"
printf '%s\n' 'public key fixture' > "$temporary/module/keys/chatgpt.asc"

run env \
  MYUNIX_DNF_MODULE_DIR="$temporary/module" \
  MYUNIX_DNF_REPO_DIR="$temporary/repos" \
  MYUNIX_DNF_KEYRING_DIR="$temporary/keys" \
  bash -c '
    rpm() {
      case "$1" in
        -q) return 1 ;;
        -E) printf "44\\n" ;;
        --import) printf "rpm:%s\\n" "$*" ;;
        *) return 1 ;;
      esac
    }
    dnf() { printf "dnf:%s\\n" "$*"; }
    sudo() { "$@"; }
    timeout() { shift 2; "$@"; }
    source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
    source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
    source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
    install_dnf_sources_for_scope profile
    test -f "$MYUNIX_DNF_REPO_DIR/myunix-chatgpt.repo"
    test -f "$MYUNIX_DNF_KEYRING_DIR/RPM-GPG-KEY-chatgpt"
  '
assert_status 0
assert_output_contains 'dnf:install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm'
assert_output_contains 'rpm:--import'
[[ "$OUTPUT" != *'copr enable'* ]] || {
  printf '%s\n' 'Profile source setup must not enable Niri COPRs' >&2
  exit 1
}

mkdir -p "$temporary/existing-repos"
printf '%s\n' '[openai-chatgpt]' 'enabled=0' > "$temporary/existing-repos/chatgpt.repo"
run env \
  MYUNIX_DNF_MODULE_DIR="$temporary/module" \
  MYUNIX_DNF_REPO_DIR="$temporary/existing-repos" \
  MYUNIX_DNF_KEYRING_DIR="$temporary/existing-keys" \
  bash -c '
    rpm() {
      case "$1" in
        -q) return 1 ;;
        -E) printf "44\\n" ;;
        --import) return 0 ;;
        *) return 1 ;;
      esac
    }
    dnf() { printf "dnf:%s\\n" "$*"; }
    sudo() { "$@"; }
    timeout() { shift 2; "$@"; }
    source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
    source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
    source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
    install_dnf_sources_for_scope profile
    test ! -e "$MYUNIX_DNF_REPO_DIR/myunix-chatgpt.repo"
  '
assert_status 0
assert_output_contains 'DNF repository already configured: openai-chatgpt'
assert_output_contains 'dnf:config-manager setopt openai-chatgpt.enabled=1'

run env \
  MYUNIX_DNF_MODULE_DIR="$temporary/module" \
  MYUNIX_DNF_REPO_DIR="$temporary/repos" \
  MYUNIX_DNF_KEYRING_DIR="$temporary/keys" \
  bash -c '
    dnf() { printf "dnf:%s\\n" "$*"; }
    sudo() { "$@"; }
    timeout() { shift 2; "$@"; }
    source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
    source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
    source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
    install_dnf_sources_for_scope niri-dms
  '
assert_status 0
assert_output_contains 'dnf:copr enable -y yalter/niri'

run env \
  MYUNIX_DNF_MODULE_DIR="$temporary/module" \
  MYUNIX_DNF_SOURCES_MANIFEST="$temporary/failing-sources.tsv" \
  MYUNIX_DNF_REPO_DIR="$temporary/repos" \
  MYUNIX_DNF_KEYRING_DIR="$temporary/keys" \
  bash -c '
    printf "%s\\n" \
      "first|copr|owner/fail|profile" \
      "second|copr|owner/pass|profile" > "$MYUNIX_DNF_SOURCES_MANIFEST"
    dnf() {
      printf "dnf:%s\\n" "$*"
      [[ "$*" != *owner/fail* ]]
    }
    sudo() { "$@"; }
    timeout() { shift 2; "$@"; }
    source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
    source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
    source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
    install_dnf_sources_for_scope profile
  '
assert_status 1
assert_output_contains 'dnf:copr enable -y owner/fail'
[[ "$OUTPUT" != *'owner/pass'* ]] || {
  printf '%s\n' 'DNF source setup must stop after a required source fails' >&2
  exit 1
}

run env MYUNIX_DNF_PORTABLE_MANIFEST="$temporary/portable.txt" bash -c '
  printf "%s\\n" git > "$MYUNIX_DNF_PORTABLE_MANIFEST"
  source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
  source "'"$PROJECT_ROOT"'/scripts/lib/manifest.sh"
  source "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
  install_dnf_sources_for_scope() { return 0; }
  verify_dnf_manifest_available() { return 1; }
  install_dnf_manifest() { printf "install-ran\\n"; }
  install_dnf_portable_profile
'
assert_status 1
[[ "$OUTPUT" != *'install-ran'* ]] || {
  printf '%s\n' 'Portable profile must not install after availability verification fails' >&2
  exit 1
}

run bash -c '
  test -f "'"$PROJECT_ROOT"'/modules/dnf/portable.txt"
  ! rg -q "^(kernel|linux-firmware|microcode_ctl|grub|shim|dracut|systemd)" "'"$PROJECT_ROOT"'/modules/dnf/portable.txt"
  ! rg -qx "niri" "'"$PROJECT_ROOT"'/modules/dnf/portable.txt"
  ! rg -qx "steam" "'"$PROJECT_ROOT"'/modules/dnf/portable.txt"
  ! rg -qx "distrobox" "'"$PROJECT_ROOT"'/modules/dnf/portable.txt"
  ! rg -Fq "mirrors.rpmfusion.org" "'"$PROJECT_ROOT"'/modules/dnf/install.sh"
'
assert_status 0

run bash -c '
  rg -Fx "danklinux|copr|avengemedia/danklinux|niri-dms" "'"$PROJECT_ROOT"'/modules/dnf/sources.tsv"
  rg -Fx "dms-git|copr|avengemedia/dms-git|niri-dms" "'"$PROJECT_ROOT"'/modules/dnf/sources.tsv"
  rg -Fx "yalter-niri|copr|yalter/niri|niri-dms" "'"$PROJECT_ROOT"'/modules/dnf/sources.tsv"
'
assert_status 0
