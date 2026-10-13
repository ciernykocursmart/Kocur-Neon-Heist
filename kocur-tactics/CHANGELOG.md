# Changelog

## 1.0.1 - 2026-10-13

Fix for the Microsoft Store certification report ("Click to select, Click to inspect,
Click to aim and Move here are unusable" during battle).

- Fixed: mouse clicks on the battle board were ignored. The full-screen battle root
  `Control` used the default `MOUSE_FILTER_STOP`, so the GUI pass swallowed every click
  before `_unhandled_input` could turn it into a command. It now uses `MOUSE_FILTER_IGNORE`.
- Board clicks now use the click event's own position instead of polling the mouse,
  so they land on the right tile at any window size, letterboxing or display scaling.
- New test `test_real_mouse_clicks_reach_the_board` drives real mouse events through the
  viewport at 1280x720, 1366x768, 1920x1080 and 2560x1600 (select, inspect, move, aim, confirm).
  The older tests called `click_cell()` directly, which is why they missed this.
- Version 1.0.1 (MSIX 1.0.1.0).

## Unreleased - Microsoft Store kit (2026-10-12)
- Unsigned MSIX package (`tools/build_msix.sh`) with identity `59513Lukes.KocurTactics`, publisher Kocur.
- Store logos, key art (hero, box, poster) and 10 screenshots of the real game (`tools/store_shots.sh`).
- `store/STORE_LISTING.md` (English + Slovak listing texts) and `store/NAVOD_PUBLIKOVANIE_SK.md`.
- `store/*` is excluded from the Windows export; the game itself is unchanged.

## 1.0.0 - 2026-10-12

First complete release candidate, waiting for KX playtesting.

### Game
- Grid tactics engine: terrain costs, Dijkstra movement fields, A* paths, supercover line of sight,
  move-then-act turns with undo, deterministic damage with exact previews, flanking, cover, threat display.
- 3 hero classes (Shadowblade, Guardian, Ranger) plus the Mender support class; 6 named heroes (3 rescued during the campaign).
- 5 White Crown enemy archetypes (Recruit, Guard, Archer, Mage, Stalker) driven by a utility-scoring AI with
  per-archetype profiles; sleeping groups with alert radius; announced reinforcements.
- 2 bosses: Ironpaw Commander (telegraphed Crushing Blow, Exhausted window, Iron Guard) and the Pale King
  (pylon shield, Royal Lance, summons, phase 2 with Pale Nova and Drained window).
- 12 missions in 3 acts with 10 objective types (eliminate, rescue + escape, defend, escape, boss, protect,
  commander, survive, escort, claim), 24 optional objectives, medals, 3 tactical challenges.
- Progression: XP and levels, Relic Shards, 5 upgrades per hero including a class mastery, recruits,
  records, campaign ending. Story / Normal / Hard difficulty.
- Full UI: main menu, campaign screen (missions + squad select, roster, upgrades, challenges, records),
  battle HUD (objectives, unit and tile info, log, preview line, action bar), briefing, pause menu,
  result screen, settings (volumes, fullscreen, window size, animation speed, difficulty), controls & rules.
- Original generated pixel art (77 sprites, 3 regional tile sets) and audio (36 sound effects, 8 music tracks).
- Versioned, atomic local save with corrupt-save quarantine and sanitizing; settings file.

### Tooling
- 97 automated headless tests in 9 suites, a two-process restart persistence check, AI autoplay of
  every mission, screenshot tool, Windows export script with a two-process smoke test of the exported pack.

### Balance changes made from autoplay results
- Elder HP 18/DEF 1, Stalker ATK 5, Ironpaw HP 52, Pale King HP 70, Moonwell 30 HP/DEF 2.
- M05 reinforcements adjusted, M07 reinforcement reduced, M10 alert 0 with one archer removed,
  M11 turn limit 18, challenge 1 turn limit 8.

### Fixes found by the tests
- Battle briefing and HUD now draw above the map (CanvasLayers).
- The damage preview stays visible when a target is aimed while the mouse is off the map (keyboard flow).
