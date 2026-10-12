# Kocur Tactics - KX Manual Test Checklist

For the KX tester, on a real Windows 10/11 x64 PC with `KocurTactics-windows-x86_64.zip`.
Fill **Actual** and **Status** (PASS / FAIL / BLOCKED) for every row. Every row is
**PENDING** until a human has played it: nothing in this file has been verified manually.
The automated tests (see TEST_REPORT.md) do not replace this checklist.

Severity if it fails: **Blocker** (game unusable), **Critical** (core feature broken),
**Major** (clearly wrong, workaround exists), **Minor** (cosmetic / polish).

Recommended order: areas 1, 14 and 2 first (launch, settings, basic controls), then 3-7
in missions 1-2, then play the campaign in order (8-11, 13, 15) and do area 12 after
mission 3. Finish with 16 and 17. Report bugs with: area/row ID, mission, what you did,
what happened, and a screenshot.

Tester: ________  Date: ________  PC (CPU / GPU / Windows version / screen): ________________

## 1. First launch and main menu

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 1.1 | Unzip the ZIP to the Desktop, double-click `KocurTactics.exe`. | Game starts (after SmartScreen "More info -> Run anyway" if shown); main menu with title KOCUR TACTICS, walking cat parade and menu music within a few seconds. |  | PENDING | Blocker |
| 1.2 | Look at the window. | Title "Kocur Tactics", 1280x720 window, crisp pixel art (no blur). |  | PENDING | Minor |
| 1.3 | Disconnect the internet and start the game. | Everything works offline. |  | PENDING | Major |
| 1.4 | First launch (no save): look at the buttons. | Continue, Mission Select, Roster, Upgrades, Tactical Challenges and Reset Progress are greyed out. New Campaign, Settings, Credits, Quit work. |  | PENDING | Major |
| 1.5 | New Campaign. | Difficulty window (Story / Normal / Hard + Cancel). Cancel closes it. Choosing Normal opens the campaign screen on the Missions tab. |  | PENDING | Blocker |
| 1.6 | Credits. | Kocur Studios credits and the Godot licence note; Close returns. |  | PENDING | Minor |
| 1.7 | Quit, then close with the window X on a second start. | Game exits cleanly both ways. |  | PENDING | Major |
| 1.8 | Navigate the menu with Tab/arrows + Enter/Space. | Focus highlight moves; buttons activate; UI sounds play. |  | PENDING | Minor |

## 2. Selecting and moving units

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 2.1 | Mission 1, click Begin Battle, click Nox. | Nox gets a selection frame; blue tiles (with dots) show where he can move; the right panel shows name, class, HP, ATK, DEF, MOV. |  | PENDING | Critical |
| 2.2 | Hover a blue tile. | A path is drawn; the bottom line says "Move Nox here (cost X of 5)". |  | PENDING | Major |
| 2.3 | Click the blue tile. | Nox walks along exactly the drawn path, tile by tile, with step sounds. |  | PENDING | Critical |
| 2.4 | Right click (or Z) before acting. | Nox jumps back to his start tile and can move again. |  | PENDING | Major |
| 2.5 | Try to click a wall, water, an enemy tile, an ally tile or outside the map. | Nothing moves there; no crash. |  | PENDING | Critical |
| 2.6 | Press Tab repeatedly. | Cycles through heroes that can still act. |  | PENDING | Minor |
| 2.7 | Move Willow through a tile occupied by Bramble (corridor). | Allies can be walked through, but not stopped on. |  | PENDING | Major |

## 3. Attack range and line of sight

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 3.1 | Select Willow (Aimed Shot armed). | Pale red range tiles 2-5; enemies she can hit get red corner markers. |  | PENDING | Critical |
| 3.2 | Put a wall or pillar between Willow and an enemy. | That enemy is NOT targetable; through forest/water it is. |  | PENDING | Critical |
| 3.3 | Click a target once. | Bottom line shows the exact damage and its parts, e.g. "Aimed Shot -> White Recruit: 8 dmg (ATK 6, steady +2, ...)". Nothing happens yet. |  | PENDING | Critical |
| 3.4 | Click the same target again (or Space). | Arrow flies, damage number appears, HP bar drops by exactly the previewed amount. |  | PENDING | Critical |
| 3.5 | Move Willow, then look at the preview again. | The Steady +2 bonus is gone. |  | PENDING | Major |
| 3.6 | Put an enemy right next to Willow. | It cannot be shot (minimum range 2). |  | PENDING | Major |
| 3.7 | Click an enemy (no hero selected). | Its stats show, and every tile it can attack next turn is outlined. |  | PENDING | Major |
| 3.8 | Press T. | All tiles any enemy can attack next turn are hatched; T again hides them. |  | PENDING | Major |

## 4. The three hero classes (+ Mender)

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 4.1 | Nox: Claw Strike an adjacent enemy with another hero also next to it. | Damage = 7 + 2 flank - DEF; preview lists "flank +2". |  | PENDING | Critical |
| 4.2 | Nox: Shadow Pounce (key 2) on an enemy up to 3 tiles away. | Leaps to the shown landing tile beside the target and hits for ATK+2. Button then shows the cooldown "(2)". |  | PENDING | Critical |
| 4.3 | Nox: Shadow Pounce on an empty tile; try one behind a wall. | Repositions to the empty tile; tiles behind walls are not offered. |  | PENDING | Major |
| 4.4 | Bramble: Heavy Strike without moving; then on another turn move first. | Without moving: ATK+4. After moving the Heavy Strike button is disabled with a reason. |  | PENDING | Critical |
| 4.5 | Bramble: Protective Stance (press twice to confirm). Enemy attacks Bramble and an ally next to him. | Shield icon on Bramble; damage to Bramble -3, to adjacent ally -2 versus normal. Cooldown 1. |  | PENDING | Critical |
| 4.6 | Willow: Volley on a group (2-4 tiles away). | Hits the target tile and the 4 tiles around it for ATK-1, never allies. Cooldown 2. |  | PENDING | Critical |
| 4.7 | Moss (after mission 3): Mend a wounded ally within 3 tiles. | Heals up to 8 HP, not above max; cannot target herself or full-HP allies. |  | PENDING | Major |

## 5. Enemy AI and target selection

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 5.1 | End turn in mission 1 and watch. | "ENEMY TURN" banner; each enemy moves legally and attacks only heroes in range. |  | PENDING | Critical |
| 5.2 | Leave a low-HP hero within reach. | Enemies prefer to finish weak heroes. |  | PENDING | Major |
| 5.3 | Archers (mission 2+): walk up to one. | Archers step away to keep range and use walls/hills; they never shoot through walls. |  | PENDING | Major |
| 5.4 | Mages (mission 7+). | Frost Bolt chills a hero (snowflake icon, -2 MOV next turn); mages heal hurt allies. |  | PENDING | Major |
| 5.5 | Guards. | Stay near archers/mages; allies next to a Guard get +1 DEF (preview shows "shield wall"). |  | PENDING | Major |
| 5.6 | Stalkers (mission 5+). | Run around terrain to reach a hero standing alone; +2 damage against isolated heroes. |  | PENDING | Major |
| 5.7 | Sleeping enemies (Zz) in missions 2, 3, 5, 8, 11. | They stay put until a hero comes close or one of their group is hit; then the group wakes. |  | PENDING | Major |
| 5.8 | Watch several enemy phases. | No enemy teleports, walks through walls, acts twice or attacks after the battle ended. Enemy turns never hang. |  | PENDING | Critical |

## 6. Terrain and blocked paths

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 6.1 | Hover forest, mud, hill, water, wall, bridge, thorns tiles. | Tile panel shows name, move cost, cover DEF and a description. |  | PENDING | Major |
| 6.2 | Move through forest/mud. | Costs 2 movement (fewer blue tiles beyond it). |  | PENDING | Major |
| 6.3 | Hero in forest gets attacked. | Preview/damage includes cover +1 DEF. |  | PENDING | Major |
| 6.4 | Willow on a hill. | Aimed Shot range becomes 6. |  | PENDING | Minor |
| 6.5 | End a turn on thorns/caltrops/embers. | 3 damage at the start of that side's turn, with a log line. |  | PENDING | Major |
| 6.6 | Look for a mission where a path is blocked by an enemy in a corridor. | Heroes cannot pass through enemies; must fight or go around. |  | PENDING | Major |

## 7. Turn transitions and action limits

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 7.1 | Move a hero, attack, then try to move or attack again. | Not possible; the hero turns grey with a small hourglass icon. |  | PENDING | Critical |
| 7.2 | Attack without moving, then try to move. | Not possible (move first, then act). |  | PENDING | Critical |
| 7.3 | Click End Turn (or Enter/E) while heroes can still act. | Confirmation "N hero(es) can still act"; Cancel keeps your turn. |  | PENDING | Major |
| 7.4 | Spam-click a target and End Turn very fast during animations. | No double attacks, no double enemy phase, no skipped turn. |  | PENDING | Critical |
| 7.5 | During the enemy phase click around and press keys. | Player commands are ignored until "YOUR TURN". |  | PENDING | Critical |
| 7.6 | Use an ability with a cooldown and end turns. | The number on the button counts down and the ability becomes available again. |  | PENDING | Major |

## 8. Mission objectives and optional objectives

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 8.1 | Each mission: read the briefing and the Objective panel. | Primary objective and optional objectives listed; turn counters update (e.g. "turn 3/6"). |  | PENDING | Major |
| 8.2 | M03 Rescue: Free (F) Moss's cage, walk her to an E tile, Escape. | Victory when Moss escapes; kittens freed counts for the optional. |  | PENDING | Critical |
| 8.3 | M04 Defend: let an enemy stand on a D tile at the end of the enemy phase. | Defeat "The shrine was overrun". Otherwise victory after 6 turns. |  | PENDING | Critical |
| 8.4 | M05 Escape: get every hero on the field to an E tile and press Escape. | Escaped heroes leave the map; victory when all remaining heroes are out; defeat after 12 turns. |  | PENDING | Critical |
| 8.5 | M07 Protect: Moonwell must survive 7 turns. | Defeat if it reaches 0 HP; victory after turn 7. |  | PENDING | Critical |
| 8.6 | M08 Commander: defeat Captain Snowcap. | Victory immediately when he falls, even with enemies left. |  | PENDING | Critical |
| 8.7 | M09 Survive 7 turns; M10 Escort the Elder to an exit; M11 Claim 3 relics. | Each completes as described; turn limits (M10: 15, M11: 18) cause defeat when exceeded. |  | PENDING | Critical |
| 8.8 | Optional objectives (e.g. "Win within 5 turns", treasure $, "No hero knocked out"). | Shown [OK] on the result screen only when achieved; pay Relic Shards once. |  | PENDING | Major |

## 9. Boss telegraphs and phase changes

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 9.1 | M06: stand next to Ironpaw and end turn. | He marks 3 tiles (orange hatch + "!") and a warning appears; nothing hits yet. |  | PENDING | Critical |
| 9.2 | Step out of the marked tiles, end turn. | Crushing Blow lands only on marked tiles; nobody outside is hurt. |  | PENDING | Critical |
| 9.3 | After his blow. | Ironpaw is EXHAUSTED (DEF 0) for your turn: previews show much higher damage. |  | PENDING | Critical |
| 9.4 | Bring Ironpaw below half HP. | "IRON GUARD" banner: +3 DEF for 2 turns, 2 guards appear. Happens only once. |  | PENDING | Major |
| 9.5 | M12: attack the Pale King while pylons stand. | Damage shows IMMUNE / 0. After both Crown Pylons fall: "shield shatters" banner, damage goes through. |  | PENDING | Critical |
| 9.6 | M12 phase 1. | Royal Lance marks a full row/column one turn ahead; summon marks show where recruits will appear. |  | PENDING | Critical |
| 9.7 | Bring the King below half HP. | "PHASE 2" banner: he moves, 2 stalkers appear, he casts a marked 3x3 Pale Nova, then is DRAINED (DEF 0). |  | PENDING | Critical |
| 9.8 | Defeat the King. | Victory, then Continue leads to the ending screen. |  | PENDING | Blocker |

## 10. Hero progression and upgrades

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 10.1 | Win a mission for the first time. | Result screen lists XP per hero (deployed 40 + 10/kill up to +30, reserve 20), shards, level-ups. |  | PENDING | Major |
| 10.2 | Roster tab. | Each recruited hero with level, XP (e.g. "XP 40 / 100"), stats, abilities and bio; heroes not yet recruited say when they join. |  | PENDING | Major |
| 10.3 | Upgrades tab: buy Vitality for Nox. | Shards drop by the cost; Nox's HP rises by 3 in the roster and in the next battle. |  | PENDING | Critical |
| 10.4 | Try to buy with too few shards / at max rank. | Button disabled; nothing changes. |  | PENDING | Major |
| 10.5 | Buy Class Mastery for Willow. | Volley cooldown becomes 1 in battle. |  | PENDING | Major |
| 10.6 | Win M03, M06, M08. | Moss, Soot and Pepper join the roster (message on the result screen). |  | PENDING | Critical |
| 10.7 | A hero is knocked out in a battle that you win. | The hero is back at full HP in the next battle; nobody is lost. |  | PENDING | Major |

## 11. Mission unlocks and campaign progress

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 11.1 | Missions tab on a new campaign. | Only mission 1 is unlocked; the others read "??? (locked)" and cannot be clicked. |  | PENDING | Critical |
| 11.2 | Win mission 1. | Mission 2 unlocks; mission 1 shows medal and best turns. |  | PENDING | Critical |
| 11.3 | Lose a mission. | Nothing unlocks; no rewards; retry works. |  | PENDING | Critical |
| 11.4 | Replay a won mission. | No XP or mission shards again; only NEW optional objectives pay; medal never decreases. |  | PENDING | Critical |
| 11.5 | Squad select: click heroes to add/remove, try more than the slot count. | Squad respects the slot limit; a hero caged in that mission cannot be picked. |  | PENDING | Major |
| 11.6 | Challenges tab after M04, M08, M12. | Challenges 1, 2, 3 unlock in that order and use fixed squads. |  | PENDING | Major |
| 11.7 | Records tab. | Completed missions, medals, battles won/lost. |  | PENDING | Minor |

## 12. Save/load after closing the application

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 12.1 | Win mission 1-3, buy an upgrade, close the game with the X. Start again, Continue. | Same missions, medals, XP, shards, roster and upgrades. |  | PENDING | Blocker |
| 12.2 | Quit in the middle of a battle (pause -> Quit to Main Menu, then close). | Campaign is as it was before that battle; the battle itself is not saved (by design). |  | PENDING | Major |
| 12.3 | New Campaign with progress. | Confirmation first; Cancel keeps everything. |  | PENDING | Critical |
| 12.4 | Reset Progress. | Confirmation first; after Yes everything is back to a fresh start. |  | PENDING | Critical |
| 12.5 | Close the game, open `%APPDATA%\KocurTactics\save.json` in Notepad, break it (delete half), start the game. | Game starts with a fresh campaign, no crash; the broken file is kept as `save_corrupt.json`. |  | PENDING | Major |

## 13. Difficulty settings

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 13.1 | Compare a White Recruit on Story / Normal / Hard (Settings -> Difficulty, then restart the mission). | HP 8 / 10 / 12; its attack previews deal 2 less / normal / 1 more. |  | PENDING | Major |
| 13.2 | Change difficulty mid-campaign. | Applies to the next battle; nothing locked or lost. The top bar shows the difficulty. |  | PENDING | Major |
| 13.3 | Play a full mission on Hard. | Noticeably harder but fair. |  | PENDING | Minor |

## 14. Audio and UI settings

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 14.1 | Move Master / Music / Effects sliders. | Volume changes immediately. 0 = silent. |  | PENDING | Major |
| 14.2 | Toggle Fullscreen. | Switches cleanly; picture stays sharp and 16:9. |  | PENDING | Major |
| 14.3 | Window size 1280x720, 1600x900, 1920x1080 (and 2560x1440 if possible). | Window resizes; all text readable; nothing cut off. |  | PENDING | Major |
| 14.4 | Animation speed Normal / Fast / Very fast. | Moves and enemy turns play faster. |  | PENDING | Minor |
| 14.5 | Controls & Rules page. | Lists match the real controls. |  | PENDING | Minor |
| 14.6 | Restart the game. | All settings remembered. |  | PENDING | Major |
| 14.7 | Listen across menu -> campaign -> battle -> boss -> ending. | Music changes per scene without overlapping tracks; sounds for select, move, hits, KO, turn start, victory/defeat, boss warnings. |  | PENDING | Major |

## 15. Victory, defeat, restart and menu transitions

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 15.1 | Win a mission. | VICTORY banner, result screen (turns, KOs, optionals, medal, rewards); Continue -> campaign. |  | PENDING | Blocker |
| 15.2 | Lose a mission (let all heroes fall). | DEFEAT screen with the reason; Retry restarts the same mission; Continue -> campaign. |  | PENDING | Critical |
| 15.3 | Pause (Esc) -> Restart Mission -> Yes. | Mission restarts at turn 1 with full HP. |  | PENDING | Major |
| 15.4 | Pause -> Return to Campaign / Quit to Main Menu. | Confirmation; then the screen changes; campaign progress untouched. |  | PENDING | Major |
| 15.5 | Pause -> Settings / Controls & Rules -> Close -> Resume. | Back in battle exactly where you were. |  | PENDING | Major |

## 16. Full campaign completion

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 16.1 | Play missions 1-12 in order on Normal with the starter squad + recruits, no grinding. | Every mission is winnable; note time per mission and any mission that feels unfair. Target total 2-4 hours. |  | PENDING | Blocker |
| 16.2 | After M12. | Ending screen "THE VALLEY IS FREE!" with medal points and battles won; "Back to Campaign" and "Main Menu" buttons work. |  | PENDING | Critical |
| 16.3 | After the ending. | All missions and challenges stay replayable; Continue works. |  | PENDING | Major |
| 16.4 | Play the 3 challenges. | Each is winnable; best turns recorded. |  | PENDING | Major |

## 17. Visual clarity and performance

| ID | Steps | Expected | Actual | Status | Severity if failed |
|---|---|---|---|---|---|
| 17.1 | Look at a busy battle (M09, M12). | Heroes (blue ring) and enemies (red diamond) are distinguishable even without colour; HP bars and numbers readable. |  | PENDING | Major |
| 17.2 | Telegraphs, reinforcements (red X), threat hatch, move dots, target corners. | Each overlay is recognizable by shape/pattern, not only colour. |  | PENDING | Major |
| 17.3 | Enemy phase with many units (M09, M12). | Smooth; no long freezes. Note FPS if possible (should stay at 60 on a normal PC). |  | PENDING | Major |
| 17.4 | Three regions (Shadowwood, Border, Crown). | Each has its own tile style; bosses look distinct. |  | PENDING | Minor |
| 17.5 | Text at 1280x720. | Every label fits; nothing overlaps. |  | PENDING | Minor |
