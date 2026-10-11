# Kocur Kart – Development Status

Engine: Godot 4.5.1-stable (Compatibility renderer, Jolt physics, 3D physics interpolation).
Godot binary used in development: `/opt/godot45/godot` (symlinked as `godot`).
Windows export templates: `~/.local/share/godot/export_templates/4.5.1.stable/`.

## Milestones

| # | Milestone | State |
|---|---|---|
| 1 | Core driving controller and camera | done |
| 2 | One complete, polished test track | done |
| 3 | Race rules, checkpoints, AI | done |
| 4 | Remaining five tracks and game modes | done |
| 5 | Progression, saves, UI, audio, polish | done |
| 6 | Automated regression testing and Windows release | done (human KX pending) |

## Current state (release candidate 1.0.0)
- Full headless suite: **201/201 passing** (`tools/run_tests.sh godot`), 7 modules.
- Windows x64 export: `release/KocurKart-1.0.0-windows-x86_64.zip` (exe with embedded pck, icon and
  version info stamped). Verified with `tools/verify_windows.sh` under Wine 9.0: 23/23 checks
  (boot, all tracks build, full race, save written, progress persists across relaunch, real
  OpenGL frame rendered). Evidence in `release/verify/`.
- Docs: README.md, TEST_REPORT.md, KX_TEST_CHECKLIST.md, CHANGELOG.md.

## How to run tests / build
```
cd KocurKart
tools/run_tests.sh godot            # headless suite, fails on any script error
tools/build_windows.sh godot        # export + ZIP into build/release/
tools/verify_windows.sh             # run the exported exe (Wine on Linux) in 3 phases
python3 tools/make_test_report.py   # regenerate TEST_REPORT.md from real outputs
```

## Known issues / limitations
- Not yet run on physical Windows hardware; FPS at 1080p on real GPUs unmeasured.
- Gamepads untested with physical controllers; audio not judged by ear.
- Headless runner prints an exit-time "resources still in use" warning (static UI theme cache).
- Fredoka font lacks some Slovak glyphs (UI is English).

## Next concrete steps
1. Human KX pass on a Windows PC using KX_TEST_CHECKLIST.md; log S1-S4 issues.
2. Tune balance/audio from KX feedback; re-run `tools/run_tests.sh` and `tools/verify_windows.sh`.
3. Microsoft Store packaging (MSIX) can reuse the Neon Heist pipeline in the repo root
   (`tools/build_msix.sh`, `store/msix/AppxManifest.xml`) with Kocur Kart's name/identity.
