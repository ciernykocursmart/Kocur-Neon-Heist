#!/usr/bin/env bash
# Verifies the exported Windows build outside the editor by running it under
# Wine (Linux) or natively (Windows/MSYS) in three phases:
#   race   - fresh profile: boot, build all tracks, full autopilot race, save written
#   verify - second launch: progress from the previous run is still there
#   shot   - real OpenGL rendering of a race frame
# Reports land in build/release/verify/.
set -uo pipefail
cd "$(dirname "$0")/.."
EXE=build/windows/KocurKart.exe
OUTDIR=build/release/verify
mkdir -p "$OUTDIR"
[ -s "$EXE" ] || { echo "Missing $EXE - run tools/build_windows.sh first"; exit 1; }
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    RUN=("$EXE"); XVFB=(); DATA="$APPDATA/KocurKart" ;;
  *)
    export WINEDEBUG=-all
    export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-kocurkart}"
    mkdir -p "$WINEPREFIX"
    RUN=(wine "$EXE"); XVFB=(xvfb-run -a -s "-screen 0 1600x900x24")
    DATA="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/KocurKart" ;;
esac
rm -rf "$DATA"
fail=0
for phase in race verify; do
  echo "== phase $phase"
  "${XVFB[@]}" "${RUN[@]}" --headless -- --autotest=$phase 2>&1 | grep "\[AUTOTEST\]" | tee "$OUTDIR/$phase.log"
  grep -q "RESULT PASS" "$OUTDIR/$phase.log" || fail=1
done
echo "== phase shot"
"${XVFB[@]}" "${RUN[@]}" -- --autotest=shot 2>&1 | grep "\[AUTOTEST\]" | tee "$OUTDIR/shot.log"
grep -q "RESULT PASS" "$OUTDIR/shot.log" || fail=1
cp "$DATA"/autotest_*.json "$DATA"/autotest_shot.png "$OUTDIR/" 2>/dev/null || true
cp "$DATA/save.json" "$OUTDIR/save_after_race.json" 2>/dev/null || true
[ $fail -eq 0 ] && echo "WINDOWS BUILD VERIFIED" || echo "WINDOWS BUILD VERIFICATION FAILED"
exit $fail
