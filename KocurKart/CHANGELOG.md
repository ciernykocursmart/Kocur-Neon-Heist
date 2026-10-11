# Changelog

## 1.0.0 – Release candidate (2026-10-11)

### Gameplay
- Arcade kart controller: speed-scaled steering, lateral grip, braking/reverse, two-level drift
  mini-turbos, Purr Boost meter, boost pads, ramp launches with arcade airtime, soft landings,
  wall-scrape assist that never spins the kart, kart-to-kart bumps, hazard knock-backs, recovery
  with brief ghosting, perfect start / wheelspin on the countdown.
- Surfaces: road, curbs, off-road verge, dirt shortcuts, ice.
- Chase camera with physics interpolation, speed FOV, landing dip, impact shake and scenery
  pull-in. Follow speed and distance are adjustable.
- Race rules: 3-2-1-GO countdown, ordered checkpoints (reversing undoes progress, skipping is never
  credited), lap and total timers, live positions from real progress, wrong-way warning, automatic
  respawn after falls or leaving the circuit, finish handling and estimated times for stragglers.
- AI: racing line with speed profile from real kart turning limits, drifting, Purr Boost use,
  shortcuts, overtaking/avoidance, hazard dodging, stuck recovery and personalities.
  Easy/Normal/Hard, with no rubber-banding.

### Content
- Six tracks with distinct themes and features: Whiskerwood Circuit (hairpin, S-bends, dirt
  path), Purrport Pier (open pier edges over water, crabs), Neon Catway (rooftop gap jump, drones),
  Frostpaw Pass (summit ice tunnel, ice sections, snowball), Sunset Safari (boulder chicane, dune
  jump, tumbleweeds, shortcut), Royal Catnip Run (moat gap jump, guards, garden shortcut).
- Three cups, a championship finale screen, Grand Prix / Single Race / Time Trial with a ghost.
- Six playable cats plus two rivals, three kart bodies with small balanced stat differences,
  paints, wheels and accessories, all unlockable through clear goals.
- Procedural low-poly art: karts, cats, props, landmarks, gates, grandstands with crowds,
  backdrops, corner chevrons. Original synthesised music (7 loops), ambience (6) and sound
  effects (28).

### Systems
- Versioned, atomic, sanitised save with backup recovery and a reset option. Settings for volumes,
  fullscreen, window size, VSync, frame cap, camera, minimap and key rebinding.
- Main menu with live 3D backdrop, garage, records and progress screen, credits, pause menu and
  results/standings/cup screens.

### Quality
- Headless test suite (7 modules) plus a `--autotest` mode that verifies the exported executable.
- Fixes found during testing: corner launches off road crests, AI clipping narrow ramps (ramps now
  span wall to wall), karts falling off embankments under the road (embankments now collide and
  "under the road" counts as off-track), respawn loops before jump gaps, wrong-way detection order,
  time display rounding (no more "1:60.000"), unsupported font glyphs, settings not written on
  first launch, and Godot scanning build output.
