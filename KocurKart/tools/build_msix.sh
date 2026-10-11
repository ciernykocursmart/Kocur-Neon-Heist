#!/usr/bin/env bash
# Packs the Windows build into an unsigned MSIX for Microsoft Store submission.
#   tools/build_msix.sh            (run tools/build_windows.sh first)
# Identity (Partner Center): 59513Lukes.KocurKart / CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD / Kocur
# DISPLAY_NAME must match the app name reserved in Partner Center exactly.
# Partner Center signs Store submissions; for local side-loading sign a copy
# with a certificate whose subject equals the Publisher above.
set -euo pipefail
cd "$(dirname "$0")/.."
DISPLAY_NAME="${DISPLAY_NAME:-Kocur Kart}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2).0"
EXE=build/windows/KocurKart.exe
[ -s "$EXE" ] || { echo "Missing $EXE - run tools/build_windows.sh first"; exit 1; }
STAGE=build/msix/staging
rm -rf "$STAGE"
mkdir -p "$STAGE/Assets"
cp "$EXE" "$STAGE/"
cp build/release/KocurKart/README.txt build/release/KocurKart/LICENSE_GODOT.txt build/release/KocurKart/LICENSE_FREDOKA_FONT.txt "$STAGE/"
cp store/msix/Assets/*.png "$STAGE/Assets/"
sed -e "s/@VERSION@/$VERSION/" -e "s/@DISPLAY_NAME@/$DISPLAY_NAME/g" store/msix/AppxManifest.xml > "$STAGE/AppxManifest.xml"
python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$STAGE/AppxManifest.xml"
OUT="build/msix/KocurKart_${VERSION}_x64.msix"
rm -f "$OUT"
python3 tools/msix/pack_msix.py "$STAGE" "$OUT"
python3 tools/msix/check_msix.py "$OUT"
echo "Built $OUT (version $VERSION, display name '$DISPLAY_NAME')"
