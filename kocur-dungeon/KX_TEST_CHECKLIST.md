# Kocur Dungeon - KX Manual Test Checklist

For the KX tester, on a real Windows 10/11 x64 PC with `KocurDungeon-windows-x86_64.zip`.
Fill **Actual** and **Status** (PASS / FAIL / BLOCKED) for every row. Every row is
**PENDING** until a human has played it: nothing in this file has been verified manually.

Severity if it fails: **Blocker** (game unusable), **Critical** (core feature broken),
**Major** (clearly wrong, workaround exists), **Minor** (cosmetic / polish).

Recommended order: areas 1-3 first (launch, menus, settings), then 4-6 in level 1-1,
then play the campaign in order (8) while checking 7 and 9-14 as they come up, and finish
with 15-16. Report bugs with: area/row ID, level, what you did, what happened, screenshot.

Tester: ________  Date: ________  PC (CPU / GPU / Windows version / screen): ________________

## 1. Install and first launch

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 1.1 | Unzip KocurDungeon-windows-x86_64.zip to the Desktop and double-click KocurDungeon.exe. | Game starts (after a SmartScreen 'Run anyway' if shown) and the main menu appears within a few seconds, with menu music. |  | PENDING | Blocker |
| 1.2 | Check the window: title, size, icon in the taskbar. | Window titled 'Kocur Dungeon', 1280x720, crisp pixel art (no blur). |  | PENDING | Minor |
| 1.3 | Launch with no internet connection. | Game works fully offline. |  | PENDING | Major |
| 1.4 | Close with the window X button, then start again. | Closes cleanly; second start works. |  | PENDING | Major |

## 2. Main menu

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 2.1 | First launch (no save): look at the buttons. | Continue, Level Select and Upgrades are greyed out; New Game, Settings, Credits, Quit work. |  | PENDING | Major |
| 2.2 | Navigate with the mouse, then with arrows/Enter, then with a gamepad. | Focus highlight moves; every button reacts; sounds on move/confirm. |  | PENDING | Major |
| 2.3 | Open Credits, then Back (also try Esc). | Credits show Kocur Studios and the Godot licence note; returns to the menu. |  | PENDING | Minor |
| 2.4 | New Game -> read the intro -> Begin. | Story intro shown; level 1-1 starts. |  | PENDING | Blocker |
| 2.5 | With an existing save, press New Game. | A confirmation warns the save will be overwritten; No keeps everything. |  | PENDING | Critical |
| 2.6 | Quit. | Game exits. |  | PENDING | Major |

## 3. Settings and display

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 3.1 | Move Master / Music / Effects sliders. | Volume changes immediately; Effects plays a test coin sound. |  | PENDING | Major |
| 3.2 | Toggle Fullscreen on and off. | Switches between fullscreen and window without stretching artefacts. |  | PENDING | Major |
| 3.3 | Try every Window size (1280x720, 1600x900, 1920x1080, 2560x1440 if the screen allows). | Window resizes and stays centred; picture keeps 16:9 and stays sharp. |  | PENDING | Major |
| 3.4 | Change difficulty to Assist and to Hard; take a hit in a level each time. | Assist: half the damage; Hard: more damage than Normal. |  | PENDING | Major |
| 3.5 | Turn Screen shake off, get hit. | No camera shake. |  | PENDING | Minor |
| 3.6 | Open Controls page. | All controls listed match the real bindings. |  | PENDING | Minor |
| 3.7 | Restart the game. | All settings were remembered. |  | PENDING | Major |

## 4. Controls and movement

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 4.1 | In 1-1 run left/right with A/D and arrows. | Smooth acceleration and stopping; the cat faces the right way. |  | PENDING | Critical |
| 4.2 | Tap Space vs hold Space. | Tap = small hop, hold = high jump (about 3.5 tiles). |  | PENDING | Critical |
| 4.3 | Press jump just after running off a ledge, and just before landing. | Both jumps still happen (forgiving timing). |  | PENDING | Major |
| 4.4 | Walk into walls, ceilings, corners while jumping. | Never stuck in walls, never jitters, never falls through the floor. |  | PENDING | Critical |
| 4.5 | Pounce with K / right mouse; hold W and pounce. | Fast dash forward; with W the pounce goes upward; cooldown bar in HUD refills. |  | PENDING | Critical |
| 4.6 | Stand on a thin wooden platform, hold S and press Space. | The cat drops through. |  | PENDING | Major |
| 4.7 | Play with a gamepad (Xbox-style). | Stick/D-pad move, A jump, X claw, B pounce, Y interact, Start pause. |  | PENDING | Minor |

## 5. Combat

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 5.1 | Claw a White Scout (J / left mouse). | Slash effect, hit sound, damage number, small knockback; one swing = one hit. |  | PENDING | Critical |
| 5.2 | Spam the attack button. | Attacks have a short cooldown; no machine-gun hits. |  | PENDING | Major |
| 5.3 | Pounce into an enemy. | Bigger damage, the cat bounces back up. |  | PENDING | Major |
| 5.4 | Get hit by an enemy. | Hearts drop, the cat flashes and is invulnerable briefly, knocked back. |  | PENDING | Critical |
| 5.5 | Claw an arrow or a mage orb out of the air. | Projectile is deflected and does not hurt you. |  | PENDING | Minor |
| 5.6 | Eat a fish when hurt / at full health. | Heals when hurt; stays on the floor when health is full. |  | PENDING | Major |

## 6. Enemies

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 6.1 | Fight a White Guard from the front with claws, then from behind and with a pounce. | Front claws are blocked ('BLOCK'); behind and pounce hurt it; it raises a warning before thrusting. |  | PENDING | Major |
| 6.2 | Approach a White Archer. | She backs off, draws (visible wind-up), fires; arrows disappear on walls. |  | PENDING | Major |
| 6.3 | Approach a White Mage. | Orb volleys and floor runes that glow before erupting; blinks away when crowded. |  | PENDING | Major |
| 6.4 | Fight a White Beast; lure it into a wall. | Roars before charging; stunned after hitting a wall; stomps send shockwaves you can jump. |  | PENDING | Major |
| 6.5 | Defeat each type. | Death animation, then it disappears; dead enemies never hurt you. |  | PENDING | Critical |

## 7. Guardians (bosses)

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 7.1 | 1-3 Iron Mouser: fight it fully. | Gates close; health bar shown; slam/charge are telegraphed; phase 2 at half health; beatable on Normal. |  | PENDING | Critical |
| 7.2 | 2-3 Ember Guardian. | Fire waves, fireball volleys, erupting floor in phase 2; vulnerable after the smash. |  | PENDING | Critical |
| 7.3 | 3-3 Frost Matron. | Blinks, shard fans, icicle rain with ceiling sparkle warning, nova in phase 2. |  | PENDING | Critical |
| 7.4 | 4-3 Shadow Stalker (dark arena). | Eyes flash before leaps and rushes; still readable in the dark. |  | PENDING | Critical |
| 7.5 | Final: The Pale King, all 3 phases. | Phase names in the health bar; teleports, orb rings, light pillars, summons; crown shards in phase 3; beatable. |  | PENDING | Critical |
| 7.6 | Die during a guardian fight, then Retry. | Fight resets cleanly (full guardian health, gates open, no leftover projectiles). |  | PENDING | Critical |
| 7.7 | After a win. | Gates open, relic drops, exit door unlocks, region music returns. |  | PENDING | Critical |

## 8. Levels (play each one start to exit)

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 8.1 | 1-1 Mossy Steps | Tutorial signs appear in order; exit reachable; hidden room found. |  | PENDING | Critical |
| 8.2 | 1-2 Root Hollow | Crumbling bridges, guard, Pip's cage, secret ledge. |  | PENDING | Critical |
| 8.3 | 1-3 The Iron Gate | Levers open the right gates; Bramble's cell; guardian arena. |  | PENDING | Critical |
| 8.4 | 2-1 Cinder Shafts | Flame jet rhythm, lava pools, shaft climb, Soot's cell, secret loft. |  | PENDING | Critical |
| 8.5 | 2-2 Bellows Deep | Mine lifts over lava, vertical lift, Cinder's perch, fake floor pocket. |  | PENDING | Critical |
| 8.6 | 2-3 The Forge Heart | Approach + Ember Guardian. |  | PENDING | Critical |
| 8.7 | 3-1 Rime Gallery | Ice sliding, icicles, Nibbles' ice cave, secret niche. |  | PENDING | Critical |
| 8.8 | 3-2 Icicle Vaults | Springs, mages, Flurry's shelf, lower vault (drop through). |  | PENDING | Critical |
| 8.9 | 3-3 Matron's Hall | Approach + Frost Matron on ice. |  | PENDING | Critical |
| 8.10 | 4-1 Lightless Way | Darkness and torches, beasts, Whisper's hidden cave. |  | PENDING | Critical |
| 8.11 | 4-2 Hollow Echoes | Two routes, hidden tunnel room, Inkblot's hidden ledge. |  | PENDING | Critical |
| 8.12 | 4-3 Stalker's Den | Approach + Shadow Stalker. |  | PENDING | Critical |
| 8.13 | 5-1 Marble Ramparts | Saws, all enemy types, Moonpaw on the spring battlement. |  | PENDING | Critical |
| 8.14 | 5-2 Hall of Banners | Tiers, lever gates, Old Tom's prison wing. |  | PENDING | Critical |
| 8.15 | 5-3 The Bell Tower | Vertical climb; pale fire rises once you climb; checkpoints on landings. |  | PENDING | Critical |
| 8.16 | The Pale Throne | Final fight, then the ending. |  | PENDING | Critical |
| 8.17 | In every level: look for places where the cat can get stuck (cannot go back or forward). | None exist. |  | PENDING | Critical |

## 9. Collectibles, secrets and rescues

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 9.1 | Collect coins, then die before the exit, retry from checkpoint. | Coins collected this attempt are kept. |  | PENDING | Major |
| 9.2 | Replay a finished level. | Already collected coins/gems appear faded and give nothing; chests stay open. |  | PENDING | Critical |
| 9.3 | Walk through a fake wall. | Wall turns see-through; 'Secret found!' plays. |  | PENDING | Major |
| 9.4 | Open a cage with E. | Cat thanks you; perk text shown; after the level it is listed in camp. |  | PENDING | Critical |
| 9.5 | Open a chest. | Coin burst, '+25'. |  | PENDING | Minor |

## 10. Camp, upgrades and progression

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 10.1 | Return to camp after a few levels. | Coins, gems, cats, relics, completion % shown at the top. |  | PENDING | Major |
| 10.2 | Adventure tab. | Unlocked levels selectable, locked ones show a lock; medals (check, gems x/y, secrets, cat, best time). |  | PENDING | Major |
| 10.3 | Buy each upgrade (cheat coins are not available - play normally). | Price and gem requirement visible; coins deducted; effect noticeable (e.g. extra heart in HUD). |  | PENDING | Critical |
| 10.4 | Try to buy without enough coins. | Denied sound, nothing changes. |  | PENDING | Major |
| 10.5 | Cats tab and campfire. | Rescued cats listed with perks; they sit around the fire; unrescued show '???'. |  | PENDING | Major |
| 10.6 | Blessing choice between levels; then return to camp. | Three offers, choice applies; blessings vanish after returning to camp. |  | PENDING | Major |

## 11. Save, load and reset

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 11.1 | Play, quit the game completely, restart, Continue. | Coins, upgrades, cats, unlocked levels, records restored. |  | PENDING | Blocker |
| 11.2 | Quit with Alt+F4 in the middle of a level, restart. | Save from the last finished level is intact (unfinished level progress is not saved by design). |  | PENDING | Critical |
| 11.3 | Settings -> Reset Progress -> No, then Yes. | No keeps everything; Yes wipes progress but keeps settings. |  | PENDING | Critical |
| 11.4 | (Advanced) Corrupt %APPDATA%\KocurDungeon\save.json with Notepad, start the game. | Game starts with a fresh save; the broken file is kept as save_corrupt.json. |  | PENDING | Major |

## 12. Death, checkpoints and retry

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 12.1 | Light a lantern, then die. | Defeat screen with a tip; Retry respawns at the lantern with full health. |  | PENDING | Critical |
| 12.2 | Fall into spikes / lava / a pit. | Lose some health and return to the last safe ground. |  | PENDING | Critical |
| 12.3 | Restart Level from the defeat screen. | Level restarts from the beginning. |  | PENDING | Major |
| 12.4 | Walk back to an earlier lantern. | It does not heal again and does not move the respawn point back. |  | PENDING | Minor |

## 13. Pause menu and UI flow

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 13.1 | Press Esc during play. | Game freezes; Resume, Restart from Checkpoint, Restart Level, Settings, Return to Camp, Main Menu. |  | PENDING | Critical |
| 13.2 | Choose Main Menu / Return to Camp / Restart Level. | Each asks for confirmation first. |  | PENDING | Major |
| 13.3 | Press Esc on the defeat/results screens. | Pause menu does not open on top of them. |  | PENDING | Minor |
| 13.4 | Check the HUD during play. | Hearts, shields, coins, gems x/y, pounce bar, level name readable at 1280x720 and 1920x1080. |  | PENDING | Major |
| 13.5 | Finish a level. | Results: time, coins, secrets, gems, deaths, cats, challenges; Continue -> blessing -> next level. |  | PENDING | Critical |

## 14. Audio

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 14.1 | Listen in each region, the camp, the menu, a guardian fight and the final fight. | Different music in each; boss/final themes during fights; music loops without a gap or click. |  | PENDING | Major |
| 14.2 | Change scenes quickly several times. | Never two songs at once; no music keeps playing after it should stop. |  | PENDING | Major |
| 14.3 | Listen to sound effects: jump, claw, hit, coin, hurt, checkpoint, door, cage, boss roar. | All present, not too loud, not distorted. |  | PENDING | Minor |
| 14.4 | Set Music to 0 and Effects to 0. | Respectively silent. |  | PENDING | Major |

## 15. Performance and stability

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 15.1 | Play for 30+ minutes with many enemies and projectiles (final fight, 5-1). | Smooth (note the FPS if possible, e.g. with an overlay); no slowdown building up over time. |  | PENDING | Major |
| 15.2 | Alt+Tab out and back, minimise and restore. | Game continues correctly. |  | PENDING | Major |
| 15.3 | Test on a low-end PC / laptop with integrated graphics. | Starts and is playable (OpenGL 3.3 needed). |  | PENDING | Major |
| 15.4 | Watch for crashes or freezes anywhere. | None. |  | PENDING | Blocker |

## 16. Ending, replayability and completion

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 16.1 | Defeat the Pale King. | Ending story, journey statistics, credits; Return to Camp / Main Menu work. |  | PENDING | Critical |
| 16.2 | After the ending, check camp records and level select. | Game marked complete; all levels replayable from level select. |  | PENDING | Major |
| 16.3 | Complete optional challenges (all secrets, all gems, deathless, guardian without fish). | Each pays +25 coins once and shows as done. |  | PENDING | Minor |
| 16.4 | Aim for 100%: all cats, gems, secrets, levels. | Completion reaches 100%. |  | PENDING | Minor |

Total checks: 95. Summary: ____ PASS / ____ FAIL / ____ BLOCKED
