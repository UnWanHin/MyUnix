#!/usr/bin/env bash
set -Eeuo pipefail

: "${MYUNIX_CODEX_STATUS_FILE:?MYUNIX_CODEX_STATUS_FILE is required}"
: "${MYUNIX_CODEX_HOME:?MYUNIX_CODEX_HOME is required}"

readonly MYUNIX_CODEX_NODE_MAJOR="${MYUNIX_CODEX_NODE_MAJOR:-22}"
readonly MYUNIX_CODEX_ROOT='/opt/myunix'
readonly MYUNIX_CODEX_NODE_LINK="${MYUNIX_CODEX_ROOT}/codex-node"
readonly MYUNIX_CODEX_CLI_PREFIX="${MYUNIX_CODEX_ROOT}/codex-cli"
readonly MYUNIX_CODEX_WRAPPER='/usr/local/bin/codex'

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

write_status() {
  mkdir -p "$(dirname "$MYUNIX_CODEX_STATUS_FILE")"
  printf '%s\n' "$1" > "$MYUNIX_CODEX_STATUS_FILE"
}

record_completion_status() {
  local status=$?
  if ((status == 0)); then
    write_status succeeded
  else
    write_status failed
  fi
  exit "$status"
}

retry_network() {
  local label=$1 attempt=1 attempts=${MYUNIX_CODEX_NETWORK_ATTEMPTS:-3}
  shift
  [[ "$attempts" =~ ^[1-9][0-9]*$ ]] || die "Invalid MYUNIX_CODEX_NETWORK_ATTEMPTS: $attempts"
  while ((attempt <= attempts)); do
    printf '[distrobox-codex] %s (attempt %s/%s)\n' "$label" "$attempt" "$attempts"
    if "$@"; then
      return 0
    fi
    ((attempt == attempts)) && break
    sleep "$attempt"
    attempt=$((attempt + 1))
  done
  die "$label failed after $attempts attempts"
}

resolve_node_version() {
  local index_file=$1
  awk -F'"' -v prefix="v${MYUNIX_CODEX_NODE_MAJOR}." \
    '$2 == "version" && index($4, prefix) == 1 { print $4; exit }' "$index_file"
}

install_node_runtime() {
  local temporary index_file checksums archive checksum_entry version archive_name extracted_directory
  [[ "$(uname -m)" == x86_64 ]] || die "Unsupported architecture: $(uname -m); only x86_64 is currently supported"
  temporary="$(mktemp -d)"
  index_file="$temporary/index.json"
  retry_network 'Fetching Node.js release index' \
    curl --fail --location --silent --show-error --output "$index_file" https://nodejs.org/dist/index.json
  version="$(resolve_node_version "$index_file")"
  [[ -n "$version" ]] || die "No Node.js ${MYUNIX_CODEX_NODE_MAJOR}.x release found"
  archive_name="node-${version}-linux-x64.tar.xz"
  checksums="$temporary/SHASUMS256.txt"
  archive="$temporary/$archive_name"
  retry_network 'Fetching Node.js checksums' \
    curl --fail --location --silent --show-error --output "$checksums" \
      "https://nodejs.org/dist/${version}/SHASUMS256.txt"
  grep -F "  ${archive_name}" "$checksums" > "$temporary/checksum.txt" \
    || die "Node.js checksum is missing for ${archive_name}"
  retry_network 'Downloading Node.js runtime' \
    curl --fail --location --output "$archive" "https://nodejs.org/dist/${version}/${archive_name}"
  (
    cd "$temporary"
    sha256sum --check checksum.txt
  )
  extracted_directory="${MYUNIX_CODEX_ROOT}/node-${version}-linux-x64"
  sudo install -d -m 0755 "$MYUNIX_CODEX_ROOT"
  if [[ ! -d "$extracted_directory" ]]; then
    sudo tar --extract --xz --file "$archive" --directory "$MYUNIX_CODEX_ROOT"
  fi
  sudo ln -sfn "$extracted_directory" "$MYUNIX_CODEX_NODE_LINK"
  rm -rf "$temporary"
}

install_codex_cli() {
  sudo env PATH="$MYUNIX_CODEX_NODE_LINK/bin:$PATH" "$MYUNIX_CODEX_NODE_LINK/bin/npm" \
    install --global --prefix "$MYUNIX_CODEX_CLI_PREFIX" \
    --no-audit --no-fund @openai/codex
}

prepare_codex_home() {
  local owner group source_config destination_config
  owner="$(id --user --name)"
  group="$(id --group --name)"
  source_config="$HOME/.codex/config.toml"
  destination_config="$MYUNIX_CODEX_HOME/config.toml"
  sudo install --directory --mode 0700 --owner "$owner" --group "$group" "$MYUNIX_CODEX_HOME"
  if [[ ! -f "$destination_config" && -f "$source_config" ]]; then
    sudo install --mode 0600 --owner "$owner" --group "$group" "$source_config" "$destination_config"
    printf '%s\n' 'Copied Codex configuration without copying authentication.'
  fi
}

install_codex_wrapper() {
  local wrapper
  wrapper="$(mktemp)"
  {
    printf '%s\n' '#!/usr/bin/env sh' 'set -eu'
    printf 'export CODEX_HOME=%q\n' "$MYUNIX_CODEX_HOME"
    printf '%s\n' \
      'runtime=/opt/myunix/codex-node' \
      'cli=/opt/myunix/codex-cli/bin/codex' \
      'test -x "$runtime/bin/node"' \
      'test -x "$cli"' \
      'exec "$runtime/bin/node" "$cli" "$@"'
  } > "$wrapper"
  sudo install -m 0755 "$wrapper" "$MYUNIX_CODEX_WRAPPER"
  rm -f "$wrapper"
}

verify_codex_auth_boundary() {
  if [[ -f "$MYUNIX_CODEX_HOME/auth.json" ]]; then
    printf '%s\n' 'Dedicated container Codex authentication detected.'
  else
    printf '%s\n' 'No dedicated container authentication found. Run codex login inside the container.'
  fi
}

write_status running
trap record_completion_status EXIT

sudo -v
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl xz-utils
install_node_runtime
install_codex_cli
prepare_codex_home
install_codex_wrapper
"$MYUNIX_CODEX_WRAPPER" --version
verify_codex_auth_boundary
printf '%s\n' 'Container-native Codex is ready.'
