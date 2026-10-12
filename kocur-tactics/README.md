# Kocur Tactics

A turn-based pixel-art tactics game by Kocur Studios, made with Godot 4.3 for Windows x64.
Lead a squad of black cats against the white-cat **White Crown Legion**: 12 campaign missions
in 3 acts, two boss fights (the Ironpaw Commander and the two-phase Pale King), 3 tactical
challenges, hero progression and three difficulty levels. Fully offline.

## Play (Windows)

1. Unzip `KocurTactics-windows-x86_64.zip` anywhere.
2. Double-click `KocurTactics.exe` (SmartScreen: "More info" -> "Run anyway"; the exe is not code-signed).

Requirements: Windows 10/11 64-bit, OpenGL 3.3 graphics. No install, no internet.

Saves: `%APPDATA%\KocurTactics\save.json` (campaign) and `settings.cfg` (volume, display, speed).
The game saves after every battle result, every upgrade purchase and every difficulty change.

## Controls

| Input | Action |
|---|---|
| Left click hero | Select it (blue tiles = where it can move) |
| Left click blue tile | Move there (the drawn path is the path taken) |
| Left click enemy | 1st click aims and shows the exact damage, 2nd click confirms |
| Right click / Backspace | Cancel aim, then undo an uncommitted move, then deselect |
| 1-4 | Choose ability |
| F | Interact: Free a captive, Claim a relic, Escape on an exit |
| W | Wait (hero is done for this turn) |
| Z | Undo the move (before acting) |
| Tab | Next hero that can act |
| Space | Confirm the aimed action |
| T | Show every tile enemies can attack next turn |
| Enter / E | End turn (asks first if heroes can still act) |
| Esc | Pause menu: Resume, Restart, Settings, Controls & Rules, Return to Campaign, Quit to Menu |

## Rules

- **Turns:** each hero may **move once, then act once** (attack, ability, interact or wait). No moving after acting.
  Then every awake enemy acts, one by one, in a fixed order (casters, ranged, guards, melee, flankers).
- **Damage** is deterministic: `ATK + ability bonus + situational bonuses - (DEF + cover + buffs)`, minimum 1.
  No dice and no critical hits; the preview is exactly what happens.
  - Flanking: melee attacks get +2 when another ally of the attacker is next to the target (enemies flank too).
  - Steady: an unmoved Ranger's shots get +2. Ambush: Stalkers get +2 against a hero with no ally next to it.
- **Line of sight:** walls and pillars block ranged attacks and pounces; forest, water and units do not.
- **Terrain:** forest (+1 DEF, costs 2), mud/snow (costs 2), hill (+1 range for ranged attacks, costs 2),
  water (impassable, see-through), walls/pillars (impassable, block sight),
  thorns/caltrops/embers (3 damage at the start of that side's turn), bridges and roads.
- **Movement:** walk through allies, never through enemies; never end on an occupied tile.
- **Knock-outs:** a hero at 0 HP is out for the rest of that battle and returns at full health next battle. Nobody is lost.
- **Sleeping enemies (Zz)** wake when a hero comes within the mission's alert range or one of their group is hit.
- **Telegraphs:** orange hatched tiles with "!" mark a boss attack landing at the start of the next enemy turn.
  A red X marks where reinforcements arrive during this enemy phase.

## Heroes

| Hero | Class | HP/ATK/DEF/MOV | Abilities |
|---|---|---|---|
| Nox (start) | Shadowblade | 20/7/1/5 | Claw Strike (adjacent, ATK); Shadow Pounce (leap up to 3 tiles with line of sight, onto an empty tile or beside an enemy for ATK+2, cooldown 2) |
| Bramble (start) | Guardian | 30/6/4/3 | Strike (ATK); Heavy Strike (ATK+4, only if he has not moved); Protective Stance (+3 DEF self, +2 DEF to adjacent allies until his next turn, cooldown 1) |
| Willow (start) | Ranger | 16/6/0/4 | Aimed Shot (range 2-5, line of sight, +2 if not moved); Volley (target 2-4 away: that tile + 4 neighbours, ATK-1, never hits allies, cooldown 2) |
| Moss (rescued in M03) | Mender | 18/4/1/4 | Paw Swipe (ATK); Mend (heal an ally within 3 for 8, cooldown 1) |
| Soot (joins after M06) | Shadowblade | as Nox | as Nox |
| Pepper (rescued in M08) | Ranger | as Willow | as Willow |

## Enemies and bosses

| Enemy | HP/ATK/DEF/MOV | Behaviour |
|---|---|---|
| White Recruit | 10/5/0/4 | Melee; goes for reachable, weak or isolated heroes |
| White Guard | 16/5/3/3 | Shield Wall: adjacent allies +1 DEF; escorts archers and mages, holds the line |
| White Archer | 10/5/0/4 | Arrow range 2-4 with line of sight; keeps distance, likes hills, avoids melee |
| White Mage | 11/4/0/3 | Frost Bolt (range 2-4, chills: -2 MOV next turn); Pale Blessing heals allies for 6 |
| White Stalker | 12/5/1/6 | Ignores terrain costs; Ambush +2 vs isolated heroes; hunts the back line |
| **Ironpaw Commander** (M06, C3) | 52/8/4/3 | Marks 3 tiles for a Crushing Blow (ATK+6) that lands next enemy turn, then is **Exhausted (DEF 0)** for a turn. At half HP raises **Iron Guard** (+3 DEF for 2 turns) and calls 2 guards (once). |
| **The Pale King** (M12) | 70/8/2/3 | Phase 1: on his throne, **immune while two Crown Pylons stand**; Royal Lance (ATK+4) on a marked row/column; telegraphed summons of recruits. Phase 2 at half HP: leaves the throne, calls 2 stalkers, casts a marked 3x3 **Pale Nova** (ATK+4) and is then **Drained (DEF 0)**. |

## Campaign

| # | Mission | Objective type |
|---|---|---|
| Act I - Shadowwood Valley | | |
| 1 | Whiskers in the Woods | Eliminate (tutorial) |
| 2 | Mill Bridge Skirmish | Eliminate (bridges, Shield Wall) |
| 3 | Rescue at Mosswell | Rescue + escape (free Moss, bring her to an exit) |
| 4 | Shadowwood Shrine | Defend tiles for 6 turns |
| Act II - The Broken Border | | |
| 5 | Over the Border Wall | Reach extraction (all heroes escape, turn limit 12) |
| 6 | Ironpaw's Bastion | Boss: Ironpaw Commander |
| 7 | The Moonwell | Protect a fragile objective for 7 turns |
| 8 | The Border Keep | Defeat a named commander (Captain Snowcap), free prisoners |
| Act III - The White Crown War | | |
| 9 | The Burning Orchard | Survive 7 turns of waves |
| 10 | The Elder's Escape | Escort the Elder to an exit (turn limit 15) |
| 11 | The Pale Gate | Claim 3 relics (turn limit 18) |
| 12 | The Pale Throne | Final boss: the Pale King (2 phases) |

Tactical challenges (fixed squads, unlocked after M04, M08 and M12): Bridge of Fools (8-turn limit),
Night of Stalkers (survive 6 turns), Iron Rematch (Ironpaw in 12 turns).

## Progression and replay

- **XP** on the first clear of a mission: deployed heroes 40 + 10 per KO (max +30), heroes in reserve 20.
  100 XP per level, max level 6; each level +2 HP, +1 ATK at levels 3 and 5.
- **Relic Shards** from first clears and optional objectives, spent on **upgrades** per hero:
  Vitality (+3 HP, 3 ranks), Sharp Claws (+1 ATK, 2 ranks), Thick Fur (+1 DEF, 2 ranks), Swift Paws (+1 MOV),
  Class Mastery (Pounce +1 range/+1 damage; Stance no cooldown and +3 to allies; Volley cooldown 1; Mend +4).
- **Recruits:** Moss (M03), Soot (M06), Pepper (M08). The campaign is winnable with the starter trio plus recruits; no grinding needed.
- **Optional objectives** (2 per mission) and **medals**: Bronze = win, Silver = one optional, Gold = both.
  Replays never repeat XP or mission shards; only newly achieved optional objectives pay, and medals never go down.
- **Difficulty** (any time in Settings): Story (enemies -2 ATK, 80% HP), Normal, Hard (+1 ATK, 120% HP).
- Records tab: completed missions, best turns, medals, battles won/lost. Ending screen after M12.

## Open and build the project

```bash
# Open in the Godot 4.3 editor: Import -> kocur-tactics/project.godot
godot --path kocur-tactics                    # run the game from source
cd kocur-tactics
tools/run_tests.sh                            # all automated tests (+ restart persistence check)
godot --headless --path . -s res://tests/sim.gd   # AI autoplays every mission and prints results
tools/build_windows.sh                        # Windows x64 export + ZIP + smoke test of the exported pack
python3 tools/gen_art.py && python3 tools/gen_audio.py   # regenerate all pixel art and audio (PIL + numpy)
```

`.gdignore` keeps the parent Neon Heist project from importing this folder; open `kocur-tactics/` itself.
Export needs the Godot 4.3.stable export templates.

## Project layout

```
scripts/core/      grid.gd (terrain, LOS, Dijkstra/A*), unit.gd, battle.gd (rules, turns, objectives),
                   ai.gd (utility AI), bosses.gd (Ironpaw, Pale King)
scripts/data/      units_data.gd (classes, enemies, abilities, upgrades, difficulty), missions.gd (12 + 3 maps)
scripts/autoload/  settings, save_manager, campaign (progress), audio_manager, transition
scripts/battle/    battle_scene (controller + event playback), battle_hud, map_view, unit_view
scripts/ui/        main_menu, campaign_screen, settings_panel, ending, ui_kit
scenes/            main_menu, campaign, battle, ending
assets/            generated sprites (77 PNG) and audio (36 SFX + 8 music tracks)
tests/             run_tests.gd + suites/, sim.gd, restart_check.gd, shot.gd (screenshots)
tools/             gen_art.py, gen_audio.py, run_tests.sh, build_windows.sh, pack_smoke.gd
```

The rules engine (`battle.gd`) is pure logic with no nodes: player commands are validated there, it emits an
event list, and the battle scene only plays those events back. Animations can therefore never trigger extra actions,
and the same engine drives the automated tests and the AI autoplayer.

## Credits

Design, code, pixel art, sound and music: Kocur Studios (generated by the project's own tools).
Godot Engine (MIT licence) - see `LICENSE_GODOT.txt`.
