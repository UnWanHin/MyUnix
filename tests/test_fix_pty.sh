#!/usr/bin/env bash
set -Eeuo pipefail
python3 "$(dirname "$0")/test_fix_pty.py"
