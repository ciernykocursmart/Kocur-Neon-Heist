#!/usr/bin/env bash
# Builds the Windows x64 release and packages it as a ZIP.
#   tools/build_windows.sh
# Needs Godot 4.3 (GODOT env var or `godot` on PATH) and the 4.3.stable export
# templates, plus Node.js (npm) for the icon/version stamping step.
# Output: build/windows/StreetsOfKocur-windows-x86_64.zip
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2)"
case "$(uname -s)" in
  Darwin) TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/4.3.stable" ;;
  MINGW*|MSYS*|CYGWIN*) TPL_DIR="$APPDATA/Godot/export_templates/4.3.stable" ;;
  *) TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.3.stable" ;;
esac
TEMPLATE="$TPL_DIR/windows_release_x86_64.exe"
[ -f "$TEMPLATE" ] || { echo "Missing export template: $TEMPLATE"; exit 1; }
# Stamp icon.ico and version info into a copy of the release template; Godot
# then embeds the game data into the already-branded executable (patching the
# exported .exe afterwards would disturb the embedded PCK). Restored on exit.
(cd tools && npm install --silent --no-audit --no-fund)
mkdir -p build/template
cp "$TEMPLATE" build/template/original_release.exe
node tools/patch_windows_exe.mjs build/template/original_release.exe "$TEMPLATE" icon.ico "$VERSION"
restore() { cp build/template/original_release.exe "$TEMPLATE"; }
trap restore EXIT
OUT=build/windows
PKG="$OUT/StreetsOfKocur"
rm -rf "$PKG" "$OUT/StreetsOfKocur.exe" "$OUT/StreetsOfKocur-windows-x86_64.zip"
mkdir -p "$PKG"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/StreetsOfKocur.exe"
test -s "$OUT/StreetsOfKocur.exe"
cp "$OUT/StreetsOfKocur.exe" "$PKG/StreetsOfKocur.exe"
cp build/PLAYER_README.txt "$PKG/README.txt"
cp LICENSE_GODOT.txt "$PKG/LICENSE_GODOT.txt"
(cd "$OUT" && rm -f StreetsOfKocur-windows-x86_64.zip && \
  python3 -c "import shutil; shutil.make_archive('StreetsOfKocur-windows-x86_64', 'zip', '.', 'StreetsOfKocur')")
echo "Built $OUT/StreetsOfKocur-windows-x86_64.zip"
# Smoke-test the exported content with the Linux binary (the .exe cannot run here).
# Run from an empty directory so Godot does not pick up project.godot from here.
ROOT="$PWD"
TMP="$(mktemp -d)"
(cd "$TMP" && "$GODOT" --headless --main-pack "$ROOT/$OUT/StreetsOfKocur.exe" -s "$ROOT/tools/pack_smoke.gd")
(cd "$TMP" && "$GODOT" --headless --main-pack "$ROOT/$OUT/StreetsOfKocur.exe" -s "$ROOT/tools/pack_smoke.gd" -- verify)
rm -rf "$TMP"
