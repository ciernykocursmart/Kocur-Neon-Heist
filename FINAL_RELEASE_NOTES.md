# KOCUR: NEON HEIST — v1.0.0 Release Candidate 1

**Build:** `build/windows/KocurNeonHeist-windows-x86_64.zip` (Windows x64, single
self-contained `KocurNeonHeist.exe` + `README.txt` + `LICENSE_GODOT.txt`)
**Engine:** Godot 4.3-stable, Compatibility (OpenGL 3.3) renderer
**Status:** feature-complete release candidate, ready for Microsoft Store
packaging (MSIX), code signing and a final human QA pass.

---

## What's in v1.0

* **Campaign:** 12 missions in three acts (Infiltration, Escalation, Black
  Site) with briefings, 12 hidden intel fragments, a three-stage finale
  (uplinks → WARDEN boss → archive → lockdown escape), an epilogue and credits.
* **Endless Heist:** unlocked after the campaign; procedurally escalating
  contracts with a saved best depth.
* **Stealth:** vision cones, awareness meters, hearing, shadows, silent
  takedowns, body discovery, yarn decoys, cameras, motion-sensor floors,
  alarm escalation with reinforcements and a pay penalty for alarms.
* **Combat:** 3 weapons (Whisper pistol, Hailstorm SMG, Thunderclaw shotgun),
  claw melee, dash with i-frames.
* **Enemies:** Drone, Guard, Hunter, Enforcer, and the WARDEN boss.
* **Progression:** 12 multi-level upgrades, weapon unlocks, intel archive,
  stats.
* **Facilities:** procedurally assembled from 16 room templates in 3
  environment themes. Every layout is verified reachable.
* **Content:** fully original. All visuals, sound effects and three music
  tracks are generated procedurally.

## Changes in Phase 3 (release-candidate pass)

### Windows release readiness
* The exe now carries the **cat icon (7 sizes) and full version metadata**
  (product "KOCUR: NEON HEIST", company, FileVersion/ProductVersion 1.0.0.0,
  original filename). Added `tools/patch_windows_exe.mjs`, a pure-JS
  PE resource editor based on `resedit`, which needs no rcedit or wine. It
  patches the export *template* before export, so Godot's embedded PCK
  section stays intact. Verified by reading the resources back and booting
  the embedded pack.
* One-command build: `tools/build_windows.sh` (stamp → export → restore
  template → zip with README and the Godot MIT licence). CI uses the same
  script and also fails on any runtime `SCRIPT ERROR`.
* `.gdignore` for `tools/` and `build/`; `tools/` is excluded from the
  exported pack.

### WARDEN boss
* Validated with a new **combat bot** (`tests/boss_bot.gd`) that strafes,
  dodges with dash, switches weapons by range and reloads. The original
  boss died in 17–24 s even to an un-upgraded cat. After several tuning
  rounds the WARDEN now has 2200 HP (was 1300), deals 8 damage per bullet
  (was 9), and has a 1.2 s **phase-change shield** so phase transitions
  read as dramatic beats.
* Final measured curve: a typically upgraded cat (about 1.4k CR of
  upgrades) wins **5/5** fights in 37–55 s, finishing with 24–127 of 150 HP;
  an un-upgraded cat loses **0/3**, leaving the boss at 28–37% HP. The suite
  requires the typical bot to win at least 2/3 fights and the un-upgraded
  bot not to win trivially.
* Fixed: the boss trigger ignored the floor where the two arena rooms are
  merged, so standing in the arena centre didn't wake the WARDEN.

### Performance
* New performance probe: largest Act III facility, full alarm, two
  reinforcement waves (27+ enemies). Logic averages about 2.5 ms per physics
  tick, about 1.5 ms per frame overall.
* Worst-case tick spikes cut from about 10 ms to about 5–7 ms. Vision-cone
  raycasts, body checks and repaths are now staggered across enemies instead
  of all firing on the same tick; the enemy list is shared once per tick.
* Fixed an edge case where an enemy chasing an unreachable, moving target
  could re-run A* every tick.

### Audio
* Automated level analysis of every generated sound. Added a peak limiter,
  so no sound can clip (the shotgun did before).
* Made the Enforcer's laser-charge warning and the reinforcement warp-in
  clearly audible. These are important gameplay cues and were among the
  quietest sounds. Toned down explosions slightly.

### Combat & feel
* Hit marker at the crosshair when shots land (red on a kill).

### Tests
* The suite now has about 1,480 checks, adding WARDEN balance, the
  performance probe, audio levels and the finale checkpoint. Several flaky
  test setups were made deterministic.

## Known issues / limitations
* Acts II–III and the WARDEN have been balanced with bots and maths, not yet
  by human players.
* Audio levels are verified numerically, but nobody has listened to the mix
  on real speakers.
* Keyboard and mouse only (no gamepad, no remapping); English only.
* The exe is not code-signed yet (expected before store submission; unsigned
  builds can trigger SmartScreen or antivirus heuristics).
* No fog of war, and bodies can't be moved (by design for v1.0).

## Next step
MSIX packaging and code signing — see `RELEASE_CHECKLIST.md` sections 5–7.
