#!/usr/bin/env bash
# Builds the Windows x64 release of KOCUR PURRZZLE.
#  1. stamps icon + version info into a copy of the Godot release template
#  2. exports with the "Windows Desktop" preset
#  3. smoke-tests the exported .pck with headless Godot and zips exe + README + licence + MANIFEST
# Usage: tools/build_windows.sh [path/to/godot]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2)"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.3.stable"
TEMPLATE="$TPL_DIR/windows_release_x86_64.exe"
[ -f "$TEMPLATE" ] || { echo "Missing export template: $TEMPLATE"; exit 1; }

(cd tools && npm install --silent --no-audit --no-fund)
mkdir -p build/windows build/template
cp "$TEMPLATE" build/template/original_release.exe
node tools/patch_windows_exe.mjs build/template/original_release.exe "$TEMPLATE" icon.ico "$VERSION"
restore() { cp build/template/original_release.exe "$TEMPLATE"; }
trap restore EXIT

"$GODOT" --headless --path . -s res://tests/write_godot_license.gd
rm -f build/windows/KocurPurrzzle.exe
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/KocurPurrzzle.exe
test -s build/windows/KocurPurrzzle.exe

python3 - "$VERSION" <<'PY'
import zipfile, sys, hashlib, os
ver = sys.argv[1]
os.chdir('build/windows')
readme = open('../../README.md', encoding='utf-8').read()
files = {'KocurPurrzzle/KocurPurrzzle.exe': 'KocurPurrzzle.exe', 'KocurPurrzzle/LICENSE_GODOT.txt': 'LICENSE_GODOT.txt'}
manifest = ['KOCUR PURRZZLE v%s - file manifest (sha256)' % ver]
for arc, src in files.items():
    manifest.append('%s  %s' % (hashlib.sha256(open(src, 'rb').read()).hexdigest(), arc.split('/')[1]))
with zipfile.ZipFile('KocurPurrzzle-windows-x86_64.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for arc, src in files.items():
        z.write(src, arc)
    z.writestr('KocurPurrzzle/README.md', readme)
    z.writestr('KocurPurrzzle/MANIFEST.txt', '\n'.join(manifest) + '\n')
print('\n'.join(manifest))
PY
echo "Built build/windows/KocurPurrzzle-windows-x86_64.zip (v$VERSION)"
