#!/usr/bin/env bash
# Runs every automated check. Usage: tools/run_tests.sh [godot]
set -uo pipefail
cd "$(dirname "$0")/.."
G="${1:-godot}"
rc=0
echo "== unit tests =="; $G --headless --path . -s res://tests/test_suite.gd 2>&1 | grep -E "TESTS|FAIL" || rc=1
echo "== UI playthrough of all levels =="; $G --headless --path . -s res://tests/smoke.gd 2>&1 | grep -E "UI playthrough|screens ok|FAIL|SCRIPT ERROR" || rc=1
echo "== two-process save persistence =="; bash tests/persist_check.sh "$G" || rc=1
echo "== real keyboard bot (key events through Godot input, all levels + hold/switch) =="
if command -v xvfb-run >/dev/null; then
  xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tests/keybot.gd -- 2 draw 2>&1 | grep -E "KEYBOT|NOT WON|HOLD|SWITCH|drawn|wall|SCRIPT ERROR" || rc=1
  xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tests/facing_shot.gd 2>&1 | grep -E "FACING|SCRIPT ERROR" || rc=1
else
  echo "skipped (needs xvfb-run)"
fi
exit $rc
