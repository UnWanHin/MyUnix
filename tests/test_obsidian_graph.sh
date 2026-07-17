#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

for note in README workstation modules session recovery installation-map; do
  [[ -f "$PROJECT_ROOT/docs/obsidian/$note.md" ]] || {
    printf 'Missing Obsidian graph note: %s\n' "$note" >&2
    exit 1
  }
done

rg -Fq '[[workstation]]' "$PROJECT_ROOT/docs/obsidian/README.md"
rg -Fq '[[modules]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
rg -Fq '[[session]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
rg -Fq '[[recovery]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
rg -Fq '[[installation-map]]' "$PROJECT_ROOT/docs/obsidian/README.md"
rg -Fq '```mermaid' "$PROJECT_ROOT/docs/obsidian/installation-map.md"
rg -Fq '[[../modules/steam|Steam]]' "$PROJECT_ROOT/docs/obsidian/installation-map.md"
rg -Fq '[[../modules/time-sync|System time sync]]' "$PROJECT_ROOT/docs/obsidian/installation-map.md"
rg -Fq '[[../modules/distrobox|Distrobox]]' "$PROJECT_ROOT/docs/obsidian/installation-map.md"
rg -Fq '[[../modules/development-toolchain|Development Toolchain]]' "$PROJECT_ROOT/docs/obsidian/installation-map.md"
[[ -f "$PROJECT_ROOT/docs/obsidian/assets/myunix-installation-map.svg" ]] || {
  printf '%s\n' 'Missing Obsidian installation-map SVG' >&2
  exit 1
}
