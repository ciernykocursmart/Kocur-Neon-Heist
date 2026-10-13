# Kocur Tactics - Test Report

Generated from actual runs on 2026-10-13 (v1.0.1) in a Linux container (Godot 4.3.stable, headless).
No Windows machine was available: the Windows build was exported and its packed content was
run with the Linux engine binary (see "Windows build"). Human KX testing is **PENDING**
(see `KX_TEST_CHECKLIST.md`).

```
RESULT: 98 tests, 98 passed, 0 failed, 1624 assertions, 21.0 s
RESTART WRITE: PASS
RESTART VERIFY: PASS
SMOKE RESULT: PASS            (exported pack, 83 checks)
SMOKE RESTART RESULT: PASS    (exported pack, second process, 4 checks)
```

## How to reproduce

```bash
cd kocur-tactics
tools/run_tests.sh                 # all suites + the two-process restart check (about 30 s)
tools/run_tests.sh combat ui       # selected suites
godot --headless --path . -s res://tests/sim.gd [ids] [--diff=hard] [--verbose]   # AI autoplay
tools/build_windows.sh             # export, ZIP, smoke test of the exported pack (2 processes)
```

`tools/run_tests.sh` fails if any assertion fails, if Godot printed a `SCRIPT ERROR`, if the runner
did not reach its summary line, or if the restart check failed. Tests use their own save and settings
files, so a real save is never touched.

## Results per suite

| Suite | Tests | Assertions | What it verifies |
|---|---|---|---|
| grid | 7 | 98 | Map parsing, bounds, terrain costs/defence/range; line of sight (walls block, water/forest do not, symmetric, corner rules); reachable tiles respect MOV, terrain costs and walls; every displayed path is orthogonal, walkable and within MOV; occupancy (cannot end on allies/enemies, can pass allies, enemies block corridors, no moves outside the map); the animated path equals the displayed path; A* finds a 17-cell zig-zag and returns nothing into walls; Stalker ignores terrain cost; chill -2 MOV with a minimum of 1. |
| combat | 14 | 69 | Exact damage (ATK-DEF), forest cover, minimum 1, Protective Stance +3 and +2 aura, flanking for both sides, Aimed Shot range 2-5 / minimum range / walls block / water does not / Steady +2 lost after moving / hill +1 range, Heavy Strike only without moving, Shield Wall, Ambush vs isolated, Volley plus-shape hits only enemies with cooldown, Shadow Pounce range, landing, damage, cooldown, no pounce through walls, reposition; heal targets and cap; invalid targets rejected without using the action; KO removes the unit, emits the event and credits the kill; Exhausted DEF 0; King immune behind pylons; hazard damage; identical inputs give identical battles. |
| turns | 19 | 87 | Move then act once, no second move/act/wait, undo before acting, act-without-move then no move, enemy phase only on End Turn and full reset after it, enemy order (caster, ranged, guard, melee, flanker), cooldown and status durations, threat tiles, turn-limit defeat (and no turns after the end), survive victory, defend overrun defeat, eliminate victory and all-heroes-down defeat, rescue + escape, relic claiming, escape objective, alert/wake of dormant groups, reinforcements announced then spawned, optional objectives and battle summary, no commands for enemies or after the battle ended. |
| ai | 10 | 39 | Every enemy in 4 real missions plans a reachable destination and a valid target; melee attacks a reachable hero; AI prefers the kill; archer steps away from an adjacent hero and shoots; mage heals a badly hurt ally; guard stays near its archer; stalker goes for the isolated ranger; dormant enemies stay put; no target -> no attack, still a legal move; 3 enemy phases of M09 finish in 116 ms (no loops). |
| bosses | 9 | 37 | Ironpaw declares Crushing Blow on 3 tiles including the target, it lands next enemy phase, stepping out avoids all damage, Exhausted = DEF 0, ignoring it deals ATK+6-DEF, Iron Guard (+3 DEF, 2 guards) only once, defeating him wins; Pale King: move 0 in phase 1, immune until both pylons fall, phase 2 at half HP (move 3, 2 stalkers), Royal Lance telegraph covers the heroes' line and hits next turn, Pale Nova (max 3x3) then Drained (DEF 0), defeating him wins; a KO'd boss's telegraph is removed. |
| missions | 6 | 746 | 12 missions in 3 acts of 4, 3 challenges, 10 distinct objective types used in the campaign; every map has equal row widths, known objective/optional types, registered music, enough deployment tiles, units on walkable tiles, exits/shrines/relics/cages/objective units present, one cage per captive, valid reinforcement tiles; every enemy, objective tile and cage is reachable from deployment; **the AI wins all 15 missions on Normal** and 5 key missions on Story; Hard enemies have more HP/ATK, Story less. |
| progression | 12 | 99 | Unlock chain (defeat unlocks nothing), XP formula and level-ups, no duplicate rewards on replay (XP, shards, recruits), new optional objectives pay once, medals never decrease, recruits join once, upgrades (costs, ranks, max rank, not for unrecruited heroes, carried into battle), challenge squads fixed and no shards, campaign complete after M12, save roundtrip and version field, malformed saves (bad JSON is quarantined, wrong types, negative/huge values, unknown ids, duplicates, newer version, empty file), New Campaign and Reset, difficulty persistence, settings persistence and sanitizing. |
| ui | 11 | 76 | Main menu buttons and disabled states, New Campaign -> difficulty -> campaign screen, New Campaign/Reset confirmations (cancel keeps progress), settings and credits windows; all 5 campaign tabs, squad add/remove, upgrade purchase; battle briefing blocks input, click selects, click moves, right click undoes, attack preselected, first click aims with preview and no damage, second click attacks; End Turn confirmation then enemy phase; pause menu with all 6 entries, restart with confirmation returns to turn 1; a full battle through the scene -> victory screen -> rewards recorded once -> Continue returns to the campaign; Tab / T / Esc shortcuts; ending scene. |
| integrity | 9 | 341 | Sprite sheets for every class/enemy (2 frames of 16x16), tiles for every terrain in every region, markers, icons for every hero ability and status, every SFX and music file, every sound name used in code exists, all 4 scenes load, project settings (name, main scene, 1280x720, canvas_items stretch, autoloads), Windows export preset (x86_64, embedded pck, tests excluded), no networking APIs in any script. |
| restart (2 processes) | - | 11 | Process 1 plays M01 with the AI through the campaign API, buys an upgrade, changes settings, exits. Process 2 loads everything back (difficulty, completion, unlock, shards, XP, medal, upgrade, music volume, speed) and a replay gives no duplicate reward. |

## AI autoplay (heroes controlled by the same utility AI, Normal)

The default squad at level `1 + mission_index / 2`, no upgrades:

| Mission | Result | Turns | KOs | | Mission | Result | Turns | KOs |
|---|---|---|---|---|---|---|---|---|
| m01 | victory | 5 | 0 | | m09 | victory | 7 | 1 |
| m02 | victory | 8 | 1 | | m10 | victory | 15 (limit 15) | 0 |
| m03 | victory | 8 | 0 | | m11 | victory | 14 (limit 18) | 1 |
| m04 | victory | 6 | 0 | | m12 | victory | 9 | 2 |
| m05 | victory | 8 (limit 12) | 2 | | c1 | victory | 6 (limit 8) | 0 |
| m06 | victory | 6 | 0 | | c2 | victory | 6 | 0 |
| m07 | victory | 7 | 1 | | c3 | victory | 8 (limit 12) | 2 |
| m08 | victory | 8 | 0 | | | | | |

Also on Hard: m03 victory in 10 turns, m08 victory in 5 turns. This proves every mission can be won
under the real rules; it does not prove the difficulty feels right to a human (KX areas 13 and 16).

## Windows build

`tools/build_windows.sh` exported `build/windows/KocurTactics.exe` with the official 4.3.stable
template (`PE32+ executable (GUI) x86-64, for MS Windows`, 95.9 MB, pck embedded) and packed
`KocurTactics-windows-x86_64.zip` (41.0 MB: exe, README.txt, LICENSE_GODOT.txt).

The smoke test (`tools/pack_smoke.gd`) loads **the pack embedded in the .exe** with the Linux engine
binary, outside the editor and without the project folder:

- the pack is Kocur Tactics; tests and tools are not shipped; all 5 autoloads and all 36 sounds exist;
- main menu, campaign and ending scenes run;
- all 15 battles build from the pack and play one AI turn each;
- a fresh campaign plays **M01 to victory through the real battle scene**, shows the victory screen,
  Continue returns to the campaign, M01 is completed and M02 unlocked, the save is on disk;
- a **second process** loads that save back (campaign started, M01 completed, M02 unlocked, shards kept).

The exported pack was also started windowed under Xvfb (OpenGL 3.3 Compatibility via Mesa llvmpipe) for
600 frames without script errors.

**Not verified:** starting `KocurTactics.exe` on real Windows (no Windows or Wine available), real GPU
performance, audio output (the container has no sound device), real mouse feel. These are KX areas 1, 14, 17.

## Known failures and warnings

- No failing tests.
- At process exit Godot prints `ObjectDB instances leaked at exit` / `resources still in use at exit`.
  These come from static texture/theme caches in `ui_kit.gd` that live until shutdown; they are harmless
  and do not occur during play.
- In the container, audio falls back to the dummy driver (no sound card), so sound playback is untested
  beyond "every file exists, loads and every referenced name is registered".
