#!/usr/bin/env bash
# Regenerates every Microsoft Store image: screenshots (1920x1080), key art and
# MSIX logos. Needs Godot 4.3 and xvfb-run.  Usage: tools/store_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SHOTS=store/screenshots ART=store/art ASSETS=store/msix/Assets
mkdir -p "$SHOTS" "$ART" "$ASSETS"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Screenshots: tests/shot.gd at 1920x1080 (the game scales its 1280x720 canvas up).
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . -s res://tests/shot.gd -- "$TMP" \
	size:1920x1080 menu level:0:1050:punk,punk,brawler:50 level:1:2000:runner,thrower,punk,punk:80 \
	level:2:3000:thrower,runner,punk:70 level:2:5860:slick:260 level:3:3300:enforcer,brawler,punk:90 \
	level:3:6250:bruno:260 level:4:6660:snowmane:260 level:5:3860:lardpaw:300 results 2>/dev/null | grep -c saved
names=(menu:01_main_menu level0_punk,punk,brawler:02_alley_trouble level1_runner,thrower,punk,punk:03_market_mayhem
	level2_thrower,runner,punk:04_neon_boulevard level2_slick:05_boss_slick_whiskers
	level3_enforcer,brawler,punk:06_industrial_paws level3_bruno:07_boss_big_bruno
	level4_snowmane:08_boss_general_snowmane level5_lardpaw:09_final_boss_lord_lardpaw results:10_street_results)
rm -f "$SHOTS"/*.png
for n in "${names[@]}"; do cp "$TMP/${n%%:*}.png" "$SHOTS/${n##*:}.png"; done

art() { xvfb-run -a -s "-screen 0 3900x2200x24" "$GODOT" --path . -s res://tools/store_art.gd -- "$1" "$PWD/$2" "${@:3}" 2>/dev/null | grep saved; }
art key $ART/hero_3840x2160.png 3840 2160
art key $ART/boxart_2160x2160.png 2160 2160
art key $ART/poster_1440x2160.png 1440 2160
art banner $ASSETS/Wide310x150Logo.png 620 300
art banner $ASSETS/SplashScreen.png 1240 600
"$GODOT" --headless --path . -s res://tools/make_msix_assets.gd | grep asset
