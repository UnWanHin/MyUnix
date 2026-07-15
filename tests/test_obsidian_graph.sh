#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

for note in README workstation modules session recovery; do
  [[ -f "$PROJECT_ROOT/docs/obsidian/$note.md" ]] || {
    printf 'Missing Obsidian graph note: %s\n' "$note" >&2
    exit 1
  }
done

rg -Fq '[[workstation]]' "$PROJECT_ROOT/docs/obsidian/README.md"
rg -Fq '[[modules]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
rg -Fq '[[session]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
rg -Fq '[[recovery]]' "$PROJECT_ROOT/docs/obsidian/workstation.md"
