#!/usr/bin/env bash
# Packs the Windows build into an MSIX for Microsoft Store submission.
#
#   tools/build_msix.sh [path/to/makemsix]
#
# Prerequisites: run tools/build_windows.sh first (it produces
# build/windows/KocurTactics.exe). makemsix comes from Microsoft's open-source
# MSIX SDK (github.com/microsoft/msix-packaging, built with ./makelinux.sh --pack);
# on Windows, MakeAppx.exe from the Windows SDK works the same way:
#   MakeAppx pack /d build/msix/staging /p <out>.msix
#
# The package is unsigned on purpose: Partner Center signs Store submissions.
# For a local side-load test, sign a copy with SignTool and a certificate whose
# subject matches the Publisher in store/msix/AppxManifest.xml.
#
# DISPLAY_NAME must match the app name reserved in Partner Center exactly.
set -euo pipefail
cd "$(dirname "$0")/.."
MAKEMSIX="${1:-makemsix}"
DISPLAY_NAME="${DISPLAY_NAME:-Kocur Tactics}"
VERSION="$(grep '^config/version=' project.godot | cut -d'"' -f2).0"

EXE=build/windows/KocurTactics.exe
[ -s "$EXE" ] || { echo "Missing $EXE - run tools/build_windows.sh first"; exit 1; }

STAGE=build/msix/staging
rm -rf "$STAGE"
mkdir -p "$STAGE/Assets"
cp "$EXE" "$STAGE/"
cp build/PLAYER_README.txt "$STAGE/README.txt"
cp LICENSE_GODOT.txt "$STAGE/"
cp store/msix/Assets/*.png "$STAGE/Assets/"
sed -e "s/@VERSION@/$VERSION/" -e "s/@DISPLAY_NAME@/$DISPLAY_NAME/g" store/msix/AppxManifest.xml > "$STAGE/AppxManifest.xml"

OUT="build/msix/KocurTactics_${VERSION}_x64.msix"
rm -f "$OUT"
"$MAKEMSIX" pack -d "$STAGE" -p "$OUT"
rm -rf "$STAGE"
echo "Built $OUT (version $VERSION, display name '$DISPLAY_NAME')"
