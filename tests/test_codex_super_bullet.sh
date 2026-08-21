#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/test_helper.bash"

module_dir="$PROJECT_ROOT/modules/codex-super-bullet"
launcher="$module_dir/bin/super-bullet"
profile="$module_dir/config/super-bullet.config.toml"
agents="$module_dir/config/AGENTS.md"
skill="$module_dir/config/skills/super-bullet/SKILL.md"
installer="$module_dir/install.sh"

for required_file in "$launcher" "$profile" "$agents" "$skill" "$installer"; do
  run test -f "$required_file"
  assert_status 0
done

for public_file in "$agents" "$profile" "$skill"; do
  if git -C "$PROJECT_ROOT" check-ignore -q "$public_file"; then
    printf 'Public SuperBullet template is ignored: %s\n' "$public_file" >&2
    exit 1
  fi
done

run grep -F 'model = "gpt-5.6-luna"' "$profile"
assert_status 0
run grep -F 'model_reasoning_effort = "max"' "$profile"
assert_status 0
run grep -F 'multi_agent = true' "$profile"
assert_status 0

run grep -F '关闭 SuperBullet' "$agents"
assert_status 0
run grep -F 'SuperBullet: active — Luna execution' "$agents"
assert_status 0
run grep -F 'SuperBullet: active — Sol validation' "$agents"
assert_status 0
run grep -F 'must not edit files' "$agents"
assert_status 0

run grep -F 'run_sol_review' "$launcher"
assert_status 0
run grep -F 'gpt-5.6-sol' "$launcher"
assert_status 0
run grep -F 'model_reasoning_effort' "$launcher"
assert_status 0
run grep -F -- '--disable multi_agent' "$launcher"
assert_status 0

run bash -c "if grep -REn 'sk-[A-Za-z0-9]|gh[pousr]_[A-Za-z0-9]|BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|password[[:space:]]*=' '$module_dir'; then exit 1; fi"
assert_status 0

fake_root="$(mktemp -d)"
trap 'rm -rf "$fake_root"' EXIT
fake_bin="$fake_root/bin"
fake_home="$fake_root/codex"
fake_state="$fake_root/state"
fake_log="$fake_root/codex.log"
mkdir -p "$fake_bin"
cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_CODEX_LOG"
for argument in "$@"; do
  if [[ "$argument" == --fail-exec* ]]; then
    exit 7
  fi
done
if [[ "${1:-}" == exec && -n "${FAKE_COMMIT_REPO:-}" ]]; then
  git -C "$FAKE_COMMIT_REPO" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -m 'fake Luna change' >/dev/null
fi
exit 0
EOF
chmod +x "$fake_bin/codex"

run env \
  MYUNIX_TEST_MODE=fedora \
  MYUNIX_CODEX_HOME="$fake_home" \
  MYUNIX_SUPER_BULLET_BIN_DIR="$fake_bin" \
  MYUNIX_SUPER_BULLET_STATE_DIR="$fake_state" \
  bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$installer'; install_codex_super_bullet"
assert_status 0
run test -x "$fake_bin/super-bullet"
assert_status 0
run test -f "$fake_home/AGENTS.md"
assert_status 0
run test -f "$fake_home/super-bullet.config.toml"
assert_status 0
run test -f "$fake_home/skills/super-bullet/SKILL.md"
assert_status 0

run env \
  MYUNIX_TEST_MODE=fedora \
  MYUNIX_CODEX_HOME="$fake_home" \
  MYUNIX_SUPER_BULLET_BIN_DIR="$fake_bin" \
  MYUNIX_SUPER_BULLET_STATE_DIR="$fake_state" \
  bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$installer'; install_codex_super_bullet"
assert_status 0
run grep -Fc '# MyUnix SuperBullet mode' "$fake_home/AGENTS.md"
assert_status 0
assert_equals '1' "$(tr -d ' ' <<< "$OUTPUT")"
first_agents_digest="$(sha256sum "$fake_home/AGENTS.md" | cut -d' ' -f1)"
run env \
  MYUNIX_TEST_MODE=fedora \
  MYUNIX_CODEX_HOME="$fake_home" \
  MYUNIX_SUPER_BULLET_BIN_DIR="$fake_bin" \
  MYUNIX_SUPER_BULLET_STATE_DIR="$fake_state" \
  bash -c "source '$PROJECT_ROOT/scripts/lib/core.sh'; source '$installer'; install_codex_super_bullet"
assert_status 0
second_agents_digest="$(sha256sum "$fake_home/AGENTS.md" | cut -d' ' -f1)"
assert_equals "$first_agents_digest" "$second_agents_digest"

run env \
  FAKE_CODEX_LOG="$fake_log" \
  MYUNIX_CODEX_BIN="$fake_bin/codex" \
  "$fake_bin/super-bullet" exec 'build the project'
assert_status 0
assert_output_contains 'SuperBullet: active — Luna execution'
assert_output_contains 'SuperBullet: active — Sol validation'
run sed -n '1p' "$fake_log"
assert_status 0
assert_output_contains 'exec -p super-bullet build the project'
run sed -n '2p' "$fake_log"
assert_status 0
assert_output_contains 'review'
assert_output_contains 'gpt-5.6-sol'

: > "$fake_log"
run env \
  FAKE_CODEX_LOG="$fake_log" \
  MYUNIX_CODEX_BIN="$fake_bin/codex" \
  "$fake_bin/super-bullet" exec build the project
assert_status 0
run sed -n '1p' "$fake_log"
assert_status 0
assert_output_contains 'exec -p super-bullet build the project'

: > "$fake_log"
run env \
  FAKE_CODEX_LOG="$fake_log" \
  MYUNIX_CODEX_BIN="$fake_bin/codex" \
  "$fake_bin/super-bullet" exec --fail-exec 'expected failure'
assert_status 7
assert_output_contains 'SuperBullet: active — Luna execution'
if [[ "$OUTPUT" == *'SuperBullet: active — Sol validation'* ]]; then
  printf 'Sol review must not run after failed Luna execution.\n' >&2
  exit 1
fi
run wc -l < "$fake_log"
assert_status 0
assert_equals '1' "$(tr -d ' ' <<< "$OUTPUT")"

run env FAKE_CODEX_LOG="$fake_log" MYUNIX_CODEX_BIN="$fake_bin/codex" "$fake_bin/super-bullet" review
assert_status 0
assert_output_contains 'SuperBullet: active — Sol validation'
run tail -n 1 "$fake_log"
assert_status 0
assert_output_contains 'review'
assert_output_contains -- '--uncommitted'

review_repo="$(mktemp -d)"
git -C "$review_repo" init -q
git -C "$review_repo" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -m 'review baseline' >/dev/null
run bash -c "cd '$review_repo' && FAKE_CODEX_LOG='$fake_log' MYUNIX_CODEX_BIN='$fake_bin/codex' '$fake_bin/super-bullet' review"
assert_status 0
assert_output_contains 'SuperBullet: active — Sol validation'

commit_repo="$(mktemp -d)"
git -C "$commit_repo" init -q
git -C "$commit_repo" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -m 'before Luna' >/dev/null
before_commit="$(git -C "$commit_repo" rev-parse HEAD)"
: > "$fake_log"
run bash -c "cd '$commit_repo' && FAKE_CODEX_LOG='$fake_log' FAKE_COMMIT_REPO='$commit_repo' MYUNIX_CODEX_BIN='$fake_bin/codex' '$fake_bin/super-bullet' exec 'commit a change'"
assert_status 0
assert_output_contains 'SuperBullet: active — Sol validation'
run tail -n 1 "$fake_log"
assert_status 0
assert_output_contains "--base $before_commit"

run env FAKE_CODEX_LOG="$fake_log" MYUNIX_CODEX_BIN="$fake_bin/codex" "$fake_bin/super-bullet" --help
assert_status 0
assert_output_contains 'super-bullet run'

printf 'Codex SuperBullet tests passed.\n'
