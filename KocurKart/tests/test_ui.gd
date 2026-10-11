extends Node
## UI and flow: main menu pages and buttons, every mode reachable, locked
## content disabled, pause/resume, settings panel, garage selection rules,
## results actions, HUD, audio cleanup and full scene transitions.

const DIR := "user://test_saves_ui"
var t


func run(suite) -> void:
	t = suite
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.path_override = DIR
	Save.data = Save.defaults()
	Save.save_game()
	await _main_menu()
	await _pause_and_settings()
	await _results_actions()
	await _garage()
	await _scene_flow()
	Save.path_override = ""
	Save.load_game()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _buttons(root: Node) -> Array:
	var out := []
	for b in root.find_children("*", "Button", true, false):
		out.append(b)
	return out


func _texts(root: Node) -> Array:
	return _buttons(root).map(func(b): return b.text)


func _main_menu() -> void:
	var menu: Node = load("res://scripts/ui/main_menu.gd").new()
	add_child(menu)
	await t.frames(3)
	var texts := _texts(menu.content)
	var expected := ["Grand Prix", "Single Race", "Time Trial", "Garage", "Records & Progress", "Settings", "Credits", "Quit"]
	var all := true
	for e in expected:
		if not (e in texts):
			all = false
	t.check(all, "Main menu shows every required entry", ", ".join(texts))
	menu._page_gp()
	await t.frames(2)
	var cups := _buttons(menu.content).filter(func(b): return b.text.begins_with("Whisker Cup") or b.text.begins_with("Moonlight Cup") or b.text.begins_with("Royal Cup"))
	var states := cups.map(func(b): return not b.disabled)
	t.check(cups.size() == 3 and states == [true, false, false], "Grand Prix page: Cup 1 open, later cups locked", str(states))
	var locked_text: String = cups[1].text if cups.size() > 1 else ""
	t.check(locked_text.contains("Locked"), "Locked cups say how to unlock them", locked_text.replace("\n", " | "))
	menu._page_single()
	await t.frames(2)
	var single := _texts(menu.content)
	t.check("Start Race" in single and "Garage" in single, "Single Race page offers start and kart setup", "")
	var neon_btn := _buttons(menu.content).filter(func(b): return b.text.begins_with("Neon Catway"))
	t.check(neon_btn.size() == 1 and neon_btn[0].disabled, "Locked tracks cannot be selected", "")
	menu._page_tt()
	await t.frames(2)
	t.check("Start" in _texts(menu.content), "Time Trial page offers start", "")
	menu._page_records()
	await t.frames(2)
	t.check("Reset Progress" in _texts(menu.content), "Records page shows progress and reset", "")
	menu._page_credits()
	await t.frames(2)
	t.check("Back" in _texts(menu.content), "Credits page reachable", "")
	menu._open_settings()
	await t.frames(2)
	var panel_ok := menu._overlay != null and "Controls" in _texts(menu._overlay)
	t.check(panel_ok, "Settings opens from the menu", "")
	if menu._overlay:
		menu._overlay._close()
	await t.frames(2)
	t.check(Audio.current_music() == "menu", "Menu music plays", Audio.current_music())
	menu.queue_free()
	await t.frames(2)


func _pause_and_settings() -> void:
	var race := RaceHelper.make_race(self, {"track": "purrport", "ui": true})
	await t.physics_frames(30)
	var pm = race.get_node("PauseMenu")
	pm.pause()
	await t.frames(2)
	var paused := get_tree().paused
	var tpos := race.player.kart.global_position
	await t.frames(30)
	t.check(paused and race.player.kart.global_position == tpos, "Pause freezes the race", "")
	var texts := _texts(pm.root)
	t.check("Resume" in texts and "Restart Race" in texts and "Settings" in texts and "Quit to Menu" in texts, "Pause menu offers resume/restart/settings/quit", ", ".join(texts))
	pm.resume()
	await t.physics_frames(5)
	t.check(not get_tree().paused, "Resume continues the race", "")
	t.check(race.get_node_or_null("HUD") != null and race.get_node_or_null("RaceAudio") != null, "HUD and race audio are present", "")
	t.check(Audio.current_music() == "pier", "Track music follows the theme", Audio.current_music())
	race.queue_free()
	await t.physics_frames(2)


func _results_actions() -> void:
	var race := RaceHelper.make_race(self, {"track": "neon", "laps": 1, "ui": true, "mode": "single"})
	await RaceHelper.run_to_end(t, race, 200.0)
	await t.physics_frames(150)
	var rs = race.get_node_or_null("Results")
	var texts := _texts(rs.root) if rs else []
	t.check("Race Again" in texts and "Choose Track" in texts and "Main Menu" in texts, "Results offer replay, track select and menu", ", ".join(texts))
	race.queue_free()
	await t.physics_frames(2)
	var tt := RaceHelper.make_race(self, {"track": "purrport", "laps": 3, "ui": true, "mode": "time_trial"})
	await RaceHelper.run_to_end(t, tt, 200.0)
	await t.physics_frames(150)
	var rs2 = tt.get_node_or_null("Results")
	var texts2 := _texts(rs2.root) if rs2 else []
	t.check("Retry" in texts2, "Time Trial results allow an instant retry", ", ".join(texts2))
	tt.queue_free()
	await t.physics_frames(2)


func _garage() -> void:
	var g: Node = load("res://scripts/ui/garage.gd").new()
	add_child(g)
	await t.frames(3)
	g.sel["racer"] = "sushi"     # locked (champion)
	g.sel["paint"] = "midnight"  # unlocked
	g._refresh("racer")
	var locked_hint: String = g.info.text
	t.check(locked_hint.contains("LOCKED") and locked_hint.contains("three cups"), "Garage explains locked items", locked_hint.replace("\n", " | "))
	t.check(g.model != null, "Garage shows the kart model", "")
	g._done()
	await t.frames(2)
	t.check(Save.data["selection"]["racer"] == "kocur" and Save.data["selection"]["paint"] == "midnight", "Garage saves only unlocked choices", str(Save.data["selection"]))
	g.queue_free()
	await t.frames(2)


func _scene_flow() -> void:
	Game.change_scene(Game.MENU_SCENE)
	await _wait_scene("MainMenu")
	t.check(get_tree().current_scene and get_tree().current_scene.name == "MainMenu", "Main menu scene loads", "")
	Game.start_single("whiskerwood", "easy", 1)
	await _wait_scene("Race")
	var race = get_tree().current_scene
	t.check(race is Race and race.entries.size() == 6, "Single Race starts from the menu flow", "")
	await t.physics_frames(300)
	Game.to_menu()
	await _wait_scene("MainMenu")
	await t.frames(5)
	var leftover := get_tree().root.find_children("*", "Race", true, false).size()
	t.check(leftover == 0 and not get_tree().paused, "Returning to the menu frees the race", "%d races left" % leftover)
	Game.start_time_trial("purrport")
	await _wait_scene("Race")
	t.check(get_tree().current_scene is Race and get_tree().current_scene.mode == "time_trial", "Time Trial starts from the menu flow", "")
	Game.begin_grand_prix("cup1", "normal")
	Game._start_gp_race()
	await _wait_scene("Race")
	var gp_race = get_tree().current_scene
	t.check(gp_race is Race and gp_race.mode == "grand_prix" and gp_race.track.def["id"] == "whiskerwood", "Grand Prix starts with the cup's first track", "")
	Game.restart_race()
	await _wait_scene("Race")
	t.check(get_tree().root.find_children("*", "Race", true, false).size() == 1, "Restart via the game flow keeps a single race", "")
	Game.gp = {}
	Game.change_scene(Game.MENU_SCENE)
	await _wait_scene("MainMenu")
	await t.frames(3)


func _wait_scene(scene_name: String) -> void:
	for i in 600:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name and not Game._busy:
			return
