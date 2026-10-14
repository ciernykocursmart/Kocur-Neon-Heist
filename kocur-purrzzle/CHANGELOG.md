# Changelog

## 1.0.1 (2026-10-14)
- Fixed: key presses made while the cat was still animating (fast taps, taps during an ice slide) were silently dropped, so the cat seemed stuck or refused to turn back. Every press is now applied immediately; the previous animation just finishes instantly.
- On-screen arrow pad and Wait button use the same path, so mouse clicks are never lost either.
- New tips when a move is blocked by a closed crystal gate, a lock without a key, a closed door or two crates in a row.
- New test: a real-keyboard bot sends key press/release events through Godot's input system and finishes all 30 levels (also at 1 frame between taps), plus hold-to-walk and direction-switch checks.

## 1.0.0 (2026-10-13)
- First release: 30 levels in 5 regions.
