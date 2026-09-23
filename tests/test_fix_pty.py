#!/usr/bin/env python3
"""Exercise the real repair CLI and nested selectors on a terminal, not test mode."""
import errno
import os
from pathlib import Path
import pty
import select
import signal
import tempfile
import time


root = Path(__file__).resolve().parents[1]


def run_case(outcome):
    with tempfile.TemporaryDirectory(prefix="myunix-fix-pty-") as home:
        exercise_terminal(home, outcome)


def exercise_terminal(home, outcome):
    pid, terminal = pty.fork()
    if pid == 0:
        env = dict(os.environ, HOME=home, XDG_DATA_HOME=f"{home}/.local/share",
                   XDG_CONFIG_HOME=f"{home}/.config", TERM="xterm")
        for key in list(env):
            if key.startswith("MYUNIX_") or key == "NIRI_SOCKET":
                env.pop(key)
        env.update(MYUNIX_SYSTEM_APPLICATIONS_DIR=f"{home}/system-applications",
                   MYUNIX_FLATPAK_USER_APPLICATIONS_DIR=f"{home}/flatpak-user",
                   MYUNIX_FLATPAK_SYSTEM_APPLICATIONS_DIR=f"{home}/flatpak-system")
        if outcome == "cancelled":
            os.execve(str(root / "scripts/myunix"), ["myunix", "fix"], env)
        # Keep the real terminal selectors and dispatcher while bounding the
        # apply/verify phases: no live package or desktop operation may run.
        env.update(MYUNIX_SOURCE_ONLY="1", FIX_PTY_OUTCOME=outcome)
        fixture = """
source "$1/scripts/myunix"
fix_diagnose_wechat_cangjie() { [[ "$FIX_PTY_OUTCOME" == clean ]]; }
fix_plan_wechat_cangjie() { printf 'Fixture next steps remain visible.\\n'; }
fix_apply_wechat_cangjie() { [[ "$FIX_PTY_OUTCOME" != failure ]]; }
fix_verify_wechat_cangjie() { [[ "$FIX_PTY_OUTCOME" != verification-failure ]]; }
run_fix
"""
        os.execve("/usr/bin/bash", ["bash", "-c", fixture, "bash", str(root)], env)

    transcript = bytearray()
    cursor = 0

    def expect(text):
        nonlocal cursor
        deadline = time.monotonic() + 10
        expected = text.encode()
        while expected not in transcript[cursor:]:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f"Timed out waiting for {text!r}: {transcript.decode(errors='replace')}")
            ready, _, _ = select.select([terminal], [], [], remaining)
            if ready:
                try:
                    data = os.read(terminal, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    data = b""
                if not data:
                    raise AssertionError(f"CLI exited before {text!r}: {transcript.decode(errors='replace')}")
                transcript.extend(data)
        cursor = transcript.index(expected, cursor) + len(expected)

    def collect_pending_output():
        while select.select([terminal], [], [], 0.1)[0]:
            transcript.extend(os.read(terminal, 65536))

    try:
        expect("MyUnix repair")
        os.write(terminal, b"\r")
        expect("WeChat / Cangjie compatibility")
        os.write(terminal, b"\r")
        expect("Diagnosis:")
        if outcome != "clean":
            expect("Plan:")
            expect("Apply this repair? [y/N]")
            os.write(terminal, b"n\r" if outcome == "cancelled" else b"y\r")
        result = {"cancelled": "cancelled", "clean": "diagnosis clean; no change needed",
                  "success": "repaired and verified", "failure": "repair failed",
                  "verification-failure": "repair failed: verification did not pass"}[outcome]
        expect(result)
        result_end = cursor
        expect("Press Enter to return to categories.")
        collect_pending_output()
        assert b"\x1b[H\x1b[2J" not in transcript[result_end:], "result cleared before acknowledgement"
        assert b"MyUnix repair" not in transcript[result_end:], "category redrawn before acknowledgement"
        os.write(terminal, b"private-acknowledgement-value\r")
        expect("MyUnix repair")
        assert b"private-acknowledgement-value" not in transcript, "acknowledgement input leaked"
        # Re-enter the category and use the explicit Back entry.
        os.write(terminal, b"\r")
        expect("Back to categories")
        os.write(terminal, b"\x1b[B\r")
        expect("MyUnix repair")
        # The explicit Exit entry is immediately above the first category.
        os.write(terminal, b"\x1b[A\r")
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            ended, status = os.waitpid(pid, os.WNOHANG)
            if ended:
                expected_status = 1 if outcome in ("failure", "verification-failure") else 0
                assert os.waitstatus_to_exitcode(status) == expected_status
                pid = 0
                break
            select.select([], [], [], 0.02)
        assert pid == 0, "CLI did not exit after selecting Exit"
        assert not (Path(home) / ".config/fcitx5/profile").exists()
        print(f"PASS: real PTY repair {outcome}, acknowledgement, back, and exit")
    finally:
        os.close(terminal)
        if pid:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)


for case in ("cancelled", "success", "clean", "failure", "verification-failure"):
    run_case(case)
