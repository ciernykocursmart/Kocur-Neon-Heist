# Streets of Kocur - Test Report

Version 1.0.0, 2026-10-13. Every number below comes from a real run in this
environment; nothing was estimated unless it says so.

## Environment

* Linux x86_64 cloud container, **no Windows machine, no GPU, no sound card**.
* Godot 4.3.stable.official (77dcf97d8), Windows export templates 4.3.stable.
* Tests run headless (`--headless`); screenshots rendered under Xvfb.

## 1. Automated test suite

Command: `tools/run_tests.sh` (exit code 0). Runner: `tests/run_tests.gd`, suites in
`tests/suites/`. Each test gets a clean save, settings and run state. The shell
wrapper also fails the run if Godot prints any `SCRIPT ERROR` (a script error
aborts a GDScript test silently, so the log is checked as well).

**Result: 66 tests, 66 passed, 0 failed, 928 assertions, 12.7 s.**

| Suite | Tests | Assertions | Result |
|---|---|---|---|
| test_campaign | 12 | 76 | all PASS |
| test_combat | 14 | 77 | all PASS |
| test_food | 9 | 39 | all PASS |
| test_integrity | 6 | 560 | all PASS |
| test_player | 13 | 68 | all PASS |
| test_save_ui | 12 | 108 | all PASS |
| **Total** | **66** | **928** | **66 / 66 PASS** |

**test_campaign**: `clear_street_1` (7), `clear_street_2` (7), `clear_street_3` (8), `clear_street_4` (8), `clear_street_5` (8), `clear_street_6_final_boss_and_ending` (10), `street_without_god_mode` (1), `encounter_triggers_only_when_reached` (8), `next_street_transition` (5), `restart_does_not_duplicate_enemies` (5), `continue_keeps_checkpoint_and_lives` (5), `results_compute_once` (4)

**test_combat**: `depth_aware_targeting` (3), `overlap_math` (7), `one_hit_per_activation` (2), `full_combo_damage_and_knockdown` (3), `enemies_approach_and_attack` (3), `attack_tokens_limit_attackers` (11), `cooldown_between_attacks` (2), `dead_enemies_stop` (5), `waves_progress_and_cap` (24), `thrower_projectile_and_jump_dodge` (3), `enforcer_armor` (5), `runner_and_brawler_behaviour` (3), `anti_stunlock` (2), `boss_has_phases_and_telegraphs` (4)

**test_food**: `food_heal_amounts` (7), `heal_capped_at_max` (3), `no_double_collect` (3), `pickup_needs_contact` (1), `golden_fish_and_yarn` (4), `level_food_collected_once_after_restart` (4), `prop_breaks_and_drops_once` (8), `extra_life_threshold` (3), `food_budget_per_street` (6)

**test_integrity**: `main_scene_loads` (10), `all_scripts_load` (39), `scenes_instantiate` (6), `audio_resources` (54), `level_data_valid` (441), `every_archetype_spawns` (10)

**test_player**: `moves_both_axes` (6), `acceleration_and_stop` (4), `jump_and_land` (4), `combo_progression_and_reset` (8), `special_uses_energy` (5), `special_hits_many` (5), `damage_and_invulnerability` (6), `knockback_and_recovery` (4), `death_respawn_restores_control` (6), `last_life_game_over_and_continue` (6), `grab_knee_throw` (8), `grab_times_out` (2), `jump_kick_and_pounce` (4)

**test_save_ui**: `save_round_trip` (6), `malformed_save_falls_back` (3), `hand_edited_save_is_clamped` (7), `unlocks_and_replay` (8), `continue_campaign_resumes_run` (5), `reset_progress` (3), `settings_persist` (7), `input_actions_registered` (30), `main_menu_buttons` (20), `pause_and_resume` (12), `pause_main_menu_confirm` (3), `hud_reflects_state` (4)

What the suites cover (the spec's list, section 17):

* **Integrity** - main scene and its 8 buttons, all 38 scripts compile, the 3 scenes
  instantiate, all 39 sound effects and 9 music loops load, level data is valid
  (6 levels, spacing, enemy kinds, one Golden Fish per street, healing limited,
  obstacles leave a path), every enemy and boss spawns.
* **Player** - both axes and street edges, acceleration/stop, jump and landing,
  combo jab -> swipe -> finisher, no 4th hit, late press restarts the combo,
  special costs 50 energy / refused when low / hits a crowd / invulnerable spin,
  damage and invulnerability, knockback and get-up, death -> respawn with control,
  last life -> game over -> Continue reloads with lives refilled, grab / knee /
  throw / grab timeout / enforcer not grabbable, flying kick, pounce.
* **Combat** - depth-aware targeting (same line hit, 60 px deeper not hit, behind
  not hit), overlap maths, one hit per attack activation, the full combo deals
  exactly 6+8+14 and knocks down, enemies walk up and hit an idle player, token
  limit (max 2 attackers on Normal), cooldown between attacks, dead enemies never
  attack and score once, waves (cap 5 alive, every scripted enemy spawned once,
  checkpoint advances, cleared fight never restarts), thrower bottle dodged by a
  jump but hits a standing player, enforcer armor, runner lunge, brawler poise,
  anti stun-lock, Lardpaw uses 3 different telegraphed attacks and changes phase
  at 66% and 33%.
* **Food** - heal amounts 20/40/70, cap at max, points at full health, no double
  collect, contact needed, golden fish and yarn, eaten food not respawned after a
  continue reload, prop breaks and drops exactly once and stays broken after
  reloads, extra life at 40,000, healing budget per street.
* **Campaign** - each of the 6 streets played start to finish by the autoplay bot
  in god mode through the real level scene (every encounter cleared, no enemies
  left, boss defeated, results screen, completion + unlock recorded), Street 6 ->
  "See the ending" -> ending scene, Street 1 beaten on Normal **without** god mode,
  encounter starts only when reached and the arena holds the player, Next street
  transition saves the run, restart does not duplicate enemies, continue keeps
  the checkpoint, results/bonuses computed once.
* **Save / UI** - save round trip, malformed save, hand-edited save clamped,
  unlocks and replay (no duplicate unlock, best kept), Continue resumes the run,
  reset, settings persist and are applied to the audio buses, all 10 input actions
  have keyboard and gamepad bindings, main menu buttons (Settings / Controls /
  Credits windows, New Game -> difficulty -> Street 1, Continue enabled after a run,
  Level Select unlocks), pause / settings in pause / resume, pause -> main menu
  with confirmation, HUD health bar and boss bar.

Bot clear times from the campaign suite (god mode, sim time): Street 1 80 s,
Street 2 104 s, Street 3 111 s, Street 4 120 s, Street 5 151 s, Street 6 127 s.

## 2. Save persistence across a real restart

`tests/restart_check.gd` runs as **two separate Godot processes**: `write` starts a
Hard campaign, the bot clears Street 1 through the real level scene and settings
are changed; `verify` is a new process that loads everything from disk.
**Result: RESTART WRITE PASS, RESTART VERIFY PASS (12/12 checks)** - difficulty,
completion, unlock, best score 17057, best rank, run position, run score, music
volume, screen shake, Continue resumes Street 2, replay after restart gives no
duplicate unlock.

## 3. Windows export

`tools/build_windows.sh` exported `build/windows/StreetsOfKocur.exe`
(95,552,112 bytes, PCK embedded, x86_64, Kocur file icon and version info) and
`build/windows/StreetsOfKocur-windows-x86_64.zip` (40,591,453 bytes; SHA-256
`068bfa2de9a742ac82cdaace0e01c9bc8742ea95baa1930aebed15e17bcd5345`), containing
`StreetsOfKocur/StreetsOfKocur.exe`, `README.txt`, `LICENSE_GODOT.txt`.

**The .exe was NOT run** - there is no Windows here. Instead the *exported game
data* embedded in the .exe was loaded with the Linux Godot binary
(`--main-pack StreetsOfKocur.exe`, from an empty directory) and exercised by
`tools/pack_smoke.gd`:

**SMOKE RESULT: PASS (72/72 checks) and SMOKE RESTART RESULT: PASS (5/5)**

* the pack is Streets of Kocur; tests and tools are not shipped; 5 autoloads present
* all 39 sound effects and 9 music loops load from the pack
* main menu and ending scenes run; all 6 streets load
* a **combat encounter** (Street 1, fight 1) completed by the bot through the
  exported level scene in 12 s sim time, 3 enemies defeated
* **food pickup + health change**: chicken healed 30 -> 70
* Street 1 cleared, **level transition** via "Next street" loaded Street 2
* **save persistence**: a second process loaded the save (street 1 completed,
  street 2 unlocked, best score kept, Continue points at street 2)

This proves the exported content is complete and runs; it does not prove the
Windows executable starts, renders or plays sound on a real Windows PC.

**Exe icon (store kit build):** the release template is patched before export
(`tools/patch_windows_exe.mjs`, resedit) with `icon.ico` (16-256 px) and version
strings. Checked in the built .exe: the icon group has 7 entries matching
`icon.ico`, ProductName "Streets of Kocur", CompanyName "Kocur Studios", version
1.0.0.0. The smoke test above was re-run on this build: PASS 72/72, restart PASS 5/5.

**MSIX:** `tools/build_msix.sh` packs the same .exe into
`build/msix/StreetsOfKocur_1.0.0.0_x64.msix` (unsigned; Partner Center signs it).
Checked: the package lists AppxManifest.xml, AppxBlockMap.xml, the .exe and 7
logos, and the manifest parses with identity `59513Lukes.StreetsOfKocur`. The
.msix was not installed on Windows and the Windows App Certification Kit was not run.

**Human test on Windows:** NEO played the whole campaign on Windows on 2026-10-13 and reported it as perfect; the individual checklist rows were not filled in.

## 4. Balance runs (autoplay bot, no god mode)

`tests/sim.gd -- all <difficulty>`: the bot plays the whole campaign, carrying
score and lives from street to street, using continues when it gets a game over.
The bot is simple (walks in, mashes the combo, uses PAWQUAKE in crowds, dodges
boss telegraphs and projectiles, eats food when hurt; it never grabs, blocks or
plays smart), so it is a floor, not a human player.

| Street | Easy | Normal | Hard |
|---|---|---|---|
| 1 | clear, 0 lives lost, rank S, 60 s | clear, 0 lost, S, 79 s | clear, 0 lost, S, 82 s |
| 2 | clear, 0 lost, S, 86 s | clear, 0 lost, S, 103 s | clear, 0 lost, A, 123 s |
| 3 | clear, 0 lost, A, 101 s | clear, 1 lost, C, 115 s | clear, 1 continue, D, 178 s |
| 4 | clear, 0 lost, A, 118 s | clear, 2 lost, D, 138 s | **game over** at Bruno (both continues used) |
| 5 | clear, 1 lost, C, 156 s | clear, 1 continue, D, 197 s | clear, 2 continues, D, 253 s |
| 6 | clear, 0 lost, A, 129 s | clear, 1 continue, D, 223 s | clear, 2 continues, D, 251 s |

Normal: the bot finishes the campaign with 2 continues used in total. Hard was
tuned once after the first run (enemy damage 140% -> 130%, continues 1 -> 2);
the table shows the run after that change.

**Playtime (estimated, not measured):** the bot needs about 14 minutes of game time
for the whole campaign on Normal. It never explores, reads, pauses or hesitates.
A first human playthrough with deaths and retries is estimated at roughly
30-50 minutes, which may be below the 45-90 minute target. KX should time it.

## 5. Defects found by the tests and fixed

1. **Combo never reached the finisher when chained during a hit** - pressing J
   during a jab restarted the combo with another jab. Fixed in `player.gd`
   (`start_combo(chain)`); covered by `test_combo_progression_and_reset` and
   `test_full_combo_damage_and_knockdown`.
2. **Attack lunge carried Kocur through his target**, so the swipe/finisher landed
   behind the enemy and missed. Lunges and the pounce now stop at a standing
   enemy (`_blocked_ahead`).
3. **Thrown cats hit from the thrower's position**, not from the flying body, so
   they rarely bowled anyone over. The throw hitbox now travels with the body
   (`enemy.gd _tick_thrown`).
4. **Boss fights were never marked cleared** in the encounter list (results still
   worked); now `EncounterManager.finish_with_boss()` clears it and sets the
   checkpoint.
5. Spawning at a checkpoint past the last encounter indexed out of range
   (`level.gd _spawn_x`), fixed.

Earlier, during development, headless runs and screenshots found and fixed:
"grab_focus outside the tree" errors after scene changes, a drawing transform
reset in the cat painter, several script type-inference parse errors, and
characters that were too small to read (camera zoom 1.35 added). See CHANGELOG.

## 6. Not verified (needs a human on Windows)

* Each KX checklist row separately (NEO's full playthrough on Windows is the only human result so far).
* Installing the .msix and running the Windows App Certification Kit.
* Real rendering on a GPU, frame rate, fullscreen and window-size switching.
* Any audio output (the container has no sound card; files load, nothing was heard).
* Gamepad play (bindings exist and are tested; no pad was connected).
* Mouse use in menus (buttons are tested by emitting their signals).
* Combat feel, difficulty and boss fairness for humans; real playtime.

All of these are in `KX_TEST_CHECKLIST.md` (96 checks, rows not filled in individually).

## 7. Known issues

* The campaign may be shorter than the 45-90 minute target (see section 4).
* Hard difficulty: the simple bot fails at Big Bruno; human balance unknown.
* Headless test runs end with Godot's "ObjectDB instances leaked at exit" warning
  (test harness quits while scenes are queued for deletion); not seen in the game.
* `ERROR: Parse JSON failed` in the test log is expected: it comes from the
  malformed-save test.
