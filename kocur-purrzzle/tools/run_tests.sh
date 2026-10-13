#!/usr/bin/env bash
# Runs every automated check. Usage: tools/run_tests.sh [godot]
set -uo pipefail
cd "$(dirname "$0")/.."
G="${1:-godot}"
rc=0
echo "== unit tests =="; $G --headless --path . -s res://tests/test_suite.gd 2>&1 | grep -E "TESTS|FAIL" || rc=1
echo "== UI playthrough of all levels =="; $G --headless --path . -s res://tests/smoke.gd 2>&1 | grep -E "UI playthrough|screens ok|FAIL|SCRIPT ERROR" || rc=1
echo "== two-process save persistence =="; bash tests/persist_check.sh "$G" || rc=1
exit $rc
