# Kocur Kart

**An arcade kart racer with feline flair, by Kocur Studios.**
Godot 4.5.1 · Windows x64 · single player · fully offline

Drift around corners, charge mini-turbos, fill your Purr meter and race five rival cats across six
hand-built circuits. Win the three-cup championship, hunt Time Trial medals against your own ghost
and unlock new racers, karts and cosmetics.

---

## Contents

- 6 tracks: Whiskerwood Circuit, Purrport Pier, Neon Catway, Frostpaw Pass, Sunset Safari,
  Royal Catnip Run
- 3 cups (two tracks each): Whisker Cup, Moonlight Cup, Royal Cup
- 3 modes: Grand Prix, Single Race, Time Trial (with a best-run ghost)
- 3 AI difficulties: Easy, Normal, Hard
- 6 playable cats (8 cats in total, two are rivals only), 3 kart bodies, 11 paints, 4 wheel styles,
  6 accessories
- Original procedural art, music and sound effects throughout

## Minimum known requirements

These are estimates. The game has not yet been played on physical Windows hardware (see
*Known limitations*).

- Windows 10 or 11, 64-bit
- A GPU with OpenGL 3.3 support (Godot Compatibility renderer); integrated GPUs from about 2015
  onwards should work
- 4 GB RAM, about 300 MB of disk space
- Keyboard, or an XInput-compatible gamepad (optional)

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT or A |
| Brake / Reverse | S / Down | LT or B |
| Steer | A, D / Left, Right | Left stick / D-pad |
| Drift (hold) | Space | RB |
| Purr Boost | Shift | X or LB |
| Recover kart | R | Y |
| Pause | Esc / P | Start |

Keyboard keys can be rebound in **Settings > Controls**. Menus work with mouse, keyboard
(arrows/Enter/Esc) and gamepad (D-pad/A/B).

**Driving tips**
- **Drift:** hold Drift while steering into a corner. Blue sparks mean a small boost and orange
  sparks a big one. Release Drift to fire the boost. Steering into the drift tightens it, and
  steering out of it widens it.
- **Purr Boost:** every boosted drift fills the Purr meter (three segments). Press Purr Boost to
  spend one full segment.
- **Perfect start:** press Accelerate while **1** is showing. If you floor it while **3** is still
  up, the wheels spin.
- **Boost pads** (orange chevrons) give a short boost. The ramps before the jumps on Neon Catway and
  Royal Catnip Run come with a boost pad.
- **Recover** (R) puts you back on the track if you get stuck. Falling off the course or leaving it
  respawns you automatically.

## Game modes

- **Grand Prix:** pick a cup and a difficulty, then race both tracks against five rivals. Points per
  race go 10-7-5-3-2-1. Your overall cup standing earns a trophy: gold for 1st, silver for 2nd and
  bronze for 3rd. Standings appear after each race. In race 2 the grid is set in reverse order of
  the standings. *Retry Race* resets the points to what they were before that race.
- **Single Race:** any unlocked track, any difficulty, 1–5 laps. Shows the finishing order and
  your best times.
- **Time Trial:** three laps alone against the clock. Your best total time and best lap are saved,
  and you earn medals for beating the target times. Your fastest run is replayed as a ghost.
  *Retry* restarts instantly.

## Progression and unlocks

- **Cups:** the Whisker Cup is open from the start. A trophy (top three overall) in one cup unlocks
  the next cup and its tracks, for Grand Prix, Single Race and Time Trial.
- **Championship:** earn a trophy in all three cups to complete the championship. A dedicated
  completion screen follows.
- **Unlockables:** every locked item in the garage shows how to earn it.

| Unlock | How |
|---|---|
| Duchess (racer), Pounce (kart), Steel paint, Sport Rims, Goggles | Trophy in the Whisker Cup |
| Tux (racer), Thunderpaw (kart) | Trophy in the Moonlight Cup |
| Sushi (racer), Royal Crown | Finish all three cups |
| Ziggy (racer) | 3 gold Time Trial medals |
| Catnip Flower | Gold trophy in the Whisker Cup |
| Royal Purple paint | Gold trophy in the Royal Cup |
| Champion Gold paint | Finish all three cups on Hard |
| Lime / Rose / Snow / Sunny paints | Silver medal on Whiskerwood / Purrport / Frostpaw / Safari |
| Chunky Treads / Neon Rims / Headphones | Silver / Gold / Bronze medal on Neon Catway |

The starter **Alley Racer** is an all-rounder and can win the whole championship. The other karts
trade small amounts of speed, acceleration, handling, drift and weight.

**Records & Progress** (main menu) shows trophies, Time Trial records and medals, race bests, wins,
unlock progress and your recent results. It also has a **Reset Progress** button, which asks for
confirmation first.

## Launching the Windows build

1. Unzip `KocurKart-1.0.0-windows-x86_64.zip` anywhere.
2. Run `KocurKart/KocurKart.exe`. It is a single executable with all game data embedded.
3. Save data and settings are stored in `%APPDATA%\KocurKart\` (`save.json`, `settings.cfg`,
   `ghost_<track>.json`).

## Opening the source project

1. Install **Godot 4.5.1-stable** (standard build, not .NET).
2. In the Project Manager choose **Import** and select `KocurKart/project.godot`.
3. Press F5 to play. The main scene is `scenes/main_menu.tscn`.

The project is a standalone Godot project inside the `KocurKart/` folder of this repository. The
`Kocur: Neon Heist` project in the repository root is unrelated and ignores this folder.

## Building and exporting

Prerequisites: Godot 4.5.1 on PATH as `godot`, with the 4.5.1 export templates installed.

```bash
cd KocurKart
tools/run_tests.sh godot                 # full headless test suite (fails on any script error)
tools/build_windows.sh godot             # -> build/windows/KocurKart.exe
                                         # -> build/release/KocurKart-1.0.0-windows-x86_64.zip
tools/verify_windows.sh                  # runs the exported .exe (Wine on Linux) in 3 phases
```

Other tools:
- `python3 tools/audio/make_audio.py` regenerates every sound and music file. It needs numpy and
  ffmpeg.
- `godot --headless --path . -s res://tools/track_report.gd -- <dir>` prints track geometry checks
  and writes top-down maps.
- `godot --headless --fixed-fps 60 --path . -s res://tools/calibrate_medals.gd` suggests medal
  times.

## Project layout

```
KocurKart/
  project.godot, export_presets.cfg, icon.svg, icon.ico
  scenes/            main_menu, race, garage (thin scenes; content is built in code)
  scripts/autoload/  Controls, Save, Settings, Audio, Game, Autotest
  scripts/kart/      Kart controller, model, player/scripted input, factory
  scripts/camera/    Chase camera
  scripts/track/     Track paths, builder, walls, hazards, decor, props, landmarks, themes, racing line
  scripts/race/      Race manager, entries, environment, audio, ghost
  scripts/ai/        AI driver
  scripts/ui/        HUD, minimap, menus, garage, pause, settings, controls, results
  scripts/data/      Track catalog, racers/karts/cosmetics catalog, progression rules
  shaders/           Road, curb, terrain, water, prop shaders
  assets/            Generated audio, Fredoka font (OFL)
  tests/             Headless test suite (7 modules)
  tools/             Build, verification, audio generation and design tools
```

## Known limitations

- **Not yet played on real Windows hardware.** The exported `.exe` was launched and verified
  outside the editor with Wine 9.0 on Linux and Mesa llvmpipe software OpenGL. It booted, built all
  tracks, finished a full race, wrote the save, kept progress across a restart and rendered frames.
  Real GPU performance, driver behaviour, fullscreen and resolution switching, and gamepads need the
  human KX pass (`KX_TEST_CHECKLIST.md`).
- **The 60 FPS @ 1080p target has not been measured on real hardware.** Measured instead: about
  2.4 ms CPU per frame with 6 karts, scene builds in 0.2–0.5 s, and about 190–225 draw calls and
  75k–150k triangles per frame.
- **Audio** is synthesised procedurally. Its balance and quality have not been judged by ear.
- **Gamepad support** uses Godot's standard joypad mappings and has not been tried with a physical
  controller.
- Only English text. The Fredoka font has no glyphs for some Slovak letters (ň, č, ľ, ť, ď).
- No online features, by design.

## Credits

Kocur Studios. Built with the Godot Engine (MIT). Fredoka font by the Fredoka Project Authors
(SIL OFL 1.1). All 3D models, textures, music and sound effects are original and generated for this
game.
