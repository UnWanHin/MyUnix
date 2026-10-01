#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/test_helper.bash"

temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

for scenario in package-fixed override-present override-missing apply build-failure verify; do
  [[ -z "${TEST_CASE:-}" || "$TEST_CASE" == "$scenario" ]] || continue
  home="$temporary_dir/$scenario"
  mkdir -p "$home"
  run env HOME="$home" SCENARIO="$scenario" TRACE="$home/trace" \
    MYUNIX_XWAYLAND_SATELLITE_OVERRIDE="$home/usr/local/bin/xwayland-satellite" \
    bash -c '
    source "'"$PROJECT_ROOT"'/scripts/lib/core.sh"
    source "'"$PROJECT_ROOT"'/modules/fix/install.sh"

    override="$(fix_xwayland_satellite_override_path)"
    mkdir -p "$(dirname "$override")"

    rpm() {
      case "$*" in
        *--eval*) printf "%s\n" /usr/lib64 ;;
        "-q --qf"*)
          if [[ "$SCENARIO" == package-fixed ]]; then
            printf "%s\n" "0.8.3-1.fc44"
          else
            printf "%s\n" "0.8.2-1.fc44"
          fi
          ;;
        "-ql"*) printf "%s\n" /usr/bin/xwayland-satellite ;;
        *) return 1 ;;
      esac
    }
    dnf() {
      printf "dnf %s\n" "$*" >> "$TRACE"
      local previous= destdir=
      for argument in "$@"; do
        [[ "$previous" == "--destdir" ]] && destdir="$argument"
        previous="$argument"
      done
      : > "$destdir/xcb-util-cursor-devel-0.1.6-2.fc44.x86_64.rpm"
      : > "$destdir/xcb-util-image-devel-0.4.1-9.fc44.x86_64.rpm"
    }
    rpm2cpio() {
      printf "rpm2cpio %s\n" "$1" >> "$TRACE"
    }
    cpio() {
      printf "cpio %s\n" "$*" >> "$TRACE"
      mkdir -p usr/include/xcb
      : > usr/include/xcb/xcb_cursor.h
    }
    cargo() {
      printf "cargo %s\n" "$*" >> "$TRACE"
      printf "PKG_CONFIG_PATH=%s\n" "${PKG_CONFIG_PATH:-}" >> "$TRACE"
      printf "CPATH=%s\n" "${CPATH:-}" >> "$TRACE"
      printf "LIBRARY_PATH=%s\n" "${LIBRARY_PATH:-}" >> "$TRACE"
      [[ "$SCENARIO" == build-failure ]] && return 1
      local previous= root=
      for argument in "$@"; do
        [[ "$previous" == "--root" ]] && root="$argument"
        previous="$argument"
      done
      mkdir -p "$root/bin"
      printf "%s\n" "built satellite" > "$root/bin/xwayland-satellite"
      chmod 0755 "$root/bin/xwayland-satellite"
    }
    sudo() {
      printf "sudo %s\n" "$*" >> "$TRACE"
      command install "${@:2}"
    }

    case "$SCENARIO" in
      package-fixed)
        fix_diagnose_xwayland_satellite
        fix_verify_xwayland_satellite
        ;;
      override-present)
        printf "%s\n" "existing override" > "$override"
        chmod 0755 "$override"
        XWAYLAND_SATELLITE_BUILD_SHA256="$(sha256sum "$override" | awk "{print \$1}")"
        fix_diagnose_xwayland_satellite
        test "$(fix_xwayland_satellite_override_sha256 "$override")" = "$XWAYLAND_SATELLITE_BUILD_SHA256"
        ;;
      override-missing)
        ! fix_diagnose_xwayland_satellite
        ! fix_verify_xwayland_satellite
        ;;
      apply)
        fix_apply_xwayland_satellite
        test -x "$override"
        cmp "$override" <(printf "%s\n" "built satellite")
        fix_verify_xwayland_satellite
        fix_diagnose_xwayland_satellite
        ;;
      build-failure)
        ! fix_apply_xwayland_satellite
        test ! -e "$override"
        ;;
      verify)
        printf "%s\n" "not executable" > "$override"
        chmod 0644 "$override"
        ! fix_verify_xwayland_satellite
        fix_diagnose_xwayland_satellite || true
        ;;
    esac
  '
  assert_status 0
  case "$scenario" in
    package-fixed)
      assert_output_contains 'already carries the upstream focus fix'
      ;;
    override-present)
      assert_output_contains 'matches the pinned v0.8.3 build'
      assert_output_contains 'Effective satellite'
      ;;
    override-missing)
      assert_output_contains 'override: missing'
      assert_output_contains 'missing ('
      ;;
    apply)
      assert_output_contains 'Building xwayland-satellite v0.8.3 from the pinned upstream tag'
      assert_output_contains 'Restart Steam'
      grep -Fq -- '--tag v0.8.3 --locked --root' "$home/trace" || {
        printf '%s\n' 'Expected the pinned tag to be built with --locked' >&2
        exit 1
      }
      grep -Fq -- '--arch x86_64 xcb-util-cursor-devel' "$home/trace" || {
        printf '%s\n' 'Expected the build dependencies to be downloaded for x86_64' >&2
        exit 1
      }
      grep -Eq 'PKG_CONFIG_PATH=.*/sysroot/usr/lib64/pkgconfig' "$home/trace" || {
        printf '%s\n' 'Expected the build to use the temporary sysroot pkg-config path' >&2
        exit 1
      }
      grep -Eq 'CPATH=.*/sysroot/usr/include' "$home/trace" || {
        printf '%s\n' 'Expected the build to expose the temporary sysroot headers' >&2
        exit 1
      }
      grep -Eq 'LIBRARY_PATH=.*/sysroot/usr/lib64' "$home/trace" || {
        printf '%s\n' 'Expected the build to expose the temporary sysroot libraries' >&2
        exit 1
      }
      grep -Fq "sudo install -m 0755" "$home/trace" || {
        printf '%s\n' 'Expected the built binary to be installed as a /usr/local/bin override' >&2
        exit 1
      }
      if grep -Fq 'dnf install' "$home/trace"; then
        printf '%s\n' 'The repair must not install build dependencies system-wide' >&2
        exit 1
      fi
      ;;
    build-failure)
      assert_output_contains 'Building the pinned xwayland-satellite release failed'
      ;;
    verify)
      assert_output_contains 'override: present but not executable'
      ;;
  esac
  printf 'PASS: XWayland satellite repair %s\n' "$scenario"
done

run bash -c "source '$PROJECT_ROOT/modules/fix/install.sh'; fix_plan_xwayland_satellite"
assert_status 0
assert_output_contains 'require_wm_focus()'
assert_output_contains 'cargo install --git https://github.com/Supreeeme/xwayland-satellite --tag v0.8.3 --locked'
assert_output_contains 'sudo only to install the built binary'
