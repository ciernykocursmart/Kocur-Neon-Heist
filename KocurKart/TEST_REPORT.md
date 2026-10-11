# Kocur Kart – Automated Test Report

Generated 2026-10-11 from the actual test outputs (`tools/make_test_report.py`).

## Summary

| Suite | Checks | Passed | Failed |
|---|---|---|---|
| test_vehicle | 36 | 36 | 0 |
| test_track | 61 | 61 | 0 |
| test_race | 25 | 25 | 0 |
| test_ai | 15 | 15 | 0 |
| test_progression | 38 | 38 | 0 |
| test_ui | 26 | 26 | 0 |
| **Headless suite total** | **201** | **201** | **0** |
| Exported Windows build (Wine) | 23 | 23 | 0 |

Headless suite runtime: 124 s of game simulation at a fixed 60 FPS.

**How the evidence was produced**
- Headless suite: `tools/run_tests.sh godot` runs `godot --headless --fixed-fps 60 -s res://tests/run_tests.gd`. Each check asserts a measured value, which is given in the Evidence column. The runner also fails if the log contains any `SCRIPT ERROR`. Logs are in `build/test_report/test.log`, with machine-readable results in `build/test_report/results.json` (copy: `release/verify/test_results.json`).
- Exported build: `tools/verify_windows.sh` runs `build/windows/KocurKart.exe` under **Wine 9.0 on Linux** (not physical Windows) with a fresh profile in three phases (`--autotest=race`, `verify`, `shot`). The reports are `release/verify/autotest_*.json`, the rendered frame is `autotest_shot.png` and the resulting save is `save_after_race.json`.

## Exported Windows build verification

### Phase `race` – PASS

Platform reported by the game: Windows · Godot 4.5.1-stable (official) · user dir `C:/users/root/AppData/Roaming/KocurKart`

| Check | Result | Evidence |
|---|---|---|
| main menu loads | PASS |  |
| audio assets loaded | PASS | 41 streams |
| font loaded | PASS |  |
| track builds: whiskerwood | PASS | 307 ms, 47 nodes |
| track builds: purrport | PASS | 226 ms, 46 nodes |
| track builds: neon | PASS | 249 ms, 44 nodes |
| track builds: frostpaw | PASS | 307 ms, 41 nodes |
| track builds: safari | PASS | 310 ms, 52 nodes |
| track builds: royal | PASS | 325 ms, 52 nodes |
| race scene starts | PASS |  |
| race finishes | PASS | 49.8 s race time |
| results screen shown | PASS |  |
| save file written | PASS | user://save.json |
| save file parses | PASS |  |
| race recorded in save | PASS | races 1, best lap 37.80 |
| returns to menu | PASS |  |

### Phase `verify` – PASS

Platform reported by the game: Windows · Godot 4.5.1-stable (official) · user dir `C:/users/root/AppData/Roaming/KocurKart`

| Check | Result | Evidence |
|---|---|---|
| main menu loads | PASS |  |
| save exists after restart | PASS | user://save.json |
| save loaded on boot | PASS | loaded |
| progress persisted across launches | PASS | races 1 |
| settings file exists | PASS |  |

### Phase `shot` – PASS

Platform reported by the game: Windows · Godot 4.5.1-stable (official) · user dir `C:/users/root/AppData/Roaming/KocurKart`
· renderer: llvmpipe (LLVM 20.1.2, 256 bits) / 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4

| Check | Result | Evidence |
|---|---|---|
| main menu loads | PASS |  |
| frame rendered | PASS | 1600x900 |

## Detailed results

### test_vehicle

| Test | Result | Evidence |
|---|---|---|
| Acceleration from standstill | PASS | speed 0.0 -> 15.7 m/s after 1 s |
| Reaches but does not exceed top speed | PASS | 27.00 m/s after 4 s (top 27.0) |
| Braking reduces speed | PASS | 27.0 -> 10.0 m/s in 0.5 s |
| Holding brake from standstill reverses | PASS | speed -9.0 m/s |
| Coasting rolls to a stop | PASS | speed 0.00 m/s |
| Steering right turns the kart right | PASS | yaw change -0.87 rad in 0.5 s |
| Steering left turns the kart left | PASS | yaw -0.87 -> -0.04 rad |
| Steering rate scales sensibly with speed | PASS | 0 m/s 0.00, 8 m/s 2.43, top 1.50 rad/s |
| Drift starts when steering with drift held | PASS | drifting=true dir=-1 at 26.5 m/s |
| Sustained drift charges two boost levels | PASS | level 1 after 0.9 s, 2 after 2 s |
| Drift keeps forward momentum | PASS | speed 26.5 -> 21.4 m/s |
| Releasing a charged drift fires a large boost and fills Purr | PASS | boost 1.15 s, purr 0.60 |
| Mini-turbo pushes past normal top speed | PASS | 34.7 m/s |
| Uncharged drift gives no boost | PASS | boost 0.00 s |
| Purr Boost needs a full segment | PASS | boost 0.00, purr 0.40 |
| Purr Boost spends one segment | PASS | boost 1.48 s, purr 0.20 |
| Purr Boost accelerates hard | PASS | 35.6 m/s (top 27.0) |
| Ramp launches the kart | PASS | airtime 0.65 s, peak height 2.04 m |
| Lands once without bouncing | PASS | 1 landing events |
| Keeps driving after landing | PASS | on floor true, 27.0 m/s |
| Wall collision is detected | PASS | 1 hit events |
| Wall hit never spins the kart | PASS | max yaw rate 1.80 rad/s |
| Kart slides along the wall and keeps going | PASS | lateral -12.3 m, 15.7 m/s |
| Recovery puts the kart on the road facing forward | PASS | lateral -0.0, heading error 0.00 |
| Recovered kart is briefly non-colliding | PASS | ghost 1.30 s |
| Recovered kart is drivable again | PASS | 25.7 m/s |
| Reversing away from a wall frees the kart | PASS | lateral 12.0 -> 9.2 m |
| Off-road verge slows the kart | PASS | road 27.0 m/s, verge 15.7 m/s (offroad) |
| Karts collide and bump each other | PASS | 1 bump events |
| A side bump never spins the other kart | PASS | max yaw rate 0.00 rad/s |
| Both karts keep racing after contact | PASS | 26.9 / 27.0 m/s |
| Boost pads fire a boost | PASS | [&"pad"] |
| Ice greatly reduces grip | PASS | road slide 2.10 m/s, ice slide 6.49 m/s (ice) |
| Touching a hazard knocks the kart about | PASS | 1 hits |
| Kart recovers control after a hazard hit | PASS | 30.6 m/s, 1 hits |
| Handling is consistent at 60 and 120 Hz physics | PASS | speed 24.42 vs 24.40 m/s, distance 29.2 vs 29.0 m |

### test_track

| Test | Result | Evidence |
|---|---|---|
| Six tracks in three two-track cups | PASS |  |
| Every track belongs to exactly one cup, in order | PASS | ["whiskerwood", "purrport", "neon", "frostpaw", "safari", "royal"] |
| Whiskerwood Circuit: builds with road and start gantry | PASS | 1063 m, built in 378 ms |
| Whiskerwood Circuit: all 6 grid slots on the road behind the line | PASS |  |
| Whiskerwood Circuit: 10 ordered checkpoints from the finish line | PASS | largest spacing 106 m |
| Whiskerwood Circuit: racing line stays on the road with sane speeds | PASS | slowest planned corner 24.2 m/s |
| Whiskerwood Circuit: no impossible corners | PASS | inner-edge fold factor 0.77 |
| Whiskerwood Circuit: every respawn point is on solid road | PASS | 0 bad points |
| Whiskerwood Circuit: road surface is continuous outside designed gaps | PASS | holes at s= |
| Whiskerwood Circuit: shortcut 1 connects to the road and saves a fair distance | PASS | saves 61 m |
| Whiskerwood Circuit: features on the road and hazards always passable | PASS | 0 hazards, 1 pads, 0 ramps |
| Whiskerwood Circuit: medal targets are ordered and achievable | PASS | [117.5, 126.0, 137.5] |
| Purrport Pier: builds with road and start gantry | PASS | 813 m, built in 273 ms |
| Purrport Pier: all 6 grid slots on the road behind the line | PASS |  |
| Purrport Pier: 10 ordered checkpoints from the finish line | PASS | largest spacing 81 m |
| Purrport Pier: racing line stays on the road with sane speeds | PASS | slowest planned corner 27.0 m/s |
| Purrport Pier: no impossible corners | PASS | inner-edge fold factor 0.60 |
| Purrport Pier: every respawn point is on solid road | PASS | 0 bad points |
| Purrport Pier: road surface is continuous outside designed gaps | PASS | holes at s= |
| Purrport Pier: features on the road and hazards always passable | PASS | 2 hazards, 2 pads, 0 ramps |
| Purrport Pier: medal targets are ordered and achievable | PASS | [85.5, 91.5, 100.0] |
| Neon Catway: builds with road and start gantry | PASS | 768 m, built in 249 ms |
| Neon Catway: all 6 grid slots on the road behind the line | PASS |  |
| Neon Catway: 10 ordered checkpoints from the finish line | PASS | largest spacing 77 m |
| Neon Catway: racing line stays on the road with sane speeds | PASS | slowest planned corner 27.0 m/s |
| Neon Catway: no impossible corners | PASS | inner-edge fold factor 0.75 |
| Neon Catway: every respawn point is on solid road | PASS | 0 bad points |
| Neon Catway: road surface is continuous outside designed gaps | PASS | holes at s= |
| Neon Catway: jump gap at 397 m has a ramp and open air | PASS |  |
| Neon Catway: features on the road and hazards always passable | PASS | 2 hazards, 4 pads, 1 ramps |
| Neon Catway: medal targets are ordered and achievable | PASS | [85.5, 91.5, 100.0] |
| Frostpaw Pass: builds with road and start gantry | PASS | 1032 m, built in 329 ms |
| Frostpaw Pass: all 6 grid slots on the road behind the line | PASS |  |
| Frostpaw Pass: 10 ordered checkpoints from the finish line | PASS | largest spacing 103 m |
| Frostpaw Pass: racing line stays on the road with sane speeds | PASS | slowest planned corner 23.0 m/s |
| Frostpaw Pass: no impossible corners | PASS | inner-edge fold factor 0.54 |
| Frostpaw Pass: every respawn point is on solid road | PASS | 0 bad points |
| Frostpaw Pass: road surface is continuous outside designed gaps | PASS | holes at s= |
| Frostpaw Pass: features on the road and hazards always passable | PASS | 1 hazards, 1 pads, 0 ramps |
| Frostpaw Pass: medal targets are ordered and achievable | PASS | [119.5, 128.0, 139.5] |
| Sunset Safari: builds with road and start gantry | PASS | 1011 m, built in 325 ms |
| Sunset Safari: all 6 grid slots on the road behind the line | PASS |  |
| Sunset Safari: 10 ordered checkpoints from the finish line | PASS | largest spacing 101 m |
| Sunset Safari: racing line stays on the road with sane speeds | PASS | slowest planned corner 26.2 m/s |
| Sunset Safari: no impossible corners | PASS | inner-edge fold factor 0.69 |
| Sunset Safari: every respawn point is on solid road | PASS | 0 bad points |
| Sunset Safari: road surface is continuous outside designed gaps | PASS | holes at s= |
| Sunset Safari: shortcut 1 connects to the road and saves a fair distance | PASS | saves 26 m |
| Sunset Safari: features on the road and hazards always passable | PASS | 4 hazards, 2 pads, 1 ramps |
| Sunset Safari: medal targets are ordered and achievable | PASS | [107.5, 115.0, 125.5] |
| Royal Catnip Run: builds with road and start gantry | PASS | 1108 m, built in 423 ms |
| Royal Catnip Run: all 6 grid slots on the road behind the line | PASS |  |
| Royal Catnip Run: 12 ordered checkpoints from the finish line | PASS | largest spacing 92 m |
| Royal Catnip Run: racing line stays on the road with sane speeds | PASS | slowest planned corner 22.0 m/s |
| Royal Catnip Run: no impossible corners | PASS | inner-edge fold factor 0.81 |
| Royal Catnip Run: every respawn point is on solid road | PASS | 0 bad points |
| Royal Catnip Run: road surface is continuous outside designed gaps | PASS | holes at s= |
| Royal Catnip Run: jump gap at 602 m has a ramp and open air | PASS |  |
| Royal Catnip Run: shortcut 1 connects to the road and saves a fair distance | PASS | saves 26 m |
| Royal Catnip Run: features on the road and hazards always passable | PASS | 2 hazards, 4 pads, 1 ramps |
| Royal Catnip Run: medal targets are ordered and achievable | PASS | [119.5, 127.5, 139.5] |

### test_race

| Test | Result | Evidence |
|---|---|---|
| Race initializes with 6 karts in countdown | PASS | 6 karts, state 0 |
| Karts are held on the grid during the countdown | PASS |  |
| Countdown shows 3-2-1-GO then racing starts | PASS | ticks [3, 2, 1, 0] |
| Player kart drives after GO | PASS | 22.9 m/s |
| Race reaches the results state | PASS | race time 90.6 s |
| Checkpoints are only ever advanced in order | PASS |  |
| Laps increment 1, 2 for every finisher | PASS | { "duchess": [1, 2], "kocur": [1, 2], "marmalade": [1, 2], "ziggy": [1, 2], "tux": [1, 2], "sushi": [1, 2] } |
| Finish triggers exactly once per kart | PASS | { "duchess": 1, "kocur": 1, "ziggy": 1, "marmalade": 1, "tux": 1, "sushi": 1 } |
| Results are ordered by finishing time | PASS | positions [1, 2, 3, 4, 5, 6] |
| Player result is valid with 2 lap times | PASS | laps [40.1166666666657, 39.0999999999978] |
| Results screen appears after the race | PASS |  |
| Crossing the start line begins lap 1 | PASS | lap 1 next_cp 1 |
| Reversing over the line undoes the crossing | PASS | lap 0 next_cp 0 |
| Repeated line crossings never add laps | PASS | lap 1 |
| Checkpoints advance while driving | PASS | next_cp 6 of 10 |
| Skipping part of the lap is not credited | PASS | lap 1 next_cp 6 |
| Completing every checkpoint counts the lap | PASS | lap 2, 1 lap times |
| Wrong-way warning appears when driving backwards | PASS | events [true] |
| Wrong-way warning clears when turned around | PASS | events [true, false] |
| Falling off the world respawns on the track | PASS | height above road 0.10 |
| Leaving the circuit respawns the kart | PASS | lateral -0.3 |
| Restart leaves no duplicate karts or tracks | PASS | 6 karts, 1 tracks (previous race ran 2.6 s) |
| Restarted race state is fresh | PASS | time 0.00 state 0 |
| Time Trial races alone | PASS | 1 karts |
| Time Trial completes with three valid laps | PASS | total 1:53.767, laps [39.2166666666657, 36.6999999999979, 37.8499999999978] |

### test_ai

| Test | Result | Evidence |
|---|---|---|
| Every AI leaves the starting grid | PASS | slowest progress after 5 s: 82 m |
| AI stays on the road | PASS | off-road 1.8% of samples, worst 4.4 m past the road edge |
| Whiskerwood Circuit: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 2:04.783, Duchess 1:58.200, Tux 2:05.867, Sushi 2:03.817, Ziggy 2:02.500, Kocur 1:57.667 |
| Whiskerwood Circuit: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Purrport Pier: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 1:32.117, Duchess 1:33.000, Tux 1:33.783, Sushi 1:34.917, Ziggy 1:31.133, Kocur 1:27.483 |
| Purrport Pier: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Neon Catway: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 1:30.017, Duchess 1:30.683, Tux 1:28.767, Sushi 1:32.583, Ziggy 1:31.633, Kocur 1:25.283 |
| Neon Catway: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Frostpaw Pass: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 2:04.567, Duchess 2:03.733, Tux 2:06.400, Sushi 2:07.133, Ziggy 2:05.767, Kocur 1:59.400 |
| Frostpaw Pass: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Sunset Safari: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 1:56.967, Duchess 1:58.517, Tux 1:55.267, Sushi 1:59.267, Ziggy 1:56.367, Kocur 1:48.117 |
| Sunset Safari: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Royal Catnip Run: all 6 karts finish 3 laps | PASS | 6 real finishers; Marmalade 2:03.500, Duchess 2:04.983, Tux 2:07.433, Sushi 2:05.633, Ziggy 2:06.917, Kocur 1:59.617 |
| Royal Catnip Run: AI recovery never loops | PASS | max recoveries by one kart: 0 { "marmalade": 0, "duchess": 0, "tux": 0, "sushi": 0, "ziggy": 0, "kocur": 0 } |
| Difficulty levels produce clearly different pace | PASS | avg AI 2-lap time: easy 96.2 s, normal 86.0 s, hard 81.7 s |

### test_progression

| Test | Result | Evidence |
|---|---|---|
| Grand Prix points table | PASS | [10, 7, 5, 3, 2, 1, 0] |
| Trophy for cup standing | PASS |  |
| Only the first cup is open on a new save | PASS |  |
| Cup 1 tracks open, later tracks locked | PASS |  |
| 4th place in a cup earns no trophy and no unlock | PASS | trophy 0 |
| A bronze trophy unlocks the next cup | PASS |  |
| Kart unlocks follow cup results | PASS |  |
| Better results upgrade the trophy and best points | PASS |  |
| Worse results never downgrade a trophy | PASS |  |
| New unlocks are reported once | PASS | Duchess, Pounce, Steel, Sport Rims, Goggles, Catnip Flower, Moonlight Cup |
| Unlock notifications are not repeated | PASS |  |
| Locked items explain how to earn them | PASS | Earn Gold medal in Neon Catway Time Trial |
| Invalid (unfinished) runs never create records | PASS |  |
| A valid run sets the record | PASS | { "new_best_time": true, "new_best_lap": true, "medal": 1, "medal_improved": true } |
| Slower runs keep the record, faster laps update best lap | PASS | { "new_best_time": false, "new_best_lap": true, "medal": 0, "medal_improved": false } |
| Medal thresholds | PASS |  |
| Silver medal is stored and unlocks its paint | PASS | { "new_best_time": true, "new_best_lap": false, "medal": 2, "medal_improved": true } |
| Race results update race records and stats only | PASS |  |
| Shorter races never count as full-race records | PASS |  |
| Race 1 awards points to the standings | PASS | { "kocur": 7, "marmalade": 10, "duchess": 5, "tux": 3, "sushi": 2, "ziggy": 1 } |
| Cup standings after two races | PASS | leader kocur with 17 |
| Winning the cup awards and saves gold | PASS |  |
| Finishing Cup 1 unlocks Cup 2 | PASS |  |
| Cup completion reports unlocks | PASS | Duchess, Pounce, Steel, Sport Rims, Goggles, Catnip Flower, Moonlight Cup |
| All three cups complete the championship | PASS |  |
| Save and reload preserve progress | PASS | status loaded |
| Atomic save leaves no temp file | PASS |  |
| Previous save is kept as a backup | PASS |  |
| Corrupt save is recovered from the backup | PASS | status recovered |
| Unreadable save falls back to defaults safely | PASS | status reset_corrupt |
| Partially corrupted data is repaired field by field | PASS | {"cups":{"cup1":{"best_points":0,"trophy":3,"trophy_easy":0,"trophy_hard":0,"trophy_normal":0},"cup2":{"best_points":0,"trophy":0,"trophy_easy":0,"trophy_hard": |
| An abandoned race leaves no records or stats | PASS |  |
| Reset progress clears records, trophies and ghosts | PASS |  |
| Settings persist across reloads | PASS |  |
| Volume sliders drive the correct audio buses | PASS | music 0.30 sfx 0.00 |
| Effects volume does not touch music | PASS |  |
| Invalid settings fall back to defaults | PASS |  |
| All audio assets load | PASS | 41 streams |

### test_ui

| Test | Result | Evidence |
|---|---|---|
| Main menu shows every required entry | PASS | Grand Prix, Single Race, Time Trial, Garage, Records & Progress, Settings, Credits, Quit |
| Grand Prix page: Cup 1 open, later cups locked | PASS | [true, false, false] |
| Locked cups say how to unlock them | PASS | Moonlight Cup    / Locked: Earn a trophy in the Whisker Cup |
| Single Race page offers start and kart setup | PASS |  |
| Locked tracks cannot be selected | PASS |  |
| Time Trial page offers start | PASS |  |
| Records page shows progress and reset | PASS |  |
| Credits page reachable | PASS |  |
| Settings opens from the menu | PASS |  |
| Menu music plays | PASS | menu |
| Pause freezes the race | PASS |  |
| Pause menu offers resume/restart/settings/quit | PASS | Resume, Restart Race, Settings, Controls, Quit to Menu |
| Resume continues the race | PASS |  |
| HUD and race audio are present | PASS |  |
| Track music follows the theme | PASS | pier |
| Results offer replay, track select and menu | PASS | Race Again, Choose Track, Main Menu |
| Time Trial results allow an instant retry | PASS | Retry, Choose Track, Main Menu |
| Garage explains locked items | PASS | Calico chaos on four wheels. / LOCKED - Finish all three cups |
| Garage shows the kart model | PASS |  |
| Garage saves only unlocked choices | PASS | { "racer": "kocur", "kart": "alley", "paint": "midnight", "wheels": "classic", "accessory": "scarf" } |
| Main menu scene loads | PASS |  |
| Single Race starts from the menu flow | PASS |  |
| Returning to the menu frees the race | PASS | 0 races left |
| Time Trial starts from the menu flow | PASS |  |
| Grand Prix starts with the cup's first track | PASS |  |
| Restart via the game flow keeps a single race | PASS |  |

## Unresolved failures

None. Every automated check above passed on the final build.

## Not covered by automation (needs human KX testing)

- Physical Windows hardware and real GPU drivers, frame rate at 1080p, fullscreen and resolution switching (the window code is guarded in headless mode).
- Physical gamepads. Input mappings are defined but were never driven by a real controller.
- Audio quality and balance by ear. Tests only confirm that the assets load, the buses route correctly and the volumes apply.
- Subjective driving feel, difficulty fairness and fun.

See `KX_TEST_CHECKLIST.md` for the manual procedure.
