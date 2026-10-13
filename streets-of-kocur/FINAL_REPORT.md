# Streets of Kocur - Final Report

Kocur Studios | Godot 4.3 | Windows x64 | version 1.0.0 | 2026-10-13

## Summary

Streets of Kocur is a complete short arcade beat 'em up. Kocur, a black alley cat
with a red scarf, fights the White Crown gang of white cats through six streets,
beats three lieutenants and defeats the enormous Lord Lardpaw. It has a full menu
flow, three difficulties, scoring and ranks, checkpoints, continues, a versioned
save, an ending, keyboard and gamepad controls, and original code-drawn art and
generated audio. All six streets were played to the end by an automated bot;
**no human has played it yet** and **the .exe has not been run on Windows**.

## The six levels

| # | Street | Environment | Content |
|---|---|---|---|
| 1 | Alley Trouble | red-brick back alley, fire escapes, crates and trash cans | 5 fights, tutorial hints, punks and a brawler |
| 2 | Market Mayhem | sunny market, striped stalls, bunting | 6 fights, runners, breakable stalls |
| 3 | Neon Boulevard | night city, neon signs (SUSHI, CLAW CLUB) | barriers, electric puddles, throwers, **Slick Whiskers** |
| 4 | Industrial Paws | warehouse yards, pipes, hazard stripes | crate walls, hydraulic presses, enforcers, **Big Bruno Boltpaw** |
| 5 | White Crown Headquarters | white palace halls with crown banners | Front Gate, Courtyard, Kitchens, Guard Hall, Lift Lobby, Armory, **General Snowmane** |
| 6 | The Fat Cat Showdown | the gang's pantry full of stolen food | Bodyguards, Kitchen Guard, **Lord Lardpaw** |

## Player moves and combo

Walk/run on the street plane (horizontal + depth), jump, `J J J` combo (paw jab,
claw swipe, knock-down WHAM) with a short timing window and a forced end after the
finisher, flying kick, running pounce, PAWQUAKE spin (invulnerable, costs one of
two energy bars), grab with knees and a throw that bowls over other cats. Hit
invulnerability, knockback and an automatic knock-down after 3 chained hits stop
stun-locks. Every attack activation hits each target once; hit tests use ground
position, depth and height, never sprite overlap.

## Enemies and bosses

* **White Street Punk** - basic melee, punch or kick.
* **White Brawler** - tough, shrugs off the first light hit, haymaker + uppercut.
* **White Runner** - fast, flanks to the side, lunging kick, runs off.
* **White Thrower** - keeps distance and throws bottles; scratches up close.
* **White Enforcer** - armored, telegraphed slam with a red zone, charge that
  leaves him dazed against a wall, cannot be grabbed.
* **Slick Whiskers** (Street 3 lieutenant) - dash, fishbone fan, claws; punks at 50%.
* **Big Bruno Boltpaw** (Street 4 mini-boss) - slam + shockwave, shoulder charge, sweep; runners at 50%.
* **General Snowmane** (Street 5) - lunge, Banner Spin, Crown Leap; reinforcements at 66% and 33%.
* **Lord Lardpaw** (final boss) - Belly Bounce, Rolling Charge, Paw Slam; bodyguards
  at 66%; Food Frenzy at 33%. Every move is telegraphed with its own sound, ends
  in an "OPEN!" window, and the boss bar shows the phase marks.

## Food, health, score and progression

Health 100. Fish +20, chicken +40, cat food can +70 (capped; points at full
health). Breakable crates, barrels, trash cans, stalls; one Golden Fish per street
(+3000, full special meter). Lives 5 / 3 / 2 (Easy / Normal / Hard), continues
unlimited / 3 / 2 per street, extra life every 40,000 points. Score from enemies,
hits, 5+ combos, bosses, items and end-of-street bonuses; rank S-D and an optional
challenge per street. Checkpoint after every fight; eaten food and broken props
stay gone after a continue. Save keeps unlocks, completions, best scores and
ranks, golden fish, challenges, campaign completion, statistics and the current
run; settings are a separate file.

## Automated test results (real runs)

* `tools/run_tests.sh`: **66 tests, 66 passed, 928 assertions** (integrity 6,
  player 13, combat 14, food 9, campaign 12, save/UI 12).
* Two-process save/restart check: **PASS** (12/12).
* Exported pack smoke test: **PASS** (72/72) + restart **PASS** (5/5).
* Bot campaign runs: Easy and Normal completed (Normal with 2 continues), Hard
  completed 5 of 6 streets (game over at Big Bruno).
* 5 defects found by the new tests were fixed (combo chain, lunge through target,
  throw hitbox, boss encounter state, checkpoint index). Details in TEST_REPORT.md.

## What was verified in the Windows build

The Windows export succeeded and the ZIP contains the .exe (PCK embedded),
README.txt and the Godot licence. The game data inside the .exe was loaded with
the Linux Godot binary and played headless: all scenes and 6 streets load, all
audio files load, a combat encounter was completed, a food pickup healed 30 -> 70,
Street 1 was cleared and "Next street" loaded Street 2, and a second process read
the save back. **The .exe itself was not started here; no Windows, GPU or sound card
was available.** Afterwards NEO played the whole campaign on Windows on 2026-10-13 and reported it as perfect; the individual checklist rows were not filled in.

## Microsoft Store kit

`store/` holds the Store kit: `msix/AppxManifest.xml` (identity
`59513Lukes.StreetsOfKocur`, DisplayName "Streets Of Kocur"), the tile logos,
3 key art images, 10 screenshots at 1920x1080, `STORE_LISTING.md` (EN + SK) and
`NAVOD_PUBLIKOVANIE_SK.md`. `tools/build_msix.sh` builds the unsigned
`StreetsOfKocur_1.0.0.0_x64.msix`; `tools/store_shots.sh` regenerates every image.
The .exe now has the Kocur icon and version info. The .msix was not installed
on Windows and WACK was not run.

## Paths (in the repository `ciernykocursmart/Kocur-Neon-Heist`)

* Source project: `streets-of-kocur/` (open `streets-of-kocur/project.godot`)
* Windows build (generated, not committed): `streets-of-kocur/build/windows/StreetsOfKocur-windows-x86_64.zip`
  and `streets-of-kocur/build/windows/StreetsOfKocur.exe`; inside the ZIP:
  `StreetsOfKocur/StreetsOfKocur.exe`
* Delivered copies: `/mnt/project-files/streets-of-kocur/StreetsOfKocur-windows-x86_64.zip`
  and the documents and `screenshots/` next to it; the Store kit and .msix in
  `/mnt/project-files/streets-of-kocur/store/`
* Docs: `streets-of-kocur/README.md`, `TEST_REPORT.md`, `KX_TEST_CHECKLIST.md`,
  `CHANGELOG.md`, `DEVELOPMENT_STATUS.md`, `FINAL_REPORT.md`

## Known issues and untested behaviour

* Not run on Windows; frame rate, fullscreen/resolution switching, audio output,
  gamepad and mouse play are untested by a human.
* Real playtime unknown; bot time is about 14 min on Normal, so the campaign may
  be shorter than the 45-90 minute target.
* Hard difficulty may be too hard (bot fails at Big Bruno); Normal balance and boss
  fairness need human judgement.

## Recommended KX test order

1. Section 1 (first launch and menus) and 15 (resolution and fullscreen) - can it run?
2. Sections 2-5 (movement, combo, jump attack, special) in Street 1 - does it feel good?
3. Sections 6-9 (enemies, crowds, food, death and restart) through Streets 2-4.
4. Sections 10-11 (all levels, mini-bosses), writing down the time per street.
5. Section 12 (Lord Lardpaw) and 17 (ending and replay).
6. Sections 13-14 (save and audio), then 16 (performance and collision) on the
   weakest PC available.
