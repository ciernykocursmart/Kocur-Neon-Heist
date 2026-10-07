# KOCUR: NEON HEIST — Release Checklist

Use this checklist for every release candidate (RC) heading to the Microsoft
Store. Tick items in the PR or release ticket. Items marked **[auto]** are
covered by the automated test-suite or the CI workflow.

## 1. Code & content freeze
- [ ] All feature work merged; only bug fixes accepted after this point.
- [ ] `config/version` in `project.godot` and `file_version` /
      `product_version` in `export_presets.cfg` bumped (e.g. `1.0.0` / `1.0.0.0`).
- [ ] No `print()` debug spam, test-only hooks or cheat shortcuts in
      `scripts/` (`grep -rn "print(" scripts/` should only show intentional output).
- [ ] No TODO/FIXME left that affects players.
- [ ] Campaign text proof-read (briefings, intel, truth, epilogue, credits).

## 2. Automated verification
- [ ] **[auto]** `godot --headless --path . -s res://tests/run_tests.gd` exits 0 with no `SCRIPT ERROR` lines.
- [ ] **[auto]** Reachability across 240 generated facilities (12 missions + endless).
- [ ] **[auto]** Bot playthrough of all 12 campaign missions incl. WARDEN and lockdown.
- [ ] **[auto]** Save migration, corrupt-save recovery, missing-save handling.
- [ ] **[auto]** WARDEN balance bot (typical upgrades win a 25 s+ fight; no upgrades can't win trivially).
- [ ] **[auto]** Performance probe (27+ enemies, full alarm: < 4 ms average logic per tick).
- [ ] **[auto]** Audio levels: no clipping, gameplay cues audible.
- [ ] Run the suite 3 times in a row; all runs green (random layouts vary between runs).
- [ ] **[auto]** CI workflow green on the release commit; Windows artifact produced.
- [ ] Screenshot tour (`tests/run_screenshots.gd` under Xvfb) reviewed by eye.

## 3. Manual QA on Windows (real hardware)
Test on at least one low-end laptop (integrated GPU) and one desktop.
- [ ] Fresh install: game starts with no save, no settings file, no console window.
- [ ] Main menu: Continue disabled without a save; New Game, Settings, Controls, Credits, Quit all work.
- [ ] Endless Heist locked before the campaign is complete, unlocked after.
- [ ] Settings persist after restart (volumes, fullscreen, screen shake, tutorial tips).
- [ ] Fullscreen toggle and window resize (16:9, 16:10, 21:9, 4:3) keep the UI readable.
- [ ] Full campaign playthrough 1 → 12 by a human on default difficulty:
  - [ ] Act I accessible for a newcomer; tips appear and make sense.
  - [ ] Act II difficulty step feels fair; Enforcer telegraph readable.
  - [ ] Act III hard but not frustrating; the WARDEN fight is beatable without max upgrades.
  - [ ] The finale sequence (uplinks → vault → WARDEN → archive → lockdown → EVAC) never soft-locks.
  - [ ] Epilogue and credits play; returning to the menu works; Endless unlocked.
- [ ] Every mission: death → retry, restart from pause, abort to Hideout, quit to menu.
- [ ] Alt-tab, minimise and restore during gameplay, pause and the hack mini-game.
- [ ] Hack mini-game input works with E, left mouse and Space; abort with Q, right mouse and Esc.
- [ ] Weapon switching with 1/2/3, wheel and Q; ammo per weapon correct.
- [ ] All 12 intel fragments can be found; the archive tab shows them after restart.
- [ ] Save/Continue after killing the process mid-mission (progress = last completed mission).
- [ ] Endless: play at least 5 contracts; best depth persists.
- [ ] Performance: steady 60 FPS on the low-end machine in the biggest
      facility (5×4) during a full alarm with reinforcements.
- [ ] Memory stable over a 30-minute session (Task Manager).

## 4. Audio & visual sign-off
- [ ] Listening pass on speakers and headphones: no clipping, music/SFX
      balance OK, siren not fatiguing, boss audio impactful.
- [ ] Volume sliders at 0 fully mute each bus.
- [ ] Colour-contrast check of HUD text; vision cones readable on every theme.
- [ ] Screen shake can be disabled and is disabled everywhere.

## 5. Build
- [ ] Export templates match the editor version (Godot 4.3-stable).
- [ ] Build with `tools/build_windows.sh /path/to/godot`. It stamps the icon and
      version info into the template (pure JS, no rcedit needed), exports in
      **release** mode with the "Windows Desktop" preset, restores the
      template and zips the result.
- [ ] `config/version` in `project.godot` matches the release (the script
      reads it for FileVersion/ProductVersion).
- [ ] The .exe shows the cat icon, "KOCUR: NEON HEIST", company and version
      in *Properties → Details*. (Verified automatically on Linux for RC1 by
      reading the PE resources; re-check on Windows.)
- [ ] The PCK is embedded (single file) and the exe boots
      (`godot --main-pack KocurNeonHeist.exe` works as a smoke test).
- [ ] The exported pack excludes `tests/`, `build/`, `tools/`, `.github/` and Markdown files.
- [ ] The zip contains `KocurNeonHeist.exe`, `README.txt` and `LICENSE_GODOT.txt`
      (Godot's MIT licence; add `COPYRIGHT.txt` third-party notices from the
      Godot source tree for the store build).
- [ ] Virus scan the final zip/exe (Windows Defender + VirusTotal). Unsigned
      Godot executables occasionally trigger heuristic false positives;
      code signing (section 6) resolves most of them.

## 6. Store packaging
- [x] App name reserved; identity `59513Lukes.KocurNeonHeist`, publisher
      `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`, publisher display name `Kocur`.
- [x] MSIX built with `tools/build_msix.sh` (x64, `runFullTrust`, Windows 10
      1809+, version from `project.godot` + `.0`). Validated by makemsix's schema
      check and a full unpack with block-map verification; the packaged exe is
      byte-identical to the tested build.
- [ ] Confirm the manifest `DisplayName` (`Kocur Neon Heist`) exactly matches
      the reserved name; otherwise rebuild with `DISPLAY_NAME=...`.
- [ ] Optional local install test: sign a *copy* with a self-signed cert
      (steps in `store/NAVOD_PUBLIKOVANIE_SK.md`) and install on Windows 10 and 11;
      check the Start menu tile, the icon and that saves persist between launches.
- [ ] Upload the **unsigned** .msix; Partner Center signs it.
- [ ] Run the Windows App Certification Kit on the test-signed copy (recommended).
- [x] Store listing texts (`store/STORE_LISTING.md`), 8 screenshots at
      1920×1080, 1:1 box art, 2:3 poster art, 16:9 hero art (`store/`).
- [ ] Age rating (IARC questionnaire), price €4.99, markets, release date.
- [x] Privacy: no data collection or network use, so no privacy policy is required.

## 7. Launch
- [ ] Tag the release commit (`v1.0.0`) and attach the zip to a GitHub release.
- [ ] Archive the exact Godot editor + templates used for the build.
- [ ] Prepare a hotfix branch and a known-issues list for day one.
