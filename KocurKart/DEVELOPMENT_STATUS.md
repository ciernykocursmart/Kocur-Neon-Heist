# Kocur Kart – Development Status

Engine: Godot 4.5.1-stable (Compatibility renderer, Jolt physics, 3D physics interpolation).
Godot binary used in development: `/opt/godot45/godot` (symlinked as `godot`).
Windows export templates: `~/.local/share/godot/export_templates/4.5.1.stable/`.

## Milestones

| # | Milestone | State |
|---|---|---|
| 1 | Core driving controller and camera | done |
| 2 | One complete, polished test track | in progress |
| 3 | Race rules, checkpoints, AI | pending |
| 4 | Remaining five tracks and game modes | pending |
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

## Known issues
- Tracks still need decoration (M2).

## Next steps
1. Track decoration system (props, landmarks, signage) and finish Whiskerwood.
2. Race manager + AI (M3).
