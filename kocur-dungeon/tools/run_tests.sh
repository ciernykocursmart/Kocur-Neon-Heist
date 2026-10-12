#!/usr/bin/env bash
# Runs the automated test suite headless. Usage: tools/run_tests.sh [suite ...]
# Fails if any test fails OR if Godot reported a script error during the run.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout 1800 "$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
  echo "FAILED: script errors were reported during the run (see above)."
  code=1
fi
if ! grep -q "^RESULT:" "$LOG"; then
  echo "FAILED: the test runner did not finish."
  code=1
fi
rm -f "$LOG"
exit $code
