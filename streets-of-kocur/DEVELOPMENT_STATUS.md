# Development Status

Last update: 2026-10-13, version 1.0.0.

## Milestones

| Milestone | State |
|---|---|
| A - Inspect environment (Godot 4.3, export templates, repo) | done |
| B - Combat foundation (movement, depth, combo, enemies, damage) | done |
| C - Full campaign (6 streets, 5 enemy types, food, 3 mini-bosses, final boss) | done |
| D - Player experience (menus, HUD, audio, settings, saves, level select, results, ending) | done |
| E - QA and release (tests, fixes, Windows export, docs) | done; NEO played the full game on Windows and reported it perfect |
| F - Microsoft Store kit (.msix, listing, art, screenshots, exe icon) | done; .msix not installed on Windows yet |

## Completion gates

| Gate | State | Evidence |
|---|---|---|
| 1 Movement and combo combat | met (automated) | test_player, test_combat |
| 2 Five enemy archetypes | met (automated) | test_combat, bot runs |
| 3 Six playable levels with completion conditions | met (automated) | test_campaign clears all 6 |
| 4 Food, health, special, score | met (automated) | test_food, test_player |
| 5 Mini-bosses and final boss beatable | met by the bot | test_campaign, sims |
| 6 Menus, settings, saves, progression, ending | met (automated) | test_save_ui, restart_check |
| 7 Windows x64 build exists and tested as far as possible | build exists; exported pack smoke-tested on Linux; **.exe not run on Windows** | TEST_REPORT section 3 |
| 8 Genuine automated QA, KX marked pending | met | TEST_REPORT, KX_TEST_CHECKLIST (96 PENDING) |

## Known issues

* Campaign length is probably below the 45-90 minute target (bot: about 14 min
  of game time on Normal; human estimate 30-50 min, unmeasured).
* Hard: the test bot loses at Big Bruno; human balance unknown.
* The KX checklist rows were not filled in one by one; NEO's full playthrough on
  Windows (2026-10-13) is the human result.
* The .msix was not installed on Windows here and WACK was not run.

## Next steps

1. KX: run `KX_TEST_CHECKLIST.md` on a real Windows 10/11 PC, in the order given
   in FINAL_REPORT.md, and record FPS and real playtime per street.
2. If playtime is short: add one encounter per street in `scripts/data/levels.gd`
   (encounters are data only) and re-run `tools/run_tests.sh` and
   `tests/sim.gd -- all normal`.
3. Tune from KX feedback in `scripts/data/balance.gd` (all damage, health,
   speed and difficulty numbers live there).
4. Rebuild with `tools/build_windows.sh`, then `tools/build_msix.sh <makemsix>`.
5. Store: follow `store/NAVOD_PUBLIKOVANIE_SK.md` (Partner Center submission).
