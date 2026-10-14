# Kocur Purrzzle

A cozy pixel-art push-block puzzle game starring a small black cat. 30 handcrafted levels in 5 regions.
Original game by Kocur Studios. All art and audio are generated in code, no external assets.

## Play (Windows x64)
Unzip `KocurPurrzzle-windows-x86_64.zip` anywhere and run `KocurPurrzzle.exe`. No installer, no network, no extra runtime needed.
Progress and settings are saved in `%APPDATA%\KocurPurrzzle\purrzzle_save.json`.
The exe is unsigned, so Windows SmartScreen may ask you to confirm ("More info" -> "Run anyway").

## Controls
| Action | Keys / mouse |
|---|---|
| Move | WASD or arrow keys (hold to repeat), or the on-screen arrow pad |
| Undo last move | Z (also U, Backspace) or the Undo button |
| Restart level | R or the Restart button (asks first) |
| Wait one beat | Space (also X) or the Wait button |
| Pause | Esc (also P) |
| Fullscreen | F11 |
Menus: arrow keys + Enter, or the mouse.

## Rules
- Push crates (never pull). Cover every paw target with a crate to open the exit, then step on the exit.
- Plates open iron doors while pressed (by a crate or the cat). Keys open locked doors (one key per lock).
- Ice: you and crates keep sliding until something stops you. Warp pads: step on one to jump to its twin.
- Blue/pink gates are open on even/odd beats (every move or wait is one beat).
- Stars: 1 = finished, 2 = within the move target, 3 = within the target and every fish collected. The target is 1.5x the best known solution (plus 3), so it is generous.
- A red flashing crate is stuck in a dead end: undo it with Z.

## Campaign (30 levels, 5 regions x 6)
Sunny Garden (crates, targets) - Moonlit Ruins (plates, doors, keys) - Frozen Fishpond (ice) - Crystal Catacombs (warp pads, beat gates) - Purrfect Temple (everything combined, final puzzle).
Every level has a verified solution; mechanics are introduced with a hint in the level where they first appear.

## Developing
Requires Godot 4.3 (GL Compatibility renderer).
- Run: `godot --path .`
- Tests: `tools/run_tests.sh` (unit tests, UI playthrough of all 30 levels, save persistence across two processes)
- Re-solve all levels (BFS, writes `scripts/pars.json`): `godot --headless --path . -s res://tests/solve_all.gd -- write` (several minutes)
- Windows build: `tools/build_windows.sh` (needs Godot 4.3 export templates, node + npm for icon stamping)
- Architecture: `scripts/puzzle.gd` (pure rules, undo), `solver.gd` (BFS), `levels.gd` (data), `save.gd`, `sfx.gd` (procedural audio), `sprites.gd` (procedural pixel art), `board.gd` (drawing), `main.gd` (screens, input).

## Known limitations
- The Windows exe was built on Linux and has not been run on real Windows by the author; audio loudness and feel are unverified by ear.
- Gamepad is not supported. The font is Godot's built-in font.
- No code signing. No Microsoft Store package.
