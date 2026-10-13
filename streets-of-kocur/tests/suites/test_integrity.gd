extends "res://tests/test_case.gd"
## Project integrity: scenes, scripts, resources and level data.


func test_main_scene_loads() -> void:
	var main: String = ProjectSettings.get_setting("application/run/main_scene")
	eq(main, "res://scenes/main_menu.tscn", "main scene path")
	var menu: Node = await spawn_scene(main)
	check(menu != null, "main menu instantiated")
	for id in ["NewGame", "Continue", "LevelSelect", "Settings", "Controls", "Credits", "Reset", "Quit"]:
		check(menu.find_child(id, true, false) is Button, "menu button " + id)


func test_all_scripts_load() -> void:
	var files: Array = []
	_scan("res://scripts", files)
	check(files.size() >= 35, "found %d scripts" % files.size())
	for f: String in files:
		var s: Script = load(f)
		check(s != null and s.can_instantiate(), "script compiles: " + f)


func _scan(d: String, out: Array) -> void:
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gd"):
			out.append(d + "/" + f)
	for sub in DirAccess.get_directories_at(d):
		_scan(d + "/" + sub, out)


func test_scenes_instantiate() -> void:
	for path in ["res://scenes/main_menu.tscn", "res://scenes/level.tscn", "res://scenes/ending.tscn"]:
		var ps: PackedScene = load(path)
		check(ps != null and ps.can_instantiate(), "scene loads: " + path)
		var n: Node = await spawn_scene(path)
		check(n != null and n.get_script() != null, "scene has its script: " + path)


func test_audio_resources() -> void:
	var audio: Node = tree.root.get_node("Audio")
	for s: String in audio.SFX_NAMES:
		check(audio.streams.has(s), "sound effect loaded: " + s)
	for m: String in audio.MUSIC_NAMES:
		check(audio._music_stream(m) != null, "music loaded: " + m)
	for lv: Dictionary in Levels.LEVELS:
		check(String(lv["music"]) in audio.MUSIC_NAMES, "level music exists for " + String(lv["id"]))


func test_level_data_valid() -> void:
	eq(Levels.count(), 6, "six levels")
	var themes := {}
	var half := 640.0 / 1.35
	for i in Levels.count():
		var lv := Levels.get_level(i)
		var id: String = lv["id"]
		themes[lv["theme"]] = true
		var y0: float = lv["depth"][0]
		var y1: float = lv["depth"][1]
		var last_x := 0.0
		var encs: Array = lv["encounters"]
		check(encs.size() >= 3 or i == 5, "%s has enough encounters" % id)
		check(bool(encs[-1].get("final", false)), "%s last encounter is final" % id)
		for e: Dictionary in encs:
			check(float(e["x"]) > last_x + 600.0, "%s encounters spaced" % id)
			check(float(e["x"]) >= half and float(e["x"]) <= float(lv["length"]) - half + 1.0, "%s encounter %d inside level" % [id, int(e["x"])])
			last_x = float(e["x"])
			check(not (e["waves"] as Array).is_empty() or e.has("boss"), "%s encounter has enemies" % id)
			for w: Array in e["waves"]:
				check(w.size() >= 1 and w.size() <= 5, "%s wave size ok" % id)
				for k: String in w:
					check(B.ENEMIES.has(k.trim_suffix("<")), "%s enemy kind %s" % [id, k])
			if e.has("boss"):
				check(B.BOSSES.has(String(e["boss"])), "%s boss %s" % [id, e["boss"]])
		var golden := 0
		for p: Dictionary in lv["pickups"]:
			check(float(p["x"]) > 0 and float(p["x"]) < float(lv["length"]) and float(p["y"]) >= y0 and float(p["y"]) <= y1, "%s pickup inside" % id)
		for p: Dictionary in lv["props"]:
			check(float(p["x"]) > 0 and float(p["x"]) < float(lv["length"]) and float(p["y"]) >= y0 and float(p["y"]) <= y1, "%s prop inside" % id)
			check(String(p.get("drop", "")) == "" or B.PICKUPS.has(String(p["drop"])), "%s drop kind" % id)
			if p.get("drop", "") == "golden":
				golden += 1
		eq(golden, 1, "%s hides exactly one golden fish" % id)
		check(Levels.food_total(i) >= 3, "%s has food (%d)" % [id, Levels.food_total(i)])
		check(Levels.food_total(i) <= 8, "%s limits healing (%d)" % [id, Levels.food_total(i)])
		for o: Dictionary in lv["obstacles"]:
			check(float(o["y0"]) >= y0 and float(o["y1"]) <= y1 and float(o["y1"]) - float(o["y0"]) < y1 - y0 - 60.0, "%s obstacle leaves a path" % id)
		check(String(lv["challenge"]["type"]) in ["combo", "damage", "no_special", "no_death"], "%s challenge type" % id)
	eq(themes.size(), 6, "six distinct stage themes")
	var bosses := 0
	for i in 6:
		bosses += int(Levels.has_boss(i))
	eq(bosses, 4, "three lieutenants/mini-bosses + final boss")
	eq(String(Levels.get_level(5)["encounters"][-1]["boss"]), "lardpaw", "final boss is Lardpaw")


func test_every_archetype_spawns() -> void:
	var lv: Node = await arena()
	for k: String in B.ENEMIES:
		var e: Node = add_enemy(lv, k, Vector2(1200, 560))
		check(e is Enemy and e.kind == k and e.hp > 0.0, "spawned " + k)
	for b: String in B.BOSSES:
		var boss: Node = lv.spawn_boss(b)
		check(boss is Boss and boss.display_name != "", "spawned boss " + b)
	step(lv, 30)
	check(lv.enemies().size() == B.ENEMIES.size() + B.BOSSES.size(), "all alive after stepping")
