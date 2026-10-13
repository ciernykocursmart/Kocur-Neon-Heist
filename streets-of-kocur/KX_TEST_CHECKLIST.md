# Streets of Kocur - KX Test Checklist (real Windows)

For the Kocur Studios tester (KX) on a real Windows 10/11 x64 PC.
**Nothing below has been run on Windows yet.** Every row is `PENDING`.
Total: **96 checks in 17 sections**.
Fill in *Actual* and *Severity* (Blocker / Major / Minor / Cosmetic / OK).

Build: `StreetsOfKocur-windows-x86_64.zip` v1.0.0 (Godot 4.3.stable, unsigned).

Tester: ________  Date: ________  Windows version: ________  GPU: ________  Gamepad: ________

## 1. First launch and menus

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 1.1 | Unzip StreetsOfKocur-windows-x86_64.zip to the Desktop | Folder StreetsOfKocur with StreetsOfKocur.exe, README.txt, LICENSE_GODOT.txt | | | PENDING |
| 1.2 | Double-click StreetsOfKocur.exe (SmartScreen: More info -> Run anyway) | Window opens with the Streets of Kocur title menu within a few seconds, menu music plays | | | PENDING |
| 1.3 | Fresh install: look at Continue and Level Select | Both disabled | | | PENDING |
| 1.4 | Move through all buttons with arrow keys, gamepad and mouse | Focus highlight moves, UI sound plays | | | PENDING |
| 1.5 | Credits -> Close; Controls -> Close; Settings -> Close | Each window opens and closes | | | PENDING |
| 1.6 | New Game -> read the three difficulties -> Back, then New Game -> Normal | Fade into Street 1 'Alley Trouble' | | | PENDING |
| 1.7 | Quit | Game closes cleanly | | | PENDING |

## 2. Movement along the street and depth axis

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 2.1 | A/D, arrows, left stick | Kocur walks left/right and turns to face the direction | | | PENDING |
| 2.2 | W/S, arrows up/down | Kocur moves deeper/closer along the street and stops at the edges | | | PENDING |
| 2.3 | Double-tap D, hold Shift (RB) while moving | Kocur runs | | | PENDING |
| 2.4 | Walk into crates, traffic barriers (Street 3) and crate walls (Street 4) | Kocur cannot pass through solid objects; can walk around them | | | PENDING |
| 2.5 | Walk diagonally while fighting | Movement stays smooth, shadow stays under the cat | | | PENDING |
| 2.6 | Try to walk left past the camera | Camera never scrolls back; Kocur stops at the screen edge | | | PENDING |

## 3. Basic attack and combo timing

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 3.1 | Tap J three times quickly next to a punk | Paw jab, claw swipe, heavy WHAM; third hit knocks down | | | PENDING |
| 3.2 | Tap J, wait about one second, tap J again | Combo restarts with the jab | | | PENDING |
| 3.3 | Hold J down for a long time | Only one attack per press, no auto-repeat | | | PENDING |
| 3.4 | Attack a cat clearly higher or lower on the street | No hit (depth matters) | | | PENDING |
| 3.5 | Attack while a cat stands behind you | The cat behind is not hit | | | PENDING |
| 3.6 | Watch hit sparks, short freeze, POW/WHAM text, damage numbers, combo counter | Every hit has feedback; misses have none | | | PENDING |
| 3.7 | Overall: is the combo timing comfortable? | Report: too tight / OK / too loose | | | PENDING |

## 4. Jump attacks

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 4.1 | Space | Jump with take-off and landing sound | | | PENDING |
| 4.2 | Space then J near a cat | Flying kick knocks the cat down | | | PENDING |
| 4.3 | Jump over a thrown bottle and over Bruno's shockwave | No damage | | | PENDING |
| 4.4 | Run and press J | Pounce attack | | | PENDING |
| 4.5 | Spam jump attacks against a group | Strong but not unbeatable; report if it trivialises fights | | | PENDING |

## 5. Special attack

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 5.1 | Check the two blue PAWQUAKE bars in the HUD | Fill when you land hits, take hits and slowly over time | | | PENDING |
| 5.2 | K with less than one bar | 'NEED ENERGY', no spin | | | PENDING |
| 5.3 | K surrounded by 3 cats | All nearby cats knocked down; Kocur takes no damage during the spin | | | PENDING |
| 5.4 | K twice in a row with a full meter | Two spins, then the meter is empty | | | PENDING |
| 5.5 | PAWQUAKE an Enforcer | Enforcer is knocked down (normal hits do not stagger him) | | | PENDING |

## 6. Enemy behavior and attack telegraphs

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 6.1 | Punk | Walks up, yellow ! before each punch/kick | | | PENDING |
| 6.2 | Brawler | Ignores the first light hit, slow haymaker + uppercut | | | PENDING |
| 6.3 | Runner | Sprints to your side, lunges, then runs off | | | PENDING |
| 6.4 | Thrower | Keeps distance and throws bottles; step up/down or jump to dodge | | | PENDING |
| 6.5 | Enforcer | Armored, red zone before the slam, charge leaves him dazed on a wall | | | PENDING |
| 6.6 | Grab: E next to a punk, J three times / E to throw | Knees, then throw; thrown cat bowls over a friend; Enforcers cannot be grabbed | | | PENDING |
| 6.7 | Watch for cats stuck behind props or off-screen | None; no fight ever waits on an unreachable cat | | | PENDING |

## 7. Multiple-enemy encounters

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 7.1 | Fight groups of 4-5 cats | At most 2 attack at once on Normal (1 Easy, 3 Hard); others circle | | | PENDING |
| 7.2 | Let several cats hit you in a row | After 3 hits Kocur is knocked down and gets up blinking (no stun-lock) | | | PENDING |
| 7.3 | Watch the camera during a fight | Camera locks; GO arrow appears after the last cat | | | PENDING |
| 7.4 | Count waves in a fight | New cats only arrive when the previous group is almost beaten; never more than 5 on screen | | | PENDING |
| 7.5 | Is the action readable? | Report any moment where you could not tell what hit you | | | PENDING |

## 8. Food pickups and health restoration

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 8.1 | Eat fish / chicken / can when hurt | +20 / +40 / +70 HP, never above 100 | | | PENDING |
| 8.2 | Eat food at full health | 'FULL! +200' points instead | | | PENDING |
| 8.3 | Smash crates, barrels, stalls | Break after a few hits; some drop food | | | PENDING |
| 8.4 | Find the Golden Fish in each street | +3000 and full PAWQUAKE meter | | | PENDING |
| 8.5 | Continue after a game over and walk back to eaten food | Eaten food and broken props do not come back | | | PENDING |

## 9. Player death and restart

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 9.1 | Lose all health with lives left | Kocur falls, gets up at the same spot blinking, nearby cats pushed away, control works | | | PENDING |
| 9.2 | Lose the last life | GAME OVER with Continue / Restart street / Main menu | | | PENDING |
| 9.3 | Continue | Back at the last cleared fight, full lives, continues -1 | | | PENDING |
| 9.4 | Use all 3 continues on Normal | Continue disabled | | | PENDING |
| 9.5 | Pause -> Restart from checkpoint; Pause -> Restart street | Checkpoint costs a life (disabled at 1 life); restart street asks for confirmation | | | PENDING |
| 9.6 | After any restart | No duplicate enemies, input not stuck | | | PENDING |

## 10. All six levels

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 10.1 | Street 1 Alley Trouble | 5 fights, tutorial hints, exit opens at the end | | | PENDING |
| 10.2 | Street 2 Market Mayhem | 6 fights, stalls to smash, market music | | | PENDING |
| 10.3 | Street 3 Neon Boulevard | Barriers, electric puddles that hurt everyone | | | PENDING |
| 10.4 | Street 4 Industrial Paws | Crate walls, hydraulic presses with red warning light | | | PENDING |
| 10.5 | Street 5 White Crown Headquarters | Named areas Front Gate ... Armory | | | PENDING |
| 10.6 | Street 6 The Fat Cat Showdown | Bodyguards, Kitchen Guard, then Lord Lardpaw | | | PENDING |
| 10.7 | Write down real minutes for each street | Only a bot has timed the game so far (see TEST_REPORT) | | | PENDING |

## 11. Mini-boss encounters

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 11.1 | Street 3 Slick Whiskers | Dash, fishbone fan, claws, all telegraphed; punks join at half health | | | PENDING |
| 11.2 | Street 4 Big Bruno Boltpaw | Slam + shockwave (jump it), charge that dazes him on a wall, sweep; runners join | | | PENDING |
| 11.3 | Street 5 General Snowmane | Lunge, spin, leap; reinforcements at 66% and 33% | | | PENDING |
| 11.4 | Every boss | 'OPEN!' after big moves; boss bar with phase marks; K.O. slow motion | | | PENDING |
| 11.5 | Difficulty of each mini-boss on Normal | Report fair / too easy / too hard | | | PENDING |

## 12. Final fat white cat boss

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 12.1 | Lord Lardpaw phase 1 | Belly bounce, rolling charge, paw slam, each with its own warning and sound | | | PENDING |
| 12.2 | Below 66% health | Roar, bodyguards arrive | | | PENDING |
| 12.3 | Below 33% health | Food frenzy: eats, gets faster, cans rain from the shelves | | | PENDING |
| 12.4 | Learn the pattern | Every attack can be avoided by moving or jumping; no unavoidable damage loop | | | PENDING |
| 12.5 | Defeat him | Combat stops, no new enemies, K.O. sequence, results screen | | | PENDING |
| 12.6 | Is he funny and memorable? | Report | | | PENDING |

## 13. Save persistence and level unlocks

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 13.1 | Clear Street 1, quit, start again | Continue resumes Street 2; Level Select shows Street 1 best score and rank | | | PENDING |
| 13.2 | Close the window with X in the middle of Street 2, restart | Continue starts Street 2 from its beginning; nothing corrupted | | | PENDING |
| 13.3 | Replay a cleared street from Level Select | Fresh score; no duplicate unlock; better score/rank saved | | | PENDING |
| 13.4 | Main menu -> Reset Progress -> confirm | Everything locked again; settings kept | | | PENDING |
| 13.5 | Replace %APPDATA%\StreetsOfKocur\streets_save.json with garbage, start | Starts with fresh progress, no crash | | | PENDING |

## 14. Audio and volume controls

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 14.1 | Master volume 0, then back | All sound silent, then returns | | | PENDING |
| 14.2 | Music 0 with effects at 100, and the reverse | Only the chosen group goes silent | | | PENDING |
| 14.3 | Listen across menu, each street, bosses, game over, ending | Each has its own music; no doubled or stuck loops after restart / menu | | | PENDING |
| 14.4 | Light vs heavy hits, special, food, combo, boss attacks | Distinct sounds, not harsh | | | PENDING |
| 14.5 | Restart the game | Volumes remembered | | | PENDING |

## 15. Resolution and fullscreen behavior

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 15.1 | Settings -> Fullscreen on/off | Switches cleanly | | | PENDING |
| 15.2 | Each window size: 1280x720, 1600x900, 1920x1080, 2560x1440 | Window resizes, picture stays 16:9, HUD fits | | | PENDING |
| 15.3 | Fullscreen at native resolution | Sharp, correct aspect | | | PENDING |
| 15.4 | Restart the game | Display settings remembered | | | PENDING |

## 16. Performance and collision issues

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 16.1 | FPS in the biggest fights (Street 5 Armory, Lardpaw phase 3) | Steady; note FPS and GPU (not measured yet) | | | PENDING |
| 16.2 | Laptop with integrated graphics | Playable; note FPS | | | PENDING |
| 16.3 | Play 30 minutes | No slowdown or growing memory in Task Manager | | | PENDING |
| 16.4 | Knock cats into walls, barriers and screen edges | Nobody leaves the street or gets stuck | | | PENDING |
| 16.5 | Mash buttons during fades and at a boss K.O. | No double loading, no soft lock | | | PENDING |
| 16.6 | Die at the same moment as the last enemy | Game continues correctly | | | PENDING |

## 17. Campaign completion and replay

| ID | Steps | Expected | Actual | Severity | Status |
|---|---|---|---|---|---|
| 17.1 | Beat Lardpaw -> See the ending | Four story pages (J/Enter skips), then Campaign Complete panel | | | PENDING |
| 17.2 | Play again / Main menu from the ending | Both work | | | PENDING |
| 17.3 | Main menu after completion | Campaign completion and best campaign score shown | | | PENDING |
| 17.4 | Play the full campaign on Easy and on Hard | Both completable; report difficulty | | | PENDING |
| 17.5 | Total first playthrough time on Normal | Write it down (target 45-90 min) | | | PENDING |
