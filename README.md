# KOCUR: NEON HEIST

A top-down neon cyberpunk stealth/action game about a small cybernetic cat
who breaks into corporate megastructures, steals classified data and slips
out again. Built with **Godot 4.3** and **GDScript**. Every visual and every
sound is generated procedurally at runtime, so the project contains no
third-party art, audio or fonts.

> Infiltrate → explore → hack systems → avoid or fight security → steal the
> data → reach EVAC → earn credits → upgrade the cat → next contract.

---

## Features

| Area | What's in the prototype |
| --- | --- |
| **Player** | Top-down movement with acceleration, mouse aim, plasma pistol (fire / reload / magazine + reserve ammo), dash with i-frames, sneak mode, claw melee with **silent takedowns** from behind, health, hit flashes, knockback, screen shake, death + restart. |
| **Enemies** | **Patrol Drone** (fast, fragile, 360° short-range sensor, orbits while shooting), **Security Guard** (forward vision cone, 3-round bursts, strafing), **Elite Hunter** (regenerating shield, long-range optics, shotgun, gap-closing dashes, relentless search). Shared AI state machine: patrol → suspicious → chase/attack → search → patrol, with A* pathfinding, line-of-sight raycasts, hearing (footsteps, gunshots, failed hacks), separation, and "radio" delay before a guard calls in the alarm (kill them first and nobody hears). |
| **Stealth & alarm** | Per-enemy awareness meter with `?`/`!` indicators, wall-clipped vision cones, sweeping **security cameras**, **security zones** (red motion-sensor floors), global detection meter in the HUD, three alarm levels (STEALTH → CAUTION → ALARM) with siren, all-units convergence on the last known position, escalation and **reinforcement waves** (hunters join on later alarms). |
| **Hacking** | Timing ring mini-game (lock the cursor in the green window). Misses make noise; too many misses leave a trace (CAUTION, or a full alarm for the data core). Hackables: **security doors** (open routes), **cameras** (shut down), **terminals** (camera loop / door override / credit skim), **alarm panels** (cancel alarm + disable motion sensors), **data core** (the objective). |
| **Missions** | Reusable `MissionCatalog` creates deterministic, endlessly scaling contracts (size, guards, drones, hunters, cameras, locked-door ratio, reward). `FacilityGenerator` assembles the facility from **9 reusable room templates** on a slot grid using a randomised spanning tree + extra loops, picks spawn / data vault / EVAC rooms by graph distance and seals the vault with security doors. Win = data + EVAC; lose = death. |
| **Progression** | Credits (contract pay, found credits, silent-takedown and ghost bonuses), **7 upgrades** with multiple levels (Armor, Servo Legs, Extended Mag, Plasma Rounds, Whisper Suppressor, Optic Camo, Neural Hack Suite), persistent JSON save. |
| **UI** | Main menu (Continue / New Game / Settings / Quit), Settings (master/music/SFX volume, fullscreen, screen shake), HUD (health, ammo, dash, alarm level + timer, detection eye meter, objectives, interaction prompt, objective/EVAC marker with off-screen arrow, minimap, notifications, damage/alarm vignette), hack overlay, pause menu, mission-complete screen with animated payout, game-over screen, Hideout upgrade shop + mission briefing. |
| **Audio** | ~30 synthesised effects (shots, reload, detection, siren, hack ticks/success/fail, pickups, mission jingle, explosions, UI…) and a looping synthwave track, all built in `Sfx` at startup. Music speeds up under CAUTION/ALARM. |
| **Visuals / feel** | Neon palette, additive light pools, muzzle flashes, sparks, explosions, floating damage numbers, noise rings, hit-stop on kills, recoil kicks, camera look-ahead, animated cat (tail, paws, glowing eyes), crosshair cursor, animated synthwave menu backdrop. |

## Controls

| Action | Input |
| --- | --- |
| Move | `W A S D` / arrow keys (physical keys, so QWERTZ/AZERTY work) |
| Aim | Mouse |
| Fire | Left mouse button |
| Reload | `R` |
| Claw / takedown | Right mouse button or `F` (instant silent kill on an unaware enemy) |
| Dash | `Space` |
| Sneak (silent, harder to see) | Hold `Shift` |
| Hack / interact | `E` |
| Hack: lock cursor | `E` / Left mouse / `Space` |
| Hack: abort | `Q` / Right mouse / `Esc` |
| Pause | `Esc` / `P` |

### Tips
* Running makes footstep noise; sneak past guards and hit them from behind.
* A guard that spots you needs ~1.3 s to radio it in (red ring over the `!`). Kill or break line of sight before it completes.
* Alarm panels cancel an active alarm *and* power down motion-sensor floors.
* Finishing a contract with no alarm pays a 50% **ghost bonus**.

## Running the project

1. Install **Godot 4.3** (standard build, not .NET): <https://godotengine.org/download>.
2. Open Godot → *Import* → select `project.godot` in this folder → *Import & Edit*.
3. Press **F5** (Run Project). The main scene is `scenes/main_menu.tscn`.

No setup is needed: input actions, audio buses, the UI theme, all sounds
and all visuals are created in code on first launch.

Command line:

```bash
godot --path .                     # play
godot --headless --path . -s res://tests/run_tests.gd   # run the test-suite
```

## Exporting the Windows build

The repository contains an export preset named **"Windows Desktop"**
(`export_presets.cfg`, x86_64, PCK embedded in the .exe, tests excluded).

1. In Godot: *Editor → Manage Export Templates → Download and Install* (4.3).
2. *Project → Export… → Windows Desktop → Export Project* (or "Export All").

Or headless:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/KocurNeonHeist.exe
```

A prebuilt, zipped release is committed at
**`build/windows/KocurNeonHeist-windows-x86_64.zip`** (single self-contained
`KocurNeonHeist.exe`). It is unsigned, so Windows SmartScreen may ask for
confirmation on first launch. The `.exe` itself is git-ignored; only the
zip is versioned.

*Windows Store notes:* the game uses the Compatibility (OpenGL 3.3) renderer
for the widest hardware support, has no network access and stores data only
in `%APPDATA%\KocurNeonHeist\` (`~/.local/share/KocurNeonHeist` on Linux). Packaging as MSIX and
code-signing (enable `codesign/*` and `application/modify_resources` with
rcedit on a Windows machine) are the remaining store steps.

## Project architecture

```
project.godot            engine config, autoloads, main scene
export_presets.cfg       Windows Desktop preset
scenes/                  three thin scenes; content is built in code
  main_menu.tscn         -> scripts/ui/main_menu.gd
  game.tscn              -> scripts/systems/game.gd
  hideout.tscn           -> scripts/ui/hideout.gd
scripts/
  autoload/
    game_state.gd        GameState: credits, mission index, upgrades, stats,
                         derived player stats, settings, input map, save/load
    sfx.gd               Sfx: procedural sound synthesis + player pools + music
  core/
    palette.gd           shared neon colours
    fx.gd                particles, light flashes, rings, floating text
    ring_effect.gd       expanding ring node used by FX
    vision_cone.gd       raycast fan for wall-clipped vision polygons
    ui_theme.gd          code-built Theme, widget helpers, crosshair cursor
  world/
    room_templates.gd    9 ASCII room templates + legend
    facility_generator.gd  slot-grid assembly, spanning tree, doors, roles
    facility.gd          tiles, collision, AStarGrid2D, LOS, zones, rendering
  actors/
    player.gd            the cat
    enemy.gd             base AI state machine (perception, pathing, combat)
    enemy_guard.gd / enemy_drone.gd / enemy_hunter.gd   archetypes
    bullet.gd            swept-raycast projectile
  objects/
    hackable.gd          base class for hackable systems
    security_door.gd, security_camera.gd, terminal.gd,
    alarm_panel.gd, data_core.gd, pickup.gd, extraction_pad.gd
  systems/
    game.gd              mission controller (spawning, objectives, win/lose)
    mission_catalog.gd   deterministic mission definitions
    alarm_system.gd      alert levels, escalation, reinforcements
    game_camera.gd       follow cam, look-ahead, shake, recoil kick
  ui/
    hud.gd, hack_overlay.gd, pause_menu.gd, end_screen.gd,
    settings_panel.gd, main_menu.gd, hideout.gd, neon_background.gd
tests/
  run_tests.gd / test_suite.gd       headless automated tests
  run_screenshots.gd / screenshot_tour.gd   visual smoke test (needs a display)
```

**Data flow.** `GameState` (autoload) owns everything persistent. When
`game.tscn` loads, `Game` asks `GameState` for the current mission
definition (`MissionCatalog.build`), feeds it to `FacilityGenerator`, hands
the layout to `Facility`, then spawns actors and systems from the room
markers. Actors talk back to `Game` through a small API
(`emit_noise`, `spawn_bullet`, `on_enemy_killed`, `notify`, …) and to the
`AlarmSystem`. On victory `Game` builds a result dictionary and calls
`GameState.complete_mission`, which pays out and saves.

**Adding content.**
* *New room:* append a 15×11 ASCII template to `RoomTemplates.TEMPLATES`
  (keep door areas clear; the test-suite verifies this and reachability).
* *New enemy:* extend `Enemy`, set stats in `_configure()`, draw in
  `_draw_body()`, optionally override `_combat_move()`; spawn it in
  `Game._populate()`.
* *New hackable:* extend `Hackable` and implement `on_hacked()`.
* *New upgrade:* add it to `GameState.UPGRADES`/`UPGRADE_ORDER` and read
  its level in a stat helper.

## Testing

`tests/test_suite.gd` (run via `tests/run_tests.gd`) performs ~880 checks:

* every script compiles and every scene loads;
* room templates have the right size, clear door areas, centre markers;
* 200 generated facilities: every room and marker reachable, vault sealed;
* mission catalogue determinism and difficulty scaling;
* upgrade purchase rules, caps, cost scaling, save/load round-trip
  (in-memory and real file), corrupt-save clamping;
* main menu and hideout scenes load;
* full mission win flow (no EVAC without data, data download, EVAC,
  payout, mission index advance, victory screen);
* death → game-over screen → retry reloads the same layout cleanly;
* door hacking updates navigation, hack mini-game success and failure,
  traces, alarm broadcast to all enemies, reinforcements, alarm panel reset,
  guard detection, silent takedowns, 4 s of live AI simulation;
* combat: player bullets damage guards, the hunter shield absorbs damage,
  enemy fire hurts the cat;
* a **bot playthrough** on missions 1–6 that walks the cat with real
  physics to the data core and EVAC and completes each mission.

`tests/run_screenshots.gd` renders every screen to PNG (used for visual QA
under Xvfb):

```bash
xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/run_screenshots.gd
```

`.github/workflows/build.yml` runs the test-suite and exports the Windows
build (uploaded as a workflow artifact) on every push / pull request.

## Known limitations

* Balance is first-pass; later missions (5+) with several hunters get hard.
* Enemies do not react to discovered bodies, and there is no fog of war:
  the whole facility is visible (vision cones communicate threat instead).
* Doors are either open doorways or hackable blast doors; enemies cannot
  open locked doors (reinforcements may path partially and wait).
* Only one weapon; no gamepad bindings yet (keyboard + mouse only).
* The Windows build is unsigned and uses the default Godot icon in the
  .exe resources (rcedit is not available in the Linux build environment).
* Fonts use the system monospace font (Consolas on Windows) with Godot's
  fallback elsewhere.

## Future improvements

* Gamepad support and remappable controls in Settings.
* More room templates and multi-floor facilities; optional side objectives.
* Body discovery, distraction gadgets (thrown noise-makers, EMP), vents.
* More weapons/gadgets in the shop; per-mission modifiers.
* Hand-tuned audio mix and an alarm-specific music layer.
* Localisation (Slovak/English), accessibility options (colour-blind
  palettes, hack timing assist).
* MSIX packaging, code signing and a custom .exe icon for store release.

## License / assets

All code, visuals and sounds in this repository are original and generated
procedurally; no third-party assets are included. Godot Engine is MIT
licensed.
