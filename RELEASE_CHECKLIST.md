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
- [ ] **[auto]** `godot --headless --path . -s res://tests/run_tests.gd` exits 0.
- [ ] **[auto]** Reachability across 240 generated facilities (12 missions + endless).
- [ ] **[auto]** Bot playthrough of all 12 campaign missions incl. WARDEN and lockdown.
- [ ] **[auto]** Save migration, corrupt-save recovery, missing-save handling.
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
- [ ] Export with the **"Windows Desktop"** preset in **release** mode:
      `godot --headless --path . --export-release "Windows Desktop" build/windows/KocurNeonHeist.exe`
- [ ] The .exe shows the correct icon, product name, company and version in
      *Properties → Details*.
- [ ] The PCK is embedded (single file); the exported pack excludes `tests/`, `build/`, `.github/` and Markdown files.
- [ ] Zip the build together with `README.txt` and Godot's `LICENSE` text
      (MIT, plus third-party notices from `godot --license` / Godot's
      `COPYRIGHT.txt`).
- [ ] Virus scan the final zip/exe (Windows Defender + VirusTotal).

## 6. Store packaging (next phase — not done yet)
- [ ] Reserve the app name "KOCUR: NEON HEIST" in Partner Center.
- [ ] Create the MSIX package (MSIX Packaging Tool or `makeappx`); declare
      `runFullTrust`, x64 only, min Windows 10 1809.
- [ ] Code-sign with the Partner Center certificate (or a trusted EV cert).
- [ ] Verify the save location works from the MSIX container (`%APPDATA%` virtualisation).
- [ ] Run the Windows App Certification Kit (WACK) and fix all failures.
- [ ] Store listing: description, 6+ screenshots (1920×1080), trailer,
      age rating (IARC questionnaire: fantasy violence, no blood), privacy
      policy URL (the game collects no data), price €4.99, markets.
- [ ] Accessibility notes in the listing (keyboard + mouse, subtitles not applicable).

## 7. Launch
- [ ] Tag the release commit (`v1.0.0`) and attach the zip to a GitHub release.
- [ ] Archive the exact Godot editor + templates used for the build.
- [ ] Prepare a hotfix branch and a known-issues list for day one.
