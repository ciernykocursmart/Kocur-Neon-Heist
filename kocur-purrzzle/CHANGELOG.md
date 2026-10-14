# Changelog

## 1.0.2 (2026-10-14)
- Fixed (the real cause of the "stuck cat" report): when the cat faced left it was drawn one tile to the RIGHT of where it really was. A mirrored sprite was drawn with a negative-width rectangle, which the renderer shifts by one tile. The game logic was right, but what you saw was not: a thin shadow line showed the true position, left looked blocked by a wall, and the cat seemed to walk through hedges. The mirror now uses a draw transform.
- New checks: tests/facing_shot.gd compares the drawn cat with its logical tile after left/right/down/up moves; tests/keybot.gd (with `draw`) does this after every step of every level while tapping real keys, and checks the cat never enters a wall.

## 1.0.1 (2026-10-14)
- Fixed: key presses made while the cat was still animating (fast taps, taps during an ice slide) were silently dropped, so the cat seemed stuck or refused to turn back. Every press is now applied immediately; the previous animation just finishes instantly.
- On-screen arrow pad and Wait button use the same path, so mouse clicks are never lost either.
- New tips when a move is blocked by a closed crystal gate, a lock without a key, a closed door or two crates in a row.
- New test: a real-keyboard bot sends key press/release events through Godot's input system and finishes all 30 levels (also at 1 frame between taps), plus hold-to-walk and direction-switch checks.

## 1.0.0 (2026-10-13)
- First release: 30 levels in 5 regions.
