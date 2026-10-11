# Kocur Kart – KX (Kocur Experience) Human Test Checklist

Build under test: `KocurKart-1.0.0-windows-x86_64.zip`, executable `KocurKart/KocurKart.exe`
Tester: ____________  Date: ____________  PC (CPU/GPU/RAM): ______________________________
Windows version: ______  Display (resolution/Hz): ______  Gamepad model (if any): ______________

**None of these checks has been performed by a human yet.** Automated tests are recorded separately
in `TEST_REPORT.md`. Every result field below starts empty; a tester fills it in.

Severity scale for issues:
- **S1 Blocker:** crash, hang, lost save, the game cannot be finished.
- **S2 Major:** a feature is broken or the game is clearly unfair or unplayable in one area.
- **S3 Minor:** something is wrong but has a workaround (visual glitch, odd sound, small balance issue).
- **S4 Polish:** a suggestion or cosmetic detail.

For a clean first-launch test, delete `%APPDATA%\KocurKart\` before step 1.

---

### 1. First launch and menu navigation
Steps: unzip and run `KocurKart.exe`. Wait for the main menu. Move through every main-menu entry
with the mouse, then with the arrow keys + Enter + Esc, then with a gamepad (D-pad, A, B).
Open each page and go back.
Expected: no error dialogs, and the menu appears within a few seconds over a moving 3D backdrop
with menu music. Every button responds and makes a UI sound. Esc/B goes back. Quit closes the game.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 2. First race: controls, acceleration, steering, braking, camera
Steps: Single Race > Whiskerwood Circuit > Normal > 3 laps > Start Race. Drive one lap without
drifting. Try full throttle, braking to a stop, reversing, and gentle and sharp steering at low and
high speed.
Expected: the kart responds immediately. Steering is precise at low speed and calmer at top speed.
Braking stops the kart within a few seconds and holding brake reverses. The camera follows smoothly,
looks ahead, widens slightly with speed and never loses the kart or clips into scenery.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 3. Drifting and boost timing
Steps: on Whiskerwood's hairpin and S-bends, hold Drift (Space) while steering. Hold until blue
sparks appear, then release. Repeat until orange sparks appear, then release. Fill the Purr meter
and press Shift on a straight. On the countdown, press Accelerate during "1"; next time, hold it
from "3".
Expected: the kart slides sideways but keeps its momentum, and steering changes how tight the drift
is. Blue sparks give a small boost and orange sparks a big one, each with a sound and flames. Purr
Boost spends exactly one meter segment. A perfect start shows "PERFECT START!", and an early rev
shows "WHEELSPIN!".
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 4. Collisions, jumps, landings, respawning
Steps: hit walls at shallow and steep angles, bump rivals, drive into a hazard (Purrport crabs,
Frostpaw snowball). Take the jumps on Neon Catway, Sunset Safari and Royal Catnip Run. Fall off
Purrport's open pier edge into the water on purpose. Press R while stuck against a wall.
Expected: wall hits slow you and slide you along the wall, never spinning you. Bumps push karts
apart. Hazards knock you about briefly. Jumps feel floaty with a soft landing and no bouncing.
Falling into the water respawns you on the pier within about 2 s, facing forward and briefly
translucent. R respawns you at most once every 2 s.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 5. AI behaviour on all six tracks
Steps: run a Single Race (Normal) on every track. Watch the rivals at the start, in corners, at the
jumps and around hazards. Repeat one track on Easy and on Hard.
Expected: rivals leave the grid, follow sensible lines, brake for corners, drift, dodge hazards,
recover from bumps and finish all laps. They do not teleport or go suspiciously fast when behind.
Easy is clearly slower than Normal, and Hard is clearly faster.
Actual (per track): Whiskerwood ____ Purrport ____ Neon ____ Frostpaw ____ Safari ____ Royal ____
Notes: ______________________________________________  Severity: ____

### 6. Wrong-way driving and checkpoint integrity
Steps: turn around and drive backwards for a few seconds. Then try to cut across the infield
or skip part of the lap, and drive back and forth over the finish line.
Expected: a flashing "WRONG WAY!" and a buzzer appear within about 1 s and clear when you turn
back. Laps only count after driving the whole circuit; crossing the line repeatedly never adds laps.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 7. Grand Prix points and cup completion
Steps: Grand Prix > Whisker Cup > Easy. Finish race 1 and check the standings, then finish race 2.
Use Retry Race once in race 2.
Expected: points go 10/7/5/3/2/1, and standings are shown after each race. The cup result shows
your trophy: gold for 1st, silver for 2nd, bronze for 3rd. Retry restores the standings from before
that race. Back in the menu the Moonlight Cup is unlocked if you earned a trophy, and unlock
notifications appeared.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 8. Single Race and Time Trial
Steps: Single Race with 1 and 5 laps. Time Trial on Whiskerwood: finish once, then Retry and race
your ghost. Leave a Time Trial halfway through via Pause > Quit.
Expected: the lap count matches your choice. Time Trial shows lap times, a medal (or "no medal")
and the target times. A new record is announced, and your previous best run appears as a
translucent ghost. An abandoned run saves nothing.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 9. Save persistence after closing and reopening
Steps: after earning a trophy, a Time Trial record and changing a setting, quit the game
completely and start it again. Then check Records & Progress, the garage and Settings.
Expected: trophies, records, medals, unlocks, garage selection and settings are all exactly as you
left them.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 10. Garage selection and unlock progression
Steps: open the Garage and cycle every category. Select a locked item and press Done. Race with a
different kart and paint.
Expected: the kart preview updates and rotates, and the stat bars change per kart. Locked items
show "LOCKED" plus exactly how to earn them, and a locked choice is never saved. Your chosen
racer, kart and cosmetics appear in the race.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 11. Audio balance and settings
Steps: listen during a race: engine, drift squeal, boosts, impacts, countdown, lap and finish
jingles, ambience and music. Move the Master, Music and Effects sliders, including to 0.
Expected: the engine pitch rises smoothly with speed without warbling. Music never drowns out
gameplay sounds. Each slider controls only its own group, and 0 mutes it. Sounds do not stack up
after several restarts, and music changes correctly between the menu and each track.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 12. Keyboard and gamepad controls
Steps: play a full race on keyboard only. Rebind Drift to another key in Settings > Controls and
use it, then reset to defaults. Play a full race on a gamepad (analog steering, triggers).
Expected: every action works on both devices. Analog steering is proportional and triggers act as
analog throttle/brake. Rebinding works and persists, and the game stays fully playable with no
gamepad connected.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 13. Resolution and fullscreen behaviour
Steps: toggle Fullscreen on and off. Try each window size, toggle VSync and the frame-rate caps.
Check readability at 1280×720 and 1920×1080.
Expected: changes apply immediately and persist after a restart. The HUD and menus stay legible and
inside the screen at both resolutions.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 14. Performance and visual readability
Steps: enable an FPS overlay (for example from your GPU driver) and race on every track, especially
Royal Catnip Run and Whiskerwood at 1920×1080 with 6 karts.
Expected: steady 60 FPS on a mid-range PC, no stutter when the race starts. Upcoming turns are
readable thanks to chevron boards, the track edges are clear, and the effects never hide the road.
Measured FPS per track: W ___ P ___ N ___ F ___ S ___ R ___   Severity: ____

### 15. Restart, pause, quit and scene transitions
Steps: pause mid-race, then resume, restart and quit to menu (confirm dialogs). Alt-tab away
mid-race. Restart a race five times in a row.
Expected: pause freezes everything, and alt-tab auto-pauses. Restart gives a clean race with no
duplicate karts, timers or sounds. Quitting asks for confirmation, and transitions fade cleanly
with "Loading...".
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

### 16. Final championship completion
Steps: earn trophies in all three cups (any difficulty), ending with Royal Catnip Run.
Expected: after the Royal Cup result a "CHAMPIONSHIP COMPLETE!" screen lists all three cups with
trophies and points. Sushi and the Royal Crown unlock. Records & Progress shows all cups finished.
Actual: ______________________________________________  Pass/Fail: ____  Severity: ____

---

**Overall verdict:** ________  Number of S1 ___ S2 ___ S3 ___ S4 ___
**Fun factor (1–10) / "one more race?":** ________
