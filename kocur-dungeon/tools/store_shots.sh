#!/usr/bin/env bash
# Regenerates every Microsoft Store image: screenshots (1920x1080), key art and
# MSIX logos. Needs Godot 4.3 and xvfb-run.  Usage: tools/store_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SHOTS=store/screenshots ART=store/art ASSETS=store/msix/Assets
mkdir -p "$SHOTS" "$ART" "$ASSETS"
shot() { xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . -s res://tools/store_shots.gd -- "$PWD/$SHOTS/$1" "${@:2}" 2>/dev/null | grep saved; }
art() { xvfb-run -a -s "-screen 0 3900x2200x24" "$GODOT" --path . -s res://tools/store_art.gd -- "$1" "$PWD/$2" "${@:3}" 2>/dev/null | grep saved; }
shot 01_main_menu.png res://scenes/main_menu.tscn wait:60
shot 02_mossroot_catacombs.png 1-1 wait:240 tp:33,15 wait:40 move_right:12 attack:4 wait:6
shot 03_emberpaw_mines.png 2-2 wait:240 tp:90,12 wait:30 move_right:6 attack:4 wait:8
shot 04_frostfang_crypt.png 3-2 wait:240 tp:74,18 wait:30 move_right:10 wait:20
shot 05_shadowclaw_depths.png 4-1 wait:240 tp:80,20 wait:30 move_right:8 wait:20
shot 06_pale_citadel.png 5-2 wait:240 tp:72,18 wait:30 move_right:8 attack:4 wait:6
shot 07_boss_ember_guardian.png 2-3 wait:240 tp:100,21 wait:150
shot 08_boss_pale_king.png final wait:240 tp:46,21 wait:180
shot 09_camp_upgrades.png res://scenes/camp.tscn wait:30 tab:upgrades wait:20
art key $ART/hero_3840x2160.png 3840 2160 6 5
art key $ART/boxart_2160x2160.png 2160 2160 6 5
art key $ART/poster_1440x2160.png 1440 2160 6 5
art banner $ASSETS/Wide310x150Logo.png 620 300 2
art banner $ASSETS/SplashScreen.png 1240 600 4
"$GODOT" --headless --path . -s res://tools/make_msix_assets.gd | grep asset
