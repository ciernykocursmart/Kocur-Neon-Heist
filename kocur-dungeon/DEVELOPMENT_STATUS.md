# Development Status

_Last updated: 2026-10-12 - version 1.0.0_

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Project skeleton, autoloads, input map, save system | Done |
| 2 | Generated art (tiles, characters, bosses, objects, FX, icons, font) and audio | Done |
| 3 | Player controller + combat | Done |
| 4 | 5 enemy archetypes, 5 guardians | Done |
| 5 | Level engine (map parser, tiles, collision, objects, hazards, camera, darkness) | Done |
| 6 | Progression: coins, gems, secrets, cats, upgrades, blessings, challenges | Done |
| 7 | HUD, pause, death, results, blessing screens | Done |
| 8 | Reachability validator calibrated against the real player | Done |
| 9 | All 16 levels designed and validated | Done |
| 10 | Main menu, camp hub, ending | Done |
| 11 | Automated test suite (82 tests, all passing) | Done |
| 12 | Windows x64 export, ZIP, exported-pack smoke test | Done |
| 13 | Docs: README, TEST_REPORT, KX checklist, changelog | Done |
| 14 | Manual KX playtest on Windows | **Pending (needs a human)** |

## What has been verified

See [TEST_REPORT.md](TEST_REPORT.md): 82 automated tests, 1789 assertions, all passing on
Linux headless with Godot 4.3; the exported Windows pack loads all menus and levels
under the Linux Godot binary and renders correctly in a virtual display.

## What has NOT been verified

- The .exe has not been started on Windows (no Windows or Wine available here).
- No real-hardware frame-rate measurement; no claim of 60 FPS.
- No human has played the whole game; balance and feel are untested by people.
- Sound has not been listened to (dummy audio driver).
- No physical gamepad tested.

## Known issues and limitations

- The .exe uses the default Godot file icon in Explorer (embedding a custom icon needs
  rcedit, which was not available); the game window itself uses the cat icon.
- The exe is not code-signed, so Windows SmartScreen may warn on first launch.
- Guardians take many base claw hits if you never use their vulnerable windows
  (e.g. ~66 hits for the Iron Mouser at 2 damage); upgrades and pounces shorten fights a lot.
  Balance should be judged in the KX playtest.
- Progress inside an unfinished level is not saved when quitting (by design: a level's
  items are banked when you reach its exit).
- Only English text in the game.
- Fullscreen and window-size switching are tested only as saved settings (headless).

## Next steps

1. KX runs KX_TEST_CHECKLIST.md on a real Windows PC.
2. Fix reported issues; tune boss health / damage from playtest feedback.
3. Optional: custom exe icon (rcedit) and code signing.
