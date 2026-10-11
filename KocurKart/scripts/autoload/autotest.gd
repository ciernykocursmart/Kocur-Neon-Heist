class_name Autotest
extends Node
## Release verification mode, used to test the exported executable outside
## the editor. Only active with an explicit command-line flag:
##   KocurKart.exe -- --autotest=race     boot, build all six tracks, run a full
##                                        autopilot race and check the save file
##   KocurKart.exe -- --autotest=verify   (second launch) check that progress
##                                        from the previous run was persisted
##   KocurKart.exe -- --autotest=shot     render a race frame to user://autotest_shot.png
## Writes user://autotest_<phase>.json and exits with code 0 (pass) or 1.

var phase := ""
var report := {"checks": []}
var _failed := false


static func requested() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			return a.substr(11)
	return ""


func start(p: String) -> void:
	phase = p
	report["phase"] = p
	report["version"] = ProjectSettings.get_setting("application/config/version")
	report["platform"] = OS.get_name()
	report["user_dir"] = OS.get_user_data_dir()
	report["godot"] = Engine.get_version_info()["string"]
	call_deferred("_run")


func _check(name: String, ok: bool, detail := "") -> void:
	report["checks"].append({"name": name, "passed": ok, "detail": detail})
	print("[AUTOTEST] %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_failed = true


func _run() -> void:
	await get_tree().process_frame
	await _wait_scene("MainMenu", 600)
	_check("main menu loads", get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu")
	match phase:
		"race":
			await _phase_race()
		"verify":
			_phase_verify()
		"shot":
			await _phase_shot()
		_:
			_check("known phase", false, phase)
	_finish()


func _phase_race() -> void:
	_check("audio assets loaded", Audio.streams.size() >= 40, "%d streams" % Audio.streams.size())
	_check("font loaded", UI.bold() != null and UI.regular() != null)
	for id in TrackCatalog.ORDER:
		var t0 := Time.get_ticks_msec()
		var tr := Track.new()
		add_child(tr)
		tr.setup(TrackCatalog.get_track(id))
		var ok := tr.main.size() > 100 and tr.get_child_count() > 10 and tr.racing_line != null
		_check("track builds: " + id, ok, "%d ms, %d nodes" % [Time.get_ticks_msec() - t0, tr.get_child_count()])
		tr.queue_free()
		await get_tree().process_frame
	var races_before := int(Save.data["stats"]["races"])
	Game.race_config = {"track": "whiskerwood", "mode": "single", "laps": 1, "difficulty": "normal",
		"player": Game.selection(), "autopilot": true, "seed": 7, "grid_slot": 3}
	Game.change_scene(Game.RACE_SCENE)
	await _wait_scene("Race", 900)
	var race = get_tree().current_scene
	_check("race scene starts", race is Race and race.entries.size() == 6)
	var frames := 0
	while race is Race and race.state != Race.State.RESULTS and frames < 60 * 240:
		await get_tree().physics_frame
		frames += 1
	_check("race finishes", race is Race and race.state == Race.State.RESULTS, "%.1f s race time" % (race.race_time if race is Race else 0.0))
	await get_tree().create_timer(2.5).timeout
	_check("results screen shown", race.get_node_or_null("Results") != null)
	var path := Save.base_dir().path_join("save.json")
	_check("save file written", FileAccess.file_exists(path), path)
	var fresh := Save.defaults()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_check("save file parses", raw is Dictionary)
	if raw is Dictionary:
		var sane := Save.sanitize(raw)
		_check("race recorded in save", int(sane["stats"]["races"]) == races_before + 1 and float(sane["records"]["whiskerwood"]["race_lap"]) > 0.0,
			"races %d, best lap %.2f" % [sane["stats"]["races"], sane["records"]["whiskerwood"]["race_lap"]])
		report["races_after"] = sane["stats"]["races"]
	Game.to_menu()
	await _wait_scene("MainMenu", 600)
	_check("returns to menu", get_tree().current_scene.name == "MainMenu")


func _phase_verify() -> void:
	var path := Save.base_dir().path_join("save.json")
	_check("save exists after restart", FileAccess.file_exists(path), path)
	_check("save loaded on boot", Save.load_status == "loaded", Save.load_status)
	_check("progress persisted across launches", int(Save.data["stats"]["races"]) >= 1 and float(Save.data["records"]["whiskerwood"]["race_lap"]) > 0.0,
		"races %d" % Save.data["stats"]["races"])
	_check("settings file exists", FileAccess.file_exists("user://settings.cfg"))


func _phase_shot() -> void:
	Game.race_config = {"track": "neon", "mode": "single", "laps": 1, "difficulty": "normal",
		"player": Game.selection(), "autopilot": true, "seed": 7, "persist": false}
	Game.change_scene(Game.RACE_SCENE)
	await _wait_scene("Race", 900)
	for i in 400:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var ok := img != null and img.get_width() > 0
	if ok:
		img.save_png("user://autotest_shot.png")
	_check("frame rendered", ok, "%dx%d" % [img.get_width(), img.get_height()] if ok else "")
	report["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_api_version()
	report["fps"] = Engine.get_frames_per_second()


func _wait_scene(scene_name: String, max_frames: int) -> void:
	for i in max_frames:
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name and not Game._busy:
			return
		await get_tree().process_frame


func _finish() -> void:
	report["passed"] = not _failed
	var f := FileAccess.open("user://autotest_%s.json" % phase, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[AUTOTEST] RESULT %s" % ("PASS" if not _failed else "FAIL"))
	get_tree().quit(0 if not _failed else 1)
