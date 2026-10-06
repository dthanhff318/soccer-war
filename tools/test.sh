#!/usr/bin/env bash
# Runs the headless test suite. Optional arg filters suites by file name.
# A watchdog kills Godot after 120 s so a hung test can't block CI.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --import >/dev/null 2>&1 || true
perl -e 'alarm shift; exec @ARGV' 120 godot --headless -s tests/run_tests.gd -- "$@"
