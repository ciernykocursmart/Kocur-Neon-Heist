#!/usr/bin/env bash
# Regenerates every Microsoft Store image: screenshots (1920x1080), key art and
# MSIX logos. Needs Godot 4.3 and xvfb-run.  Usage: tools/store_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SHOTS=store/screenshots ART=store/art ASSETS=store/msix/Assets
mkdir -p "$SHOTS" "$ART" "$ASSETS"
art() { xvfb-run -a -s "-screen 0 3900x2200x24" "$GODOT" --path . -s res://tools/store_art.gd -- "$1" "$PWD/$2" "${@:3}" 2>/dev/null | grep saved; }
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . -s res://tools/store_shots.gd -- "$PWD/$SHOTS" 2>/dev/null | grep saved
art key $ART/hero_3840x2160.png 3840 2160 6
art key $ART/boxart_2160x2160.png 2160 2160 6
art key $ART/poster_1440x2160.png 1440 2160 6
art banner $ASSETS/Wide310x150Logo.png 620 300 2
art banner $ASSETS/SplashScreen.png 1240 600 4
"$GODOT" --headless --path . -s res://tools/make_msix_assets.gd | grep asset
