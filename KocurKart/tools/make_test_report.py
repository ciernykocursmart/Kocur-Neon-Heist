#!/usr/bin/env python3
"""Builds TEST_REPORT.md from the real outputs of the automated runs:
  build/test_report/results.json   (tools/run_tests.sh)
  build/release/verify/*.json      (tools/verify_windows.sh)
"""
import datetime
import json
import os
from collections import OrderedDict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
res = json.load(open(os.path.join(ROOT, "build/test_report/results.json")))
verify_dir = os.path.join(ROOT, "build/release/verify")

modules = OrderedDict()
for r in res["results"]:
    modules.setdefault(r["module"], []).append(r)

out = []
w = out.append
w("# Kocur Kart – Automated Test Report")
w("")
w("Generated %s from the actual test outputs (`tools/make_test_report.py`)." % datetime.date.today().isoformat())
w("")
w("## Summary")
w("")
w("| Suite | Checks | Passed | Failed |")
w("|---|---|---|---|")
for m, rows in modules.items():
    p = sum(1 for r in rows if r["passed"])
    w("| %s | %d | %d | %d |" % (m, len(rows), p, len(rows) - p))
w("| **Headless suite total** | **%d** | **%d** | **%d** |" % (res["passed"] + res["failed"], res["passed"], res["failed"]))

verify_rows = []
for phase in ["race", "verify", "shot"]:
    path = os.path.join(verify_dir, "autotest_%s.json" % phase)
    if os.path.exists(path):
        d = json.load(open(path))
        verify_rows.append((phase, d))
if verify_rows:
    tot = sum(len(d["checks"]) for _, d in verify_rows)
    ok = sum(1 for _, d in verify_rows for c in d["checks"] if c["passed"])
    w("| Exported Windows build (Wine) | %d | %d | %d |" % (tot, ok, tot - ok))
w("")
w("Headless suite runtime: %.0f s of game simulation at a fixed 60 FPS." % res["seconds"])
w("")
w("**How the evidence was produced**")
w("- Headless suite: `tools/run_tests.sh godot` runs `godot --headless --fixed-fps 60 -s res://tests/run_tests.gd`. "
  "Each check asserts a measured value, which is given in the Evidence column. The runner also fails if the log "
  "contains any `SCRIPT ERROR`. Logs are in `build/test_report/test.log`, with machine-readable results in "
  "`build/test_report/results.json`.")
w("- Exported build: `tools/verify_windows.sh` runs `build/windows/KocurKart.exe` under **Wine 9.0 on Linux** "
  "(not physical Windows) with a fresh profile in three phases (`--autotest=race`, `verify`, `shot`). "
  "The reports are `build/release/verify/autotest_*.json`, the rendered frame is `autotest_shot.png` and the "
  "resulting save is `save_after_race.json`.")
w("")
w("## Exported Windows build verification")
w("")
if verify_rows:
    for phase, d in verify_rows:
        w("### Phase `%s` – %s" % (phase, "PASS" if d.get("passed") else "FAIL"))
        w("")
        w("Platform reported by the game: %s · Godot %s · user dir `%s`" % (d.get("platform"), d.get("godot"), d.get("user_dir")))
        if d.get("renderer"):
            w("· renderer: %s" % d["renderer"])
        w("")
        w("| Check | Result | Evidence |")
        w("|---|---|---|")
        for c in d["checks"]:
            w("| %s | %s | %s |" % (c["name"], "PASS" if c["passed"] else "**FAIL**", c.get("detail", "")))
        w("")
else:
    w("Not run.")
    w("")
w("## Detailed results")
w("")
for m, rows in modules.items():
    w("### %s" % m)
    w("")
    w("| Test | Result | Evidence |")
    w("|---|---|---|")
    for r in rows:
        ev = str(r["evidence"]).replace("|", "/").replace("\n", " ")
        w("| %s | %s | %s |" % (r["name"], "PASS" if r["passed"] else "**FAIL**", ev))
    w("")
w("## Unresolved failures")
w("")
fails = [r for r in res["results"] if not r["passed"]]
vf = [(p, c) for p, d in verify_rows for c in d["checks"] if not c["passed"]]
if not fails and not vf:
    w("None. Every automated check above passed on the final build.")
else:
    for r in fails:
        w("- %s / %s: %s" % (r["module"], r["name"], r["evidence"]))
    for p, c in vf:
        w("- exported build (%s) / %s: %s" % (p, c["name"], c.get("detail", "")))
w("")
w("## Not covered by automation (needs human KX testing)")
w("")
w("- Physical Windows hardware and real GPU drivers, frame rate at 1080p, fullscreen and resolution switching (the window code is guarded in headless mode).")
w("- Physical gamepads. Input mappings are defined but were never driven by a real controller.")
w("- Audio quality and balance by ear. Tests only confirm that the assets load, the buses route correctly and the volumes apply.")
w("- Subjective driving feel, difficulty fairness and fun.")
w("")
w("See `KX_TEST_CHECKLIST.md` for the manual procedure.")
open(os.path.join(ROOT, "TEST_REPORT.md"), "w").write("\n".join(out) + "\n")
print("TEST_REPORT.md written: %d headless checks, %d exported-build checks" % (res["passed"] + res["failed"], sum(len(d["checks"]) for _, d in verify_rows)))
