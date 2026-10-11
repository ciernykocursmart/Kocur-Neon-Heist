#!/usr/bin/env bash
# Runs the headless test suite and fails on any failed check or script error.
#   tools/run_tests.sh [godot] [module-filter] [report-dir]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
FILTER="${2:-all}"
REPORT="${3:-build/test_report}"
mkdir -p "$REPORT"
mkdir -p build && touch build/.gdignore
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- "$FILTER" "$PWD/$REPORT" 2>&1 | tee "$REPORT/test.log"
status=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$REPORT/test.log"; then
	echo "Script errors found in the test log:"
	grep -A2 "SCRIPT ERROR" "$REPORT/test.log" | head -40
	exit 1
fi
exit $status
