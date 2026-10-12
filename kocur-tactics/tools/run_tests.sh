#!/usr/bin/env bash
# Runs the automated test suite headless. Usage: tools/run_tests.sh [suite ...]
# Fails if any test fails OR if Godot reported a script error during the run.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 1800 "$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
  echo "FAILED: script errors were reported during the run (see above)."
  code=1
fi
if ! grep -q "^RESULT:" "$LOG"; then
  echo "FAILED: the test runner did not finish."
  code=1
fi
# Save persistence across a real restart: two separate Godot processes.
if [ "$#" -eq 0 ] || [[ " $* " == *" restart "* ]]; then
  "$GODOT" --headless --path . -s res://tests/restart_check.gd -- write 2>&1 | grep -E "RESTART|FAIL|SCRIPT ERROR" | tee -a "$LOG"
  "$GODOT" --headless --path . -s res://tests/restart_check.gd -- verify 2>&1 | grep -E "RESTART|ok |FAIL|SCRIPT ERROR" | tee -a "$LOG"
  if ! grep -q "RESTART VERIFY: PASS" "$LOG" || ! grep -q "RESTART WRITE: PASS" "$LOG"; then
    echo "FAILED: save did not survive an application restart."
    code=1
  fi
fi
rm -f "$LOG"
exit $code
