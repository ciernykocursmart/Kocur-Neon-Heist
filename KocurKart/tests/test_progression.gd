extends Node
## Progression and saves: points, trophies, unlock rules, records, medals,
## save/reload, corruption handling, backups, reset, settings persistence
## and audio bus routing. Uses a separate save folder.

const DIR := "user://test_saves"
var t


func run(suite) -> void:
	t = suite
	DirAccess.make_dir_recursive_absolute(DIR)
	_wipe()
	Save.path_override = DIR
	Save.load_game()
	_rules()
	_records()
	_grand_prix_flow()
	_save_reload()
	_corruption()
	await _abandoned_race()
	_reset()
	_settings_and_audio()
	Save.path_override = ""
	Save.load_game()
	_wipe()


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _rules() -> void:
	var pts := []
	for p in range(1, 8):
		pts.append(Progression.points_for(p))
	t.check(pts == [10, 7, 5, 3, 2, 1, 0], "Grand Prix points table", str(pts))
	t.check(Progression.trophy_for(1) == 3 and Progression.trophy_for(3) == 1 and Progression.trophy_for(4) == 0, "Trophy for cup standing", "")
	var d := Save.defaults()
	t.check(Progression.cup_unlocked(d, "cup1") and not Progression.cup_unlocked(d, "cup2") and not Progression.cup_unlocked(d, "cup3"), "Only the first cup is open on a new save", "")
	t.check(Progression.track_unlocked(d, "whiskerwood") and Progression.track_unlocked(d, "purrport") and not Progression.track_unlocked(d, "neon"), "Cup 1 tracks open, later tracks locked", "")
	Progression.record_cup(d, "cup1", 4, 10, "normal")
	t.check(not Progression.cup_unlocked(d, "cup2"), "4th place in a cup earns no trophy and no unlock", "trophy %d" % d["cups"]["cup1"]["trophy"])
	Progression.record_cup(d, "cup1", 3, 12, "normal")
	t.check(Progression.cup_unlocked(d, "cup2") and Progression.is_unlocked(d, "cup:cup1"), "A bronze trophy unlocks the next cup", "")
	t.check(Progression.is_unlocked(d, Catalog.KARTS["pounce"]["unlock"]) and not Progression.is_unlocked(d, Catalog.KARTS["thunder"]["unlock"]), "Kart unlocks follow cup results", "")
	Progression.record_cup(d, "cup1", 1, 20, "normal")
	t.check(int(d["cups"]["cup1"]["trophy"]) == 3 and int(d["cups"]["cup1"]["best_points"]) == 20, "Better results upgrade the trophy and best points", "")
	Progression.record_cup(d, "cup1", 5, 3, "easy")
	t.check(int(d["cups"]["cup1"]["trophy"]) == 3, "Worse results never downgrade a trophy", "")
	var fresh := Progression.collect_new_unlocks(d)
	var names := fresh.map(func(u): return u["name"])
	t.check("Pounce" in names and "Duchess" in names and "Moonlight Cup" in names, "New unlocks are reported once", ", ".join(names))
	t.check(Progression.collect_new_unlocks(d).is_empty(), "Unlock notifications are not repeated", "")
	t.check(Catalog.unlock_text("medal:neon:gold").contains("Neon Catway"), "Locked items explain how to earn them", Catalog.unlock_text("medal:neon:gold"))


func _records() -> void:
	var d := Save.defaults()
	var res := {"track": "whiskerwood", "mode": "time_trial", "laps": 3, "player_time": 130.0, "player_best_lap": 42.0, "player_position": 1, "valid": false}
	Progression.record_race(d, res)
	t.check(d["records"]["whiskerwood"]["tt_time"] == 0.0, "Invalid (unfinished) runs never create records", "")
	res["valid"] = true
	var r1 := Progression.record_race(d, res)
	t.check(r1["new_best_time"] and d["records"]["whiskerwood"]["tt_time"] == 130.0, "A valid run sets the record", str(r1))
	res["player_time"] = 140.0
	res["player_best_lap"] = 41.0
	var r2 := Progression.record_race(d, res)
	t.check(not r2["new_best_time"] and r2["new_best_lap"] and d["records"]["whiskerwood"]["tt_time"] == 130.0 and d["records"]["whiskerwood"]["tt_lap"] == 41.0, "Slower runs keep the record, faster laps update best lap", str(r2))
	var m: Array = TrackCatalog.TRACKS["whiskerwood"]["medals"]
	t.check(Progression.medal_for("whiskerwood", m[0] - 0.1) == 3 and Progression.medal_for("whiskerwood", m[1]) == 2 and Progression.medal_for("whiskerwood", m[2] + 1.0) == 0, "Medal thresholds", "")
	res["player_time"] = m[1] - 0.5
	var r3 := Progression.record_race(d, res)
	t.check(r3["medal"] == 2 and r3["medal_improved"] and Progression.is_unlocked(d, "medal:whiskerwood:silver"), "Silver medal is stored and unlocks its paint", str(r3))
	var race_res := {"track": "purrport", "mode": "single", "laps": 3, "player_time": 95.0, "player_best_lap": 30.0, "player_position": 1, "valid": true}
	Progression.record_race(d, race_res)
	t.check(d["stats"]["wins"] == 1 and d["records"]["purrport"]["race_time"] == 95.0 and d["records"]["purrport"]["tt_time"] == 0.0, "Race results update race records and stats only", "")
	race_res["laps"] = 1
	race_res["player_time"] = 30.0
	Progression.record_race(d, race_res)
	t.check(d["records"]["purrport"]["race_time"] == 95.0, "Shorter races never count as full-race records", "")


func _grand_prix_flow() -> void:
	Save.data = Save.defaults()
	Game.begin_grand_prix("cup1", "normal")
	var dummy := Race.new()
	dummy.cfg = {"persist": true}
	var rivals: Array = Game.gp["rivals"]
	var rows1 := [{"racer": rivals[0], "position": 1}, {"racer": "kocur", "position": 2}]
	for i in range(1, rivals.size()):
		rows1.append({"racer": rivals[i], "position": i + 2})
	var res1 := {"track": "whiskerwood", "mode": "grand_prix", "laps": 3, "difficulty": "normal", "rows": rows1,
		"player_position": 2, "player_time": 120.0, "player_best_lap": 39.0, "player_laps": [40, 40, 40], "valid": true}
	var s1 := Game.on_race_over(dummy, res1)
	t.check(not s1["gp"]["last"] and Game.gp["standings"]["kocur"] == 7 and Game.gp["standings"][rivals[0]] == 10, "Race 1 awards points to the standings", str(Game.gp["standings"]))
	Game.gp["index"] = 1
	var rows2 := [{"racer": "kocur", "position": 1}]
	for i in rivals.size():
		rows2.append({"racer": rivals[i], "position": i + 2})
	var res2 := res1.duplicate(true)
	res2["track"] = "purrport"
	res2["rows"] = rows2
	res2["player_position"] = 1
	var s2 := Game.on_race_over(dummy, res2)
	var st: Array = s2["gp"]["standings"]
	t.check(s2["gp"]["last"] and st[0]["racer"] == "kocur" and st[0]["points"] == 17, "Cup standings after two races", "leader %s with %d" % [st[0]["racer"], st[0]["points"]])
	t.check(s2["gp"]["trophy"] == 3 and Save.data["cups"]["cup1"]["trophy"] == 3, "Winning the cup awards and saves gold", "")
	t.check(Progression.cup_unlocked(Save.data, "cup2"), "Finishing Cup 1 unlocks Cup 2", "")
	var unames: Array = s2["unlocks"].map(func(u): return u["name"])
	t.check("Moonlight Cup" in unames, "Cup completion reports unlocks", ", ".join(unames))
	for c in ["cup2", "cup3"]:
		Progression.record_cup(Save.data, c, 2, 14, "normal")
	t.check(Progression.champion(Save.data) and Progression.is_unlocked(Save.data, "champion"), "All three cups complete the championship", "")
	Game.gp = {}


func _save_reload() -> void:
	Save.data = Save.defaults()
	Save.data["records"]["neon"]["tt_time"] = 101.5
	Save.data["cups"]["cup2"]["trophy"] = 2
	Save.data["selection"]["paint"] = "cyan"
	var ok := Save.save_game()
	var before := JSON.stringify(Save.data)
	Save.data = {}
	Save.load_game()
	t.check(ok and Save.load_status == "loaded" and JSON.stringify(Save.data) == before, "Save and reload preserve progress", "status %s" % Save.load_status)
	t.check(FileAccess.file_exists(DIR.path_join("save.json")) and not FileAccess.file_exists(DIR.path_join("save.tmp")), "Atomic save leaves no temp file", "")
	Save.save_game()
	t.check(FileAccess.file_exists(DIR.path_join("save.bak")), "Previous save is kept as a backup", "")


func _corruption() -> void:
	# Garbage main file + valid backup: recover from the backup.
	var f := FileAccess.open(DIR.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{this is not json")
	f.close()
	Save.load_game()
	t.check(Save.load_status == "recovered" and Save.data["records"]["neon"]["tt_time"] == 101.5, "Corrupt save is recovered from the backup", "status %s" % Save.load_status)
	# Garbage everywhere: start fresh, keep a copy, never crash.
	for name in ["save.json", "save.bak", "save.tmp"]:
		var g := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
		g.store_string("\u0000\u0001 garbage")
		g.close()
	Save.load_game()
	t.check(Save.load_status == "reset_corrupt" and Save.data["cups"]["cup1"]["trophy"] == 0 and FileAccess.file_exists(DIR.path_join("save.corrupt.json")), "Unreadable save falls back to defaults safely", "status %s" % Save.load_status)
	# Wrong types and out-of-range values are sanitised.
	var bad := {"version": 1, "cups": {"cup1": {"trophy": 99, "best_points": "lots"}}, "records": {"neon": {"tt_time": -5, "tt_medal": 7}, "fake": {}},
		"selection": {"racer": "dog", "kart": 5, "paint": "cyan"}, "stats": "none", "recent": [1, 2, {"track": "neon", "position": 1}], "last_laps": 99}
	var s := Save.sanitize(bad)
	var ok: bool = s["cups"]["cup1"]["trophy"] == 3 and s["cups"]["cup1"]["best_points"] == 0 and s["records"]["neon"]["tt_time"] == 0.0 \
		and s["records"]["neon"]["tt_medal"] == 3 and not s["records"].has("fake") and s["selection"]["racer"] == "kocur" \
		and s["selection"]["kart"] == "alley" and s["selection"]["paint"] == "cyan" and s["stats"]["races"] == 0 \
		and s["recent"].size() == 1 and s["last_laps"] == 5 and s["cups"].has("cup3")
	t.check(ok, "Partially corrupted data is repaired field by field", JSON.stringify(s).substr(0, 160))


func _abandoned_race() -> void:
	Save.data = Save.defaults()
	Save.save_game()
	var before := JSON.stringify(Save.data)
	var race := RaceHelper.make_race(self, {"track": "whiskerwood", "persist": true})
	await t.physics_frames(60 * 12)
	race.queue_free()
	await t.physics_frames(2)
	Save.load_game()
	t.check(JSON.stringify(Save.data) == before, "An abandoned race leaves no records or stats", "")


func _reset() -> void:
	Save.data["records"]["royal"]["tt_time"] = 150.0
	Save.data["cups"]["cup1"]["trophy"] = 3
	Save.save_game()
	var gf := FileAccess.open(DIR.path_join("ghost_royal.json"), FileAccess.WRITE)
	gf.store_string("{}")
	gf.close()
	Save.reset_progress()
	Save.load_game()
	t.check(Save.data["records"]["royal"]["tt_time"] == 0.0 and Save.data["cups"]["cup1"]["trophy"] == 0 and not FileAccess.file_exists(DIR.path_join("ghost_royal.json")), "Reset progress clears records, trophies and ghosts", "")


func _settings_and_audio() -> void:
	var file := "user://test_settings.cfg"
	Settings.file_override = file
	var keep := Settings.values.duplicate(true)
	Settings.set_value("music_volume", 0.3)
	Settings.set_value("sfx_volume", 0.0)
	Settings.set_value("camera_distance", 1.2)
	Settings.values = {}
	Settings.load_settings()
	Settings.apply_all()
	t.check(is_equal_approx(float(Settings.get_value("music_volume")), 0.3) and is_equal_approx(float(Settings.get_value("camera_distance")), 1.2), "Settings persist across reloads", "")
	t.check(absf(Settings.bus_linear("Music") - 0.3) < 0.01 and Settings.bus_linear("SFX") == 0.0, "Volume sliders drive the correct audio buses", "music %.2f sfx %.2f" % [Settings.bus_linear("Music"), Settings.bus_linear("SFX")])
	Settings.set_value("sfx_volume", 0.7)
	t.check(absf(Settings.bus_linear("SFX") - 0.7) < 0.01 and absf(Settings.bus_linear("Music") - 0.3) < 0.01, "Effects volume does not touch music", "")
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string("[settings]\nmusic_volume=\"loud\"\nresolution=\"99x99\"\nmax_fps=7\n")
	f.close()
	Settings.load_settings()
	t.check(float(Settings.get_value("music_volume")) == Settings.DEFAULTS["music_volume"] and Settings.get_value("resolution") == Settings.DEFAULTS["resolution"] and int(Settings.get_value("max_fps")) == 0, "Invalid settings fall back to defaults", "")
	t.check(Audio.streams.size() >= 40, "All audio assets load", "%d streams" % Audio.streams.size())
	DirAccess.remove_absolute(file)
	Settings.file_override = ""
	Settings.values = keep
	Settings.apply_all()
