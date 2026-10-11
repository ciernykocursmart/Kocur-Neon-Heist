# Kocur Kart – Development Status

Engine: Godot 4.5.1-stable (Compatibility renderer, Jolt physics, 3D physics interpolation).
Godot binary used in development: `/opt/godot45/godot` (symlinked as `godot`).
Windows export templates: `~/.local/share/godot/export_templates/4.5.1.stable/`.

## Milestones

| # | Milestone | State |
|---|---|---|
| 1 | Core driving controller and camera | done |
| 2 | One complete, polished test track | done (Whiskerwood; visual polish continues) |
| 3 | Race rules, checkpoints, AI | done |
| 4 | Remaining five tracks and game modes | in progress |
| 5 | Progression, saves, UI, audio, polish | pending |
| 6 | Automated regression testing and Windows release | pending |

## Milestone 1 – done
- `scripts/kart/kart.gd`: deterministic arcade controller (CharacterBody3D): accel/brake/reverse,
  speed-scaled steering, lateral grip, drift with two charge levels, mini-turbos, Purr Boost meter,
  boost pads, ramp launches, landing, wall scrape assist (never spins), kart-kart bumps, hazards,
  recovery with brief ghosting.
- `scripts/camera/chase_camera.gd`: interpolated chase camera with speed FOV, landing dip, shake,
  scenery occlusion pull-in.
- `scripts/track/*`: spline track paths, procedural road/curb/verge/walls/embankments/ramps/pads,
  surfaces (road, curb, offroad, dirt, ice), track location queries, racing line for AI.
- `tests/test_vehicle.gd`: 29 checks, all passing.

## How to run tests
```
cd KocurKart
godot --headless --path . --import          # first time / after adding class_name scripts
godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd            # all modules
godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- test_vehicle
```

## Milestones 2-3 – done
- Decoration: `track_decor.gd` (seeded scatter via MultiMesh, landmarks, gates, corner chevrons,
  grandstand + crowd, backdrop ring), `prop_library.gd`, `landmarks.gd`.
- Whiskerwood Circuit redesigned with a hairpin and S-bends (1063 m, tightest radius 15.5 m) + dirt shortcut.
- `race.gd`: countdown (3-2-1-GO, perfect start / wheelspin), ordered checkpoints with undo on reverse,
  lap timing, positions by real progress, wrong-way, falls/off-track recovery, finish, estimated
  times for stragglers, results. `ai_driver.gd`: racing line + speed profile, drifting, Purr Boost,
  shortcuts, avoidance, hazard dodging, stuck recovery; Easy/Normal/Hard.
- UI: HUD, minimap, pause menu, settings, controls (rebinding), results/standings/cup/championship.
- Save (atomic, versioned, sanitized), Settings, Progression rules, Game flow (GP/Single/TT).
- Tests: test_vehicle 29/29, test_race 25/25, test_ai 5/5 (Whiskerwood only so far).

## Known issues
- AI occasionally needs one recovery per race on Whiskerwood (investigate).
- Audio not implemented yet (placeholder Audio autoload).
- Main menu / garage scenes not built yet.

## Next steps
1. Build Purrport Pier, Neon Catway, Frostpaw Pass, Sunset Safari, Royal Catnip Run (M4).
2. Main menu, garage, records screens; audio; ghost (M5).
