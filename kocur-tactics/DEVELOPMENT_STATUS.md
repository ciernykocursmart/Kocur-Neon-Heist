# Kocur Tactics - Development Status

Last updated: 2026-10-13. Version 1.0.1 (certification fix: mouse clicks on the battle board). Branch `claude/kocur-tactics-jkbsjx`.

## Milestones

| Milestone | State |
|---|---|
| A - Inspect and establish (Godot 4.3, templates, repo) | Done |
| B - Tactical foundation (grid, movement, combat, turns, AI, first mission) | Done |
| C - Campaign content (classes, 5 enemies, 12 missions, 2 bosses, objective variety) | Done |
| D - Progression (roster, XP, upgrades, rescues, optionals, saves, mission select) | Done |
| E - Presentation (UI, audio, visuals, result screens, settings, challenges) | Done |
| F - Test and release (98 tests, Windows export, smoke test, docs) | Done in the container; **human KX testing pending** |

## Quality gates

| Gate | State | Evidence |
|---|---|---|
| 1 Movement, combat, turns, action limits | Passing | test_grid, test_combat, test_turns |
| 2 Hero classes and enemy archetypes | Passing | test_combat, test_ai |
| 3 12 missions playable with victory/defeat | Passing (automated) | test_missions: validation + AI wins all 15 |
| 4 Both bosses work and are beatable | Passing (automated) | test_bosses, autoplay m06/m12/c3 |
| 5 Progression, optionals, upgrades, saves | Passing | test_progression, restart check |
| 6 Menus, UI, settings, audio, transitions | Passing (automated); audio output not heard | test_ui, test_integrity |
| 7 Windows x64 build exists and tested | Built; pack tested on Linux; not run on Windows | build_windows.sh + pack_smoke |
| 8 Genuine automated QA, KX pending | Yes | TEST_REPORT.md, KX_TEST_CHECKLIST.md (109 rows PENDING) |

## Known issues and risks

- **Not run on real Windows.** The .exe was exported with the official template and its content was run on
  Linux, but nobody has double-clicked it on Windows yet (KX 1.1).
- **Difficulty feel is unverified by humans.** The AI can win every mission, but M10 was won on the last
  allowed turn (15/15) and M11 at 14/18; a human might find those clocks tight or loose. Hard mode was
  only autoplayed on M03 and M08.
- Campaign length (target 2-4 hours) is an estimate from turn counts, not measured.
- Audio was never heard (no sound device in the container). Volume balance between tracks needs KX.
- Performance was measured only with a software renderer (llvmpipe); real GPUs should be far faster.
- Saves happen at safe points only: quitting mid-battle loses that battle (by design, documented).
- The exe has the default Godot file icon (no rcedit in the container); the window icon is the game's cat icon.
- Harmless "leaked at exit" engine warnings come from static UI caches at shutdown.

## Next concrete steps

1. KX playtest on Windows following `KX_TEST_CHECKLIST.md` (order given there).
2. Tune turn limits / enemy counts for any mission KX marks unfair (data only: `scripts/data/missions.gd`).
3. Optional: set an .ico on the exe (`application/icon` in `export_presets.cfg`, needs rcedit on Windows).

## Continuation point

Everything is committed. To continue: `cd kocur-tactics && tools/run_tests.sh` (should print
`RESULT: 98 tests, 98 passed`), then `tools/build_windows.sh` to rebuild the ZIP.
