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
with tempfile.TemporaryDirectory(prefix="myunix-fix-pty-") as home:
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
        os.execve(str(root / "scripts/myunix"), ["myunix", "fix"], env)

    transcript = bytearray()
    cursor = 0

    def expect(text):
        global cursor
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

    try:
        expect("MyUnix repair")
        os.write(terminal, b"\r")
        expect("WeChat / Cangjie compatibility")
        os.write(terminal, b"\r")
        expect("Diagnosis:")
        expect("Plan:")
        expect("Apply this repair? [y/N]")
        os.write(terminal, b"n\r")
        expect("cancelled")
        expect("MyUnix repair")
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
                assert os.waitstatus_to_exitcode(status) == 0
                pid = 0
                break
            select.select([], [], [], 0.02)
        assert pid == 0, "CLI did not exit after selecting Exit"
        assert not (Path(home) / ".config/fcitx5/profile").exists()
        print("PASS: real PTY repair diagnosis, cancellation, back, and exit")
    finally:
        os.close(terminal)
        if pid:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
