# Kocur Purrzzle v1.0.2 - QA report

All results below come from real runs in this build environment (Godot 4.3 stable, Linux, headless unless noted).

## Automated results
| Check | Command | Result |
|---|---|---|
| Unit tests (rules, mechanics, undo, stars, save, level data, UI flow) | `godot --headless --path . -s res://tests/test_suite.gd` | **389 passed, 0 failed** |
| UI playthrough: every level solved through the real UI input path, progress saved | `tests/smoke.gd` | **30/30 levels won, 90/90 stars, 0 fails**; all screens build |
| Real keyboard bot: key press/release events through Godot's input system (Xvfb window), every level's solution tapped 1, 2, 3 and 6 frames apart, plus hold-to-walk both ways and direction switching | `tests/keybot.gd` | **30/30 levels won at every tap speed; hold/switch PASS** (v1.0.0 failed: 18/30 at 6 frames, 1/30 at 2 frames) |
| Drawn position = logical position: screenshot pixel check of where the cat is drawn vs. its grid tile, after every step of every level (real key taps) and after left/right/down/up moves | `tests/keybot.gd -- 2 draw`, `tests/facing_shot.gd` | **0 mismatches in 423 step checks, 0 wall entries; facing check PASS** (v1.0.1 drew a left-facing cat one tile too far right) |
| Dead-end scan: every reachable state of each level, checking that only crate deadlocks (fixable with undo) can block the exit, never the cat itself | `tests/deadends.gd` | no cat-only traps in any level that fits the scan (28 of 30; L5 and L30 exceed its 150k state cap but are solver-verified) |
| Save persistence across two separate processes | `tests/persist_check.sh` | **PASS** |
| Solvability of all levels (BFS over the real game rules) | `tests/solve_all.gd` | **30/30 solvable, 0 unsolvable**; shortest solution (par) and shortest solution with all fish stored in `scripts/pars.json` |
| Windows export + exported pack boot | `tools/build_windows.sh`, then `godot --headless --main-pack KocurPurrzzle.exe --quit-after 90` | exe + zip produced; pack loads and runs 90 frames with no errors |

What the unit tests cover: grid bounds and walls, movement, valid/invalid pushes, multiple crates, targets and exit, plates/doors, keys/locks, ice (player and crates), teleport pads (incl. blocked twin, no bounce), timed gates and waiting, undo and restart, undo property test (150 random moves then full undo restores the exact state on all 30 levels), stuck-crate warning, star rules, par/target sanity for all levels, level data validity (1 start, 1 exit, pad twins, hints), save/load/corrupt/missing/partial/wrong-type save files, unlock progression, best-score keeping, rapid level switching, pause blocking input, victory screen and unlock via the UI.

## Level verification method
Every level is solved by an exhaustive breadth-first search using the same `Puzzle` class as the game, so a level can only be "solvable" if the real rules allow it. The stored shortest solution is replayed by the tests (`par` equals its length) and by the UI playthrough. A second search requires collecting every fish, so 3 stars are reachable on every level (the move target is always at least 1.25x that route).

Level layouts: all 30 were designed by hand. For the five ice-field levels (14, 16, 18, 27, 29) the hand-drawn room frame (start, exit, crate, target, plates) was fixed and the positions of the ice rocks were chosen with solver assistance (random candidates kept only if the shortest solution was long enough); the chosen layouts are fixed data in `levels.gd`, not generated at runtime.

| # | Region | Level | Par (min moves) | Par with all fish |
|---|---|---|---|---|
| 1 | Sunny Garden | First Steps | 7 | 11 |
| 2 | Sunny Garden | Push It | 12 | 12 |
| 3 | Sunny Garden | Two Crates | 13 | 17 |
| 4 | Sunny Garden | Around the Bend | 15 | 21 |
| 5 | Sunny Garden | Garden Gate | 34 | 34 |
| 6 | Sunny Garden | Sunflower Maze | 54 | 56 |
| 7 | Moonlit Ruins | Pressure Plate | 10 | 12 |
| 8 | Moonlit Ruins | Key and Lock | 9 | 23 |
| 9 | Moonlit Ruins | Both Plates | 14 | 14 |
| 10 | Moonlit Ruins | Plate, Then Key | 12 | 16 |
| 11 | Moonlit Ruins | Key Ring | 9 | 15 |
| 12 | Moonlit Ruins | Ruins Reckoning | 33 | 33 |
| 13 | Frozen Fishpond | Slippery Start | 7 | 8 |
| 14 | Frozen Fishpond | Cold Corners | 13 | 13 |
| 15 | Frozen Fishpond | Frozen Crate | 8 | 12 |
| 16 | Frozen Fishpond | Rink Rules | 17 | 17 |
| 17 | Frozen Fishpond | Chilly Switch | 8 | 11 |
| 18 | Frozen Fishpond | Thin Ice Fishing | 15 | 15 |
| 19 | Crystal Catacombs | Warp Pads | 5 | 11 |
| 20 | Crystal Catacombs | Past the Wall | 10 | 16 |
| 21 | Crystal Catacombs | Two Pairs | 6 | 10 |
| 22 | Crystal Catacombs | Blink Gates | 11 | 11 |
| 23 | Crystal Catacombs | Pulse Corridor | 11 | 15 |
| 24 | Crystal Catacombs | Crystal Crossing | 13 | 17 |
| 25 | Purrfect Temple | Temple Gate | 12 | 12 |
| 26 | Purrfect Temple | Plate Relay | 16 | 16 |
| 27 | Purrfect Temple | Icy Altar | 14 | 14 |
| 28 | Purrfect Temple | Warp Vault | 10 | 10 |
| 29 | Purrfect Temple | Rhythm of Ice | 25 | 25 |
| 30 | Purrfect Temple | Purrfect Finale | 30 | 30 |

## Not tested / limits
- The Windows exe was **not run on real Windows** (built on Linux). Rendering was checked with the Linux build under Xvfb screenshots only (`screenshots/`).
- Audio is procedural and was never heard by a human; volume balance, loudness and the music loop are unverified. No audio output device was available.
- Frame rate on real hardware, window/fullscreen switching, key repeat feel and mouse controls were not tested by a human. See `KX_TEST_CHECKLIST.md`.
- Difficulty/fun of the levels is judged by solver numbers (min moves), not by human playtesting. Levels 8, 11, 19, 21, 28 are short (par <= 10).
- Stuck-crate warning only detects wall-corner/dead-end crates; other unwinnable states are not detected (by design).
