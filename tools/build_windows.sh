#!/usr/bin/env bash
# Builds the Windows x64 release of KOCUR: NEON HEIST.
#
# 1. Stamps icon + version info into a copy of the Godot release template.
# 2. Exports with the "Windows Desktop" preset using that template.
# 3. Zips the result with README.txt and Godot's licence text.
#
# Usage: tools/build_windows.sh [path/to/godot]   (default: godot on PATH)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2)"
GODOT_VER="4.3.stable"
case "$(uname -s)" in
  Darwin) TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VER" ;;
  MINGW*|MSYS*|CYGWIN*) TPL_DIR="$APPDATA/Godot/export_templates/$GODOT_VER" ;;
  *) TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VER" ;;
esac
TEMPLATE="$TPL_DIR/windows_release_x86_64.exe"
[ -f "$TEMPLATE" ] || { echo "Missing export template: $TEMPLATE"; exit 1; }

(cd tools && npm install --silent --no-audit --no-fund)

mkdir -p build/windows build/template
cp "$TEMPLATE" build/template/original_release.exe
node tools/patch_windows_exe.mjs build/template/original_release.exe "$TEMPLATE" icon.ico "$VERSION"
restore() { cp build/template/original_release.exe "$TEMPLATE"; }
trap restore EXIT

"$GODOT" --headless --path . -s res://tests/write_godot_license.gd
rm -f build/windows/KocurNeonHeist.exe
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/KocurNeonHeist.exe
test -s build/windows/KocurNeonHeist.exe

(cd build/windows && rm -f KocurNeonHeist-windows-x86_64.zip && \
  python3 - <<'PY'
import zipfile
with zipfile.ZipFile('KocurNeonHeist-windows-x86_64.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    z.write('KocurNeonHeist.exe', 'KocurNeonHeist/KocurNeonHeist.exe')
    z.write('README.txt', 'KocurNeonHeist/README.txt')
    z.write('LICENSE_GODOT.txt', 'KocurNeonHeist/LICENSE_GODOT.txt')
PY
)
echo "Built build/windows/KocurNeonHeist-windows-x86_64.zip (v$VERSION)"
