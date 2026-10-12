#!/usr/bin/env bash
# Builds the Windows x64 release and packages it as a ZIP.
#   tools/build_windows.sh
# Needs Godot 4.3 (GODOT env var or `godot` on PATH) and the 4.3.stable export
# templates. Output: build/windows/KocurDungeon-windows-x86_64.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/windows
PKG="$OUT/KocurDungeon"
rm -rf "$PKG" "$OUT/KocurDungeon.exe" "$OUT/KocurDungeon-windows-x86_64.zip"
mkdir -p "$PKG"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/KocurDungeon.exe"
test -s "$OUT/KocurDungeon.exe"
cp "$OUT/KocurDungeon.exe" "$PKG/KocurDungeon.exe"
cp build/PLAYER_README.txt "$PKG/README.txt"
cp LICENSE_GODOT.txt "$PKG/LICENSE_GODOT.txt"
(cd "$OUT" && rm -f KocurDungeon-windows-x86_64.zip && \
  python3 -c "import shutil; shutil.make_archive('KocurDungeon-windows-x86_64', 'zip', '.', 'KocurDungeon')")
echo "Built $OUT/KocurDungeon-windows-x86_64.zip"
# Smoke-test the exported content with the Linux binary (cannot run the .exe here).
# Run from an empty directory so Godot does not pick up project.godot from here.
ROOT="$PWD"
TMP="$(mktemp -d)"
(cd "$TMP" && "$GODOT" --headless --main-pack "$ROOT/$OUT/KocurDungeon.exe" -s "$ROOT/tools/pack_smoke.gd")
rm -rf "$TMP"
