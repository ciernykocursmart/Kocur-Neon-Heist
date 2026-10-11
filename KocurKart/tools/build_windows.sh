#!/usr/bin/env bash
# Builds the Windows x64 release of Kocur Kart and packs it as a ZIP.
#   tools/build_windows.sh [path/to/godot]
# Output: build/windows/KocurKart.exe and build/release/KocurKart-1.0.0-windows-x86_64.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2)"
OUT=build/windows
REL=build/release
STAGE=build/release/KocurKart
mkdir -p "$OUT" "$REL"
touch build/.gdignore   # keep Godot from scanning build output (and any Wine prefix)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -f "$OUT/KocurKart.exe"
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/KocurKart.exe"
test -s "$OUT/KocurKart.exe"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$OUT/KocurKart.exe" "$STAGE/"
"$GODOT" --headless --path . -s res://tools/write_licenses.gd -- "$PWD/$STAGE" >/dev/null 2>&1
cp assets/fonts/OFL.txt "$STAGE/LICENSE_FREDOKA_FONT.txt"
cp tools/release/README.txt "$STAGE/README.txt"
ZIP="$REL/KocurKart-$VERSION-windows-x86_64.zip"
rm -f "$ZIP"
(cd "$REL" && python3 - "KocurKart-$VERSION-windows-x86_64.zip" <<'PY'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for name in sorted(os.listdir("KocurKart")):
        z.write(os.path.join("KocurKart", name), "KocurKart/" + name)
PY
)
ls -la "$OUT/KocurKart.exe" "$ZIP"
echo "Built $ZIP (v$VERSION)"
