# KOCUR: NEON HEIST

A top-down neon cyberpunk stealth/action game about a small cybernetic cat
who robs a sinister security corporation one facility at a time, uncovers
what it did to her, and brings the whole thing down.

* **Engine:** Godot 4.3 (GDScript, Compatibility/OpenGL renderer)
* **Platform:** Windows x86_64 (runs on Linux too)
* **Length:** 12-mission campaign in three acts (about 2–4 hours) + Endless Heist mode
* **Target price:** €4.99
* **Assets:** every visual, sound and music track is generated procedurally at
  runtime. The project has no third-party art, audio or fonts.

---

## Story

ARGUS Consolidated builds and runs automated security for half of Lumen City.
Under the codename **PROJECT LULLABY** it fitted animals with neural implants
and used their instincts to train **WARDEN**, the security AI behind every
ARGUS guard, drone and camera.

Subject 07, a small black cat the lab staff called **KOCUR**, escaped. A
fixer called **MOTH** pays Kocur to rob ARGUS facilities. Each job pulls
another piece of LULLABY into the light and leads, finally, to **CRADLE**:
the black site that holds WARDEN's core and forty other subjects asleep in
cryostasis.

The story is told without cutscenes. It comes through mission briefings from
MOTH, one hidden **intel fragment** per mission (collected into the Hideout's
intel archive), the final archive reveal and a short epilogue.

## Gameplay

**Infiltrate → explore → hack → sneak or fight → steal the data → reach EVAC → get paid → upgrade → next contract.**

* **Stealth** is a real option. Guards have vision cones and awareness meters
  (`?` means suspicious, `!` means alerted). They hear footsteps, gunshots and
  failed hacks. **Shadows** make a sneaking or still cat almost invisible.
  **Silent takedowns** from behind kill instantly. A spotted guard needs a
  moment to radio it in (red ring), so killing him before the ring fills
  stops the alarm. Bodies left in the light **get found**.
* **Alarms have consequences:** every unit converges, reinforcements warp in
  (more and tougher with each alarm), the music speeds up, and every alarm
  cuts the contract pay by 15% (up to 45%). Finishing a contract without an
  alarm pays a +50% **ghost bonus**.
* **Hacking** is a timing-ring mini-game (lock the cursor in the green window).
  Misses make noise, and too many misses leave a trace. Hackable systems:
  security doors, cameras, terminals (camera loop / door override / credit
  skim), alarm panels (cancel the alarm and switch off motion sensors), data
  cores, shards and uplinks.
* **Combat** is fast and readable: three weapons, a claw, a dash with
  i-frames, hit flashes, flinching enemies, damage numbers, shell casings,
  muzzle flashes, hit-stop and screen shake.
* **Gadget:** the yarn-ball decoy (3 per mission) lands where you aim and
  squeaks three times, pulling guards away.

## Controls

| Action | Input |
| --- | --- |
| Move | `W A S D` / arrows (physical keys, so QWERTZ/AZERTY work) |
| Aim / fire | Mouse / left button |
| Reload | `R` |
| Switch weapon | `1` `2` `3`, mouse wheel, `Q` (last weapon) |
| Claw / takedown | Right button / `F` |
| Dash | `Space` |
| Sneak | Hold `Shift` |
| Hack / interact / confirm | `E` |
| Yarn decoy | `G` |
| Hack: lock / abort | `E`, left button or `Space` / `Q`, right button or `Esc` |
| Pause | `Esc` / `P` |

The controls are also listed in-game (**Main menu → Controls**,
**Pause → Controls**).

## Weapons

| # | Weapon | Role | Feel |
| --- | --- | --- | --- |
| 1 | **VX-9 Whisper** | Precision | Accurate, quiet, 24 damage, **double damage against unaware targets**. Available from mission 1. |
| 2 | **Hailstorm SMG** | Automatic | 13 rounds/s, wide spread, 32-round magazine. Shreds drones and groups. Unlocked at mission 3. |
| 3 | **Thunderclaw** | Heavy close range | 8-pellet blast, big knockback and recoil, short range, slow reload. Breaks shields. Unlocked at mission 5. |

Each weapon keeps its own magazine and reserve, and has its own sound,
muzzle flash, tracer colour, recoil, shake and noise level. Ammo pickups
refill every weapon you carry.

## Enemies

| Enemy | Detection | Behaviour |
| --- | --- | --- |
| **Patrol Drone** | 360° short-range sensor | Fast and fragile. Orbits you while firing quick pellets. |
| **Security Guard** | Forward cone | 3-round bursts, strafes, radios the alarm in, searches when it loses you. |
| **Elite Hunter** (from mission 4) | Long, wide optics | Regenerating shield, shotgun, gap-closing dashes, searches relentlessly. |
| **Enforcer** (from mission 5) | Very long, narrow cone; turns slowly | The armoured front blocks 70% of damage. Fires a telegraphed laser (watch for the red line) for heavy damage. Flank it or take it down from behind. |
| **WARDEN** (finale boss) | Always aware | 2200 HP over three phases: aimed volleys and bullet rings, then drone escorts, then ramming charges and double rings, with a brief shield at each phase change. Immune to takedowns. |

## Progression

**12 upgrades** are bought with credits at the Hideout (multiple levels
each, about 8,800 CR to max everything):

Armor Plating (+max HP) · Nano-Repair Weave (health regen) · Servo Legs
(speed) · Phase Dash (cooldown, silent dash) · Ghost Step (sneak speed and
stealth) · Optic Camo (slower detection) · Plasma Rounds (damage) · Extended
Mags · Reflex Booster (reload) · Whisper Suppressor (gun noise) ·
Monofilament Claws (melee damage and reach) · Neural Hack Suite (hack window,
spare miss).

Weapons unlock as the story progresses, and the Hideout's **Armory** tab shows
live, upgrade-adjusted stats. **Intel** tab shows every recovered story fragment.

## Campaign structure

| Act | Missions | Focus |
| --- | --- | --- |
| **I — Infiltration** | 1–4 | Teaches sneaking, takedowns, shadows, hacking, cameras, decoys, alarms, weapons and Hunters. Small facilities (3×2 to 4×2 sectors). Accessible. |
| **II — Escalation** | 5–8 | Enforcers, multi-core objectives (2–3 data shards), bigger and more complex facilities (up to 5×3), tougher mixes. Moderate to challenging. |
| **III — Black Site** | 9–12 | CRADLE: the largest facilities (up to 5×4), every enemy type, heavy security. Hard. |
| **Finale** | 12 | Breach 3 security uplinks to unseal the core → the vault slams shut → defeat the **WARDEN** (supplies drop in) → download the **LULLABY archive** (the truth) → **lockdown** escape to the roof under a permanent alarm → epilogue and credits. |

Facilities are assembled procedurally from **16 room templates** (offices,
server farms, labs, vaults, tunnels, hangars, archives, security hubs,
canteens, hydroponics, reactor, the WARDEN vault, and more). There are three
environment themes (corporate cyan, industrial orange, black-site red). A new
game reshuffles every layout while keeping the designed difficulty curve.

## Endless Heist

Finishing the campaign unlocks **Endless Heist** (main menu or Hideout).
Each contract goes one level deeper: bigger facilities, more and tougher
enemies, alternating single-core and multi-core objectives, larger
reinforcement waves and higher pay. Your best depth is saved. Credits and
upgrades carry over, and dying just retries the current contract.

## Running the project

1. Install **Godot 4.3** (standard build, not .NET).
2. Open Godot → *Import* → select `project.godot` → *Import & Edit*.
3. Press **F5**. The main scene is `scenes/main_menu.tscn`.

Nothing has to be set up: input actions, audio buses, the theme, every sound
and every visual are created in code.

```bash
godot --path .                                           # play
godot --headless --path . -s res://tests/run_tests.gd    # test-suite
```

## Exporting the Windows build

**Recommended: one command.**

```bash
tools/build_windows.sh /path/to/godot     # needs Node.js 18+ and Python 3
```

The script:
1. stamps the cat icon (`icon.ico`, 7 sizes) and version metadata (product
   name, company, file/product version from `project.godot`) into a copy of
   the Godot release template using `tools/patch_windows_exe.mjs`. This is
   pure JavaScript (`resedit`), so it works on Linux CI without rcedit or wine.
   Patching the *template* before export keeps Godot's embedded PCK section
   intact;
2. exports with the **"Windows Desktop"** preset (release, x86_64, PCK
   embedded, tests, build output, docs and CI files excluded);
3. restores the original template and zips the `.exe` with `README.txt` and
   Godot's MIT licence (`LICENSE_GODOT.txt`).

Manual alternative: *Editor → Manage Export Templates → Download and
Install* (4.3), then *Project → Export… → Windows Desktop*. This works, but
the exe keeps Godot's default file icon (the in-game window still shows the
cat icon).

The release candidate is committed as
**`build/windows/KocurNeonHeist-windows-x86_64.zip`**. The CI workflow
(`.github/workflows/build.yml`) runs the tests and builds the same zip as a
workflow artifact.

### Microsoft Store package (MSIX)

`tools/build_msix.sh /path/to/makemsix` packs the Windows build into
**`build/msix/KocurNeonHeist_1.0.0.0_x64.msix`**. It uses the identity
`59513Lukes.KocurNeonHeist`, publisher
`CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`, x64, Windows 10 1809+ and
`runFullTrust`. The package is unsigned (Partner Center signs Store
submissions). The manifest template and tile logos live in `store/msix/`.
`makemsix` comes from Microsoft's open-source
[MSIX SDK](https://github.com/microsoft/msix-packaging) (`./makelinux.sh --pack`);
on Windows, `MakeAppx pack` works the same way. Store texts, screenshots
(1920×1080) and promo art are in `store/` (`STORE_LISTING.md`;
`NAVOD_PUBLIKOVANIE_SK.md` is the step-by-step upload guide in Slovak).

Save data and settings live in `%APPDATA%\KocurNeonHeist\`
(`~/.local/share/KocurNeonHeist` on Linux). Saves are written atomically
with a backup copy.

## Project architecture

```
project.godot / export_presets.cfg / icon.svg / icon.ico
scenes/            main_menu, game, hideout, ending (thin; content built in code)
scripts/
  autoload/
    game_state.gd  GameState: campaign/endless progress, credits, upgrades,
                   weapons, intel, stats, derived player stats, settings,
                   input map, atomic save/load with backup + migration
    sfx.gd         Sfx: procedural synthesis of all SFX + 3 music loops
    transition.gd  Transition: fade between scenes
  core/            palette, fx (particles, lights, rings, shells, text),
                   ring_effect, vision_cone, ui_theme, weapons (weapon data)
  world/           room_templates (16 rooms), facility_generator (slot grid,
                   spanning tree, doors, arena merge), facility (tiles,
                   collision, A*, LOS, zones, shadows, themes, rendering)
  actors/          player, bullet, enemy (base AI), enemy_guard,
                   enemy_drone, enemy_hunter, enemy_enforcer, enemy_warden
  objects/         hackable (base), security_door, security_camera,
                   terminal, alarm_panel, data_core (data/shard/uplink/
                   archive), intel_fragment, decoy, pickup, extraction_pad
  systems/         game (mission controller), campaign (story + mission
                   table), mission_catalog (campaign + endless defs),
                   alarm_system, game_camera
  ui/              hud, hack_overlay, pause_menu, end_screen, settings_panel,
                   controls_panel, main_menu, hideout, ending, neon_background
tests/             run_tests.gd + test_suite.gd (headless suite), boss_bot.gd
                   (WARDEN combat bot), tick_probe.gd (perf), screenshot tour,
                   write_godot_license.gd
tools/             build_windows.sh, patch_windows_exe.mjs (icon/version)
```

**Data flow.** `GameState` builds the current mission definition
(`MissionCatalog` → `Campaign` table or the endless formula).
`FacilityGenerator` turns it into a layout, `Facility` renders it and
provides navigation, and `Game` spawns actors and objectives from the room
markers. Actors talk back through a small API on `Game` (`emit_noise`,
`spawn_bullet`, `on_core_hacked`, `on_enemy_killed`, `notify`, …) and the
`AlarmSystem`. When a mission ends, `Game` builds a result dictionary and
`GameState.complete_mission` pays out, advances progress and saves.

**Extending.**
* *Room:* append a 15×11 ASCII template to `RoomTemplates.TEMPLATES` (the
  tests verify size, clear door areas and reachability).
* *Mission:* edit `Campaign.MISSIONS` (all difficulty knobs are data).
* *Weapon:* add an entry to `Weapons.DATA`/`ORDER` and an unlock in
  `GameState.WEAPON_UNLOCK`.
* *Enemy:* extend `Enemy` (`_configure`, `_draw_body`, optionally
  `_combat_move`, `_try_fire`, `_absorb`) and spawn it in `Game._populate`.
* *Upgrade:* add it to `GameState.UPGRADES`/`UPGRADE_ORDER` and use its level
  in a stat helper.

## Testing

`godot --headless --path . -s res://tests/run_tests.gd` runs about 1,450
checks and exits with code 1 on any failure (CI additionally fails on any
runtime `SCRIPT ERROR`):

* every script compiles and every scene loads;
* room templates: size, clear doorways, centre markers;
* **240 generated facilities** (all 12 campaign missions and endless
  depths): every room and marker reachable, vaults sealed, every finale has
  its merged WARDEN arena;
* campaign data: 12 missions, 3 acts × 4, rewards and threat rise
  monotonically, each mission has a briefing and intel, sane enemy density;
  endless scaling and caps;
* upgrades (rules, caps, costs, effects) and save/load (memory and disk);
* **save robustness:** v1 → v2 migration, malformed fields, sanitised
  intel, corrupt main save → backup recovery, missing save;
* menus, hideout and ending scenes load;
* mission win flow, death → game over → retry with the same layout;
* hacking (success, failure, traces), door navigation, alarm broadcast,
  reinforcements, alarm panels, guard detection, takedowns;
* combat (player bullets, hunter shield, enemy fire), **weapons**
  (unlocks, switching, separate ammo, shotgun spread, reload, ammo packs,
  pistol sneak bonus, Enforcer frontal armour);
* **stealth features** (shadow visibility, decoy lure, body discovery,
  intel pickup and reader);
* **campaign completion and Endless mode** (unlock, depth, best, mission
  load and completion);
* **WARDEN balance:** a combat bot (strafes, dodges with dash, picks weapons,
  reloads) fights the boss for real. A typically upgraded cat must win at least 2 of 3
  fights (each at least 25 s long), and an un-upgraded cat must not win trivially. A finale
  checkpoint test is included;
* **performance:** the largest Act III facility under full alarm with two
  reinforcement waves (27+ enemies) must stay under 4 ms of scripted logic
  per physics tick on average and 12 ms worst case;
* **audio levels:** every synthesised sound is clip-free and key gameplay
  cues (detection, alarm, Enforcer laser charge, reinforcements, …) are
  loud enough;
* a **physics bot playthrough of all 12 campaign missions**. It walks the
  cat with real collision to every core, breaches the uplinks, fights the
  WARDEN, reads the archive, survives the lockdown and reaches EVAC, which
  completes the campaign.

`xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/run_screenshots.gd`
renders every screen to PNG for visual QA.

## Known limitations

* Balance has been checked by automated runs (combat bot, economy maths) and
  the earlier human playtest of the prototype. Acts II–III and the WARDEN
  fight still need a human balance pass.
* No gamepad support yet; keyboard and mouse only, no key remapping.
* Bodies can't be dragged. Hide takedowns by doing them in shadows.
* There is no fog of war; the whole facility is visible and threat is shown
  through vision cones.
* English only.
* The Windows build is not code-signed and there is no MSIX package yet;
  that is the next step (see `RELEASE_CHECKLIST.md`).
* Audio levels are measured automatically (no clipping, audible cues), but
  nobody has listened to the mix on speakers yet.

## License / assets

All code, visuals, sounds and music in this repository are original and
procedurally generated; no third-party assets are included. Godot Engine is
MIT-licensed (include its licence text with distributed builds; see the
release checklist).
