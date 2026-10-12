# Changelog

## 1.0.0 - 2026-10-12

First complete version.

### Game
- 16 levels: 5 regions x 3 levels (Mossroot Catacombs, Emberpaw Mines, Frostfang Crypt,
  Shadowclaw Depths, Pale King's Citadel) and the final encounter; 1-1 is a tutorial.
- Player: run with acceleration, variable jump, coyote time, jump buffer, claw attack,
  directional pounce (with upward variant), drop-through platforms, half-heart health,
  shields, i-frames, knockback, hazards that return the cat to safe ground.
- 5 enemy archetypes (Scout, Guard, Archer, Mage, Beast) with telegraphed attacks.
- 5 guardians: Iron Mouser, Ember Guardian, Frost Matron, Shadow Stalker and the
  three-phase Pale King.
- Level objects: checkpoint lanterns, exit doors, levers and gates, crumbling blocks,
  moving lifts, flame jets, saws, icicles, springs, torches, fake walls, secret zones,
  chests, cages, rising pale fire.
- Coins, Shadow Gems, fish, relics, secrets, 10 rescuable cats with permanent perks,
  7 permanent upgrades, 8 temporary blessings, 4 optional challenges per level.
- Camp hub: level select with medals, upgrade shop, cats, records, settings.
- Main menu with story intro, credits, settings (volumes, fullscreen, window size,
  difficulty Assist/Normal/Hard, screen shake, controls page, reset progress).
- Pause menu, HUD, death screen with tips, results screen, ending with statistics.
- Original procedural pixel art, animations, parallax backgrounds, particles, lighting,
  pixel font, 38 sound effects and 10 music tracks.
- Versioned save in user:// with safe loading of missing or damaged files.

### Tooling
- Level DSL (tools/build_maps.py) and a physics-based reachability validator
  (tests/level_reach.gd) that proves every level is traversable.
- 82 automated tests (tools/run_tests.sh), Windows x64 export preset, build + ZIP script
  and a smoke test of the exported pack (tools/build_windows.sh).

### Fixed during testing
- Music for regions 3 and 4 did not loop when it was the first track loaded (loop now
  set at import as well as at runtime).
- Level signs could show the wrong text (texts are now assigned left to right).
- Lever gates: each lever opens its nearest gate in the validator too.
- Several level layouts had 4-tile climbs that the cat cannot jump; all fixed to the
  validator's limits.
- Main menu and ending panels were drawn in the corner instead of centred.
