# Kocur Dungeon - Test Report

Generated from an actual run on 2026-10-12 (Linux container, Godot 4.3.stable headless, `--fixed-fps 60`).

```
RESULT: 82 tests, 82 passed, 0 failed, 1789 assertions, 76.0 s
```

## How to reproduce

```bash
cd kocur-dungeon
tools/run_tests.sh              # whole suite (about 80 s)
tools/run_tests.sh levels       # one suite
tools/build_windows.sh          # Windows export + ZIP + smoke test of the exported pack
```

`tools/run_tests.sh` fails if any assertion fails, if Godot printed a `SCRIPT ERROR`
during the run, or if the runner did not reach its summary line. Tests use their own
save and settings files (`user://test_save.json`, `user://test_settings.cfg`), so a real
save is never touched.

## What was verified, and how

| Area | How it is tested |
|---|---|
| Project integrity | Every script and scene loads and compiles; main scene, 640x360 base resolution, 16:9 window sizes; each autoload exists exactly once; input map (keys + mouse); every sound/music referenced in code exists and is preloaded; every sprite sheet loads; campaign counts (16 levels, 5 regions, 5 bosses, 10 cats, 7 upgrades, all 5 enemy archetypes used). |
| Movement | Real player in real level 1-1 driven through `Input` actions: run/decelerate, jump apex (~60 px), variable jump height, coyote time, jump buffer, no double jump, pounce + cooldown, upward pounce, drop-through platforms, damage + knockback + i-frames, shield, healing cap, spikes return the cat to safe ground, death -> death screen -> respawn at checkpoint. |
| Validator calibration | The physics-based reachability validator and the real player agree on a test map: a 3-tile step is climbable, a 4-tile wall is not. |
| Combat | Claw hits once per swing, attack cooldown, pounce damage, guard blocks front claws (not back / pounce), guard always winds up before thrusting, archer fires and arrows expire, projectiles hit once / are deflected by claws / are cleared, defeated enemies stop colliding and dealing damage and are removed, all 5 enemy types can be defeated, difficulty ramps. |
| Levels | For all 16 levels: map structure (1 start, 1 exit, checkpoints, boss arenas, cages match captives, a text for every sign); physics-based reachability: exit, checkpoints and levers reachable without pounce, every coin/gem/fish/chest/secret/cage reachable, no soft-lock spot; each level loads and runs; each level can be completed through its exit (boss levels: door locked until the guardian falls); coins survive death and are banked once; cage rescue + secret saved; results -> blessing -> next level; checkpoints heal once; rising fire in 5-3. |
| Bosses | All 5 guardians fight for 40 s each using several moves announced by warnings, stay in their arena, keep projectiles bounded; go through all phases with brief invulnerability between them; can be defeated; exit unlocks, gates reopen, relic drops, projectiles cleared; retry fully resets the fight; the Pale King's summons are cleaned up. |
| Progression & saves | New game, unlocks, coin/secret/gem/cat/challenge rewards never duplicate, upgrades change real gameplay values, rescued cats' perks apply, blessings are temporary and never saved, save/load round trip, missing / malformed / hand-edited saves load safely (corrupt file kept aside), reset progress, New Game overwrite, difficulty damage scaling, 100% completion reachable. |
| UI & audio | Main menu with and without a save, New Game confirmation + intro, Continue -> camp, credits, settings persist (and survive a broken settings file), Reset Progress asks first, pause menu (Esc, freezes play, settings, resume, restart, quit to menu with confirmation), HUD hearts/coins/gems, boss bar + boss/final music, music crossfades never stack and stop cleanly, music files loop, SFX rate limiting, camp (level select locks, upgrade shop, cats tab, campfire cats, settings, continue), death screen buttons, ending pages, no node leaks across scene changes. |
| Export | Windows preset (x86_64, embedded pack, tests/tools excluded); the built exe has a PE x86-64 header and an embedded Godot pack. Separately `tools/pack_smoke.gd` runs the exported pack with the Linux binary and loads the menus and all 16 levels. |

## Not verified (honest limits)

- **The Windows .exe was never started on Windows.** This container is Linux without Wine. What was verified: the export succeeds, the file is a valid PE32+ x86-64 executable with the game pack embedded, and the embedded pack runs (menus + all 16 levels) under the Linux Godot 4.3 binary, including a rendered screenshot under a virtual display.
- **Frame rate was not measured on real hardware.** Tests run headless with a fixed 60 Hz step; no claim about 60 FPS on any PC is made.
- **No human played the game end to end.** Levels are proven traversable by the physics validator and completable by tests that teleport to the exit; bosses are proven defeatable by direct damage, not by a human-skill playthrough. Difficulty and feel need the KX manual pass (see KX_TEST_CHECKLIST.md).
- **Audio was not listened to.** The audio device is a dummy driver here; tests check files, buses, looping and playback bookkeeping only.
- **Gamepad input** is mapped but was not tested with a physical controller.
- **Fullscreen / window resizing** is skipped in headless mode; only the persisted settings are tested.

## Full results (82 tests)

### test_bosses

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_at_least_three_guardians_including_final | 2 | 0 ms |
| PASS | test_guardians_fight_with_varied_telegraphed_moves | 25 | 6118 ms |
| PASS | test_phases_defeat_unlock_and_relic | 40 | 1202 ms |
| PASS | test_retry_resets_the_fight | 14 | 364 ms |
| PASS | test_king_summons_are_cleaned_up | 2 | 1013 ms |

### test_combat

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_claw_damages_once_per_swing | 3 | 17 ms |
| PASS | test_attack_cooldown | 2 | 24 ms |
| PASS | test_enemy_defeat_stops_it | 7 | 39 ms |
| PASS | test_contact_damage_hurts_player | 1 | 14 ms |
| PASS | test_pounce_damages_and_bounces | 2 | 15 ms |
| PASS | test_guard_blocks_front_claw_not_back | 5 | 11 ms |
| PASS | test_guard_telegraphs_before_attacking | 2 | 20 ms |
| PASS | test_archer_shoots_and_projectiles_expire | 2 | 81 ms |
| PASS | test_projectile_hits_player_once | 2 | 28 ms |
| PASS | test_claw_deflects_projectiles | 1 | 23 ms |
| PASS | test_clear_projectiles | 2 | 12 ms |
| PASS | test_every_enemy_type_can_be_defeated | 15 | 58 ms |
| PASS | test_enemies_ramp_up | 1 | 21 ms |

### test_export

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_windows_preset | 10 | 0 ms |
| PASS | test_exported_exe_if_built | 5 | 1 ms |

### test_integrity

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_all_scripts_and_scenes_load | 127 | 82 ms |
| PASS | test_main_scene_and_display_settings | 9 | 0 ms |
| PASS | test_autoloads_present_once | 5 | 0 ms |
| PASS | test_input_actions_mapped | 18 | 0 ms |
| PASS | test_every_sound_referenced_in_code_exists | 87 | 3 ms |
| PASS | test_sprite_sheets_exist | 49 | 2 ms |
| PASS | test_campaign_content_counts | 27 | 0 ms |
| PASS | test_godot_licence_bundled | 1 | 0 ms |

### test_levels

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_map_structure | 678 | 83 ms |
| PASS | test_every_level_reachable | 103 | 54534 ms |
| PASS | test_every_level_loads_and_runs | 149 | 3285 ms |
| PASS | test_complete_every_level | 75 | 3343 ms |
| PASS | test_items_banked_once_and_survive_death | 6 | 348 ms |
| PASS | test_rescue_cat_and_secret | 7 | 411 ms |
| PASS | test_results_continue_to_next_level | 3 | 320 ms |
| PASS | test_checkpoints_heal_and_respawn_order | 5 | 110 ms |
| PASS | test_rising_fire_and_bell_tower | 4 | 203 ms |

### test_movement

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_spawns_on_ground | 4 | 169 ms |
| PASS | test_run_left_and_right | 5 | 175 ms |
| PASS | test_jump_height_and_landing | 5 | 176 ms |
| PASS | test_short_hop_is_lower | 2 | 155 ms |
| PASS | test_jump_buffer_and_coyote | 4 | 186 ms |
| PASS | test_no_double_jump | 2 | 123 ms |
| PASS | test_pounce_and_cooldown | 6 | 163 ms |
| PASS | test_upward_pounce | 1 | 125 ms |
| PASS | test_damage_iframes_and_knockback | 9 | 144 ms |
| PASS | test_shield_blocks_a_hit | 2 | 120 ms |
| PASS | test_heal_capped | 1 | 114 ms |
| PASS | test_death_and_respawn_at_checkpoint | 10 | 174 ms |
| PASS | test_hazard_resets_to_safe_ground | 3 | 148 ms |
| PASS | test_drop_through_oneway | 2 | 123 ms |
| PASS | test_validator_matches_real_jump | 6 | 182 ms |

### test_progression

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_new_game_defaults | 7 | 1 ms |
| PASS | test_commit_awards_and_unlocks | 6 | 0 ms |
| PASS | test_rewards_never_duplicate | 10 | 1 ms |
| PASS | test_challenges | 6 | 1 ms |
| PASS | test_upgrades_change_gameplay_values | 14 | 1 ms |
| PASS | test_cannot_buy_without_coins | 4 | 0 ms |
| PASS | test_rescued_cats_have_effects | 6 | 0 ms |
| PASS | test_blessings_are_temporary | 4 | 0 ms |
| PASS | test_save_and_load_roundtrip | 8 | 1 ms |
| PASS | test_missing_and_malformed_saves | 11 | 1 ms |
| PASS | test_reset_progress | 3 | 1 ms |
| PASS | test_new_game_overwrites_old_progress | 3 | 1 ms |
| PASS | test_difficulty_scales_damage | 4 | 0 ms |
| PASS | test_completion_percent | 3 | 10 ms |

### test_ui_audio

| Result | Test | Assertions | Time |
|---|---|---|---|
| PASS | test_main_menu_without_save | 11 | 6 ms |
| PASS | test_new_game_flow_with_confirmation | 13 | 119 ms |
| PASS | test_continue_opens_camp | 4 | 20 ms |
| PASS | test_credits_and_back | 4 | 9 ms |
| PASS | test_settings_persist | 11 | 11 ms |
| PASS | test_settings_reset_progress_needs_confirmation | 6 | 22 ms |
| PASS | test_pause_menu | 19 | 133 ms |
| PASS | test_pause_restart_level | 3 | 241 ms |
| PASS | test_hud_reflects_state | 4 | 111 ms |
| PASS | test_boss_bar_and_music | 6 | 219 ms |
| PASS | test_music_switching_never_stacks | 31 | 2 ms |
| PASS | test_sfx_rate_limited | 1 | 1 ms |
| PASS | test_camp_screens | 14 | 232 ms |
| PASS | test_death_screen_buttons | 6 | 153 ms |
| PASS | test_ending_screen | 7 | 11 ms |
| PASS | test_scene_changes_do_not_leak | 2 | 368 ms |

## Notes printed by the tests

```
1-3 The Iron Mouser: hp 44, moves ["approach", "slam_windup", "slam", "stuck", "recover", "charge_windup", "charge", "dazed"]
2-3 The Ember Guardian: hp 60, moves ["volley_windup", "volley", "recover", "approach", "smash_windup", "smash", "stuck"]
3-3 The Frost Matron: hp 56, moves ["rain_windup", "recover", "shards_windup", "blink"]
4-3 The Shadow Stalker: hp 60, moves ["leap_windup", "leap", "landed", "recover", "vanish", "rush_windup", "rush"]
final The Pale King: hp 105, moves ["approach", "sweep_windup", "sweep", "recover", "dash_windup", "dash"]
1-3: defeated with 66 base claw hits at 2 damage
2-3: defeated with 54 base claw hits at 2 damage
3-3: defeated with 50 base claw hits at 2 damage
4-3: defeated with 66 base claw hits at 2 damage
final: defeated with 93 base claw hits at 2 damage
1-1 reachability: 158 spots, 2713 ms
1-2 reachability: 236 spots, 3606 ms
1-3 reachability: 238 spots, 7607 ms
2-1 reachability: 203 spots, 2997 ms
2-2 reachability: 269 spots, 4159 ms
2-3 reachability: 122 spots, 1721 ms
3-1 reachability: 216 spots, 2865 ms
3-2 reachability: 169 spots, 2329 ms
3-3 reachability: 129 spots, 2359 ms
4-1 reachability: 188 spots, 2950 ms
4-2 reachability: 245 spots, 3410 ms
4-3 reachability: 125 spots, 1811 ms
5-1 reachability: 209 spots, 3361 ms
5-2 reachability: 211 spots, 6768 ms
5-3 reachability: 299 spots, 4845 ms
final reachability: 68 spots, 1033 ms
```

The guardian hit counts above are with the starting claw (2 damage) and hitting at any time;
real fights are shorter because guardians take 1.5x-2x damage while stunned, pounces hit harder,
and claw upgrades raise damage.

## Exported build smoke test (tools/pack_smoke.gd, run against build/windows/KocurDungeon.exe)

```
ok    pack is Kocur Dungeon
ok    tests are not shipped
ok    autoload Settings / SaveManager / Progress / Audio / Transition
ok    level catalog loads
ok    runs res://scenes/main_menu.tscn, camp.tscn, ending.tscn
ok    level 1-1 ... final builds and runs (16 levels)
SMOKE RESULT: PASS
```
