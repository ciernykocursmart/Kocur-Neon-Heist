#!/usr/bin/env bash
# Builds the Windows x64 release and packages it as a ZIP.
#   tools/build_windows.sh
# Needs Godot 4.3 (GODOT env var or `godot` on PATH) and the 4.3.stable export
# templates. Output: build/windows/KocurTactics-windows-x86_64.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/windows
PKG="$OUT/KocurTactics"
rm -rf "$PKG" "$OUT/KocurTactics.exe" "$OUT/KocurTactics-windows-x86_64.zip"
mkdir -p "$PKG"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/KocurTactics.exe"
test -s "$OUT/KocurTactics.exe"
cp "$OUT/KocurTactics.exe" "$PKG/KocurTactics.exe"
cp build/PLAYER_README.txt "$PKG/README.txt"
cp LICENSE_GODOT.txt "$PKG/LICENSE_GODOT.txt"
(cd "$OUT" && rm -f KocurTactics-windows-x86_64.zip && \
  python3 -c "import shutil; shutil.make_archive('KocurTactics-windows-x86_64', 'zip', '.', 'KocurTactics')")
echo "Built $OUT/KocurTactics-windows-x86_64.zip"
# Smoke-test the exported content with the Linux binary (the .exe cannot run here).
# Run from an empty directory so Godot does not pick up project.godot from here.
ROOT="$PWD"
TMP="$(mktemp -d)"
(cd "$TMP" && "$GODOT" --headless --main-pack "$ROOT/$OUT/KocurTactics.exe" -s "$ROOT/tools/pack_smoke.gd")
(cd "$TMP" && "$GODOT" --headless --main-pack "$ROOT/$OUT/KocurTactics.exe" -s "$ROOT/tools/pack_smoke.gd" -- verify)
rm -rf "$TMP"
