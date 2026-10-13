extends "res://tests/test_case.gd"
## Save data, settings persistence, menus and pause.


func test_save_round_trip() -> void:
	var g := game()
	g.data["unlocked"] = 3
	g.data["completed"]["alley"] = true
	g.data["best_scores"]["alley"] = 12345
	g.data["best_ranks"]["alley"] = "A"
	g.data["golden"]["alley"] = true
	g.save_game()
	g.data = g.defaults()
	g.load_game()
	eq(int(g.data["unlocked"]), 3, "unlocks persist")
	check(g.is_completed(0), "completion persists")
	eq(g.best_score(0), 12345, "best score persists")
	eq(g.best_rank(0), "A", "best rank persists")
	check(g.has_golden(0), "golden fish persists")
	eq(int(g.data["version"]), 1, "save is versioned")


func test_malformed_save_falls_back() -> void:
	var sm: Node = tree.root.get_node("SaveManager")
	var f := FileAccess.open(sm.path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var g := game()
	g.load_game()
	eq(int(g.data["unlocked"]), 1, "defaults after a corrupt save")
	eq(sm.last_error, "malformed save", "error recorded")
	check(not FileAccess.file_exists(sm.path) or FileAccess.get_file_as_string(sm.path).begins_with("{ this") == false, "corrupt file moved aside")


func test_hand_edited_save_is_clamped() -> void:
	var sm: Node = tree.root.get_node("SaveManager")
	sm.write({"unlocked": 99, "best_scores": {"alley": -5, "nope": 3}, "best_ranks": {"alley": "Z"},
		"difficulty": "insane", "run": {"active": true, "level": 5, "lives": 400, "score": -1}})
	var g := game()
	g.load_game()
	eq(int(g.data["unlocked"]), 6, "unlocked clamped to 6")
	eq(g.best_score(0), 0, "negative score clamped")
	check(not g.data["best_scores"].has("nope"), "unknown level ignored")
	eq(g.best_rank(0), "D", "invalid rank sanitised")
	eq(String(g.data["difficulty"]), "normal", "invalid difficulty sanitised")
	eq(int(g.data["run"]["lives"]), 9, "lives clamped")
	sm.write({"unlocked": 2, "run": {"active": true, "level": 5}})
	g.load_game()
	eq(int(g.data["run"]["level"]), 1, "run level cannot exceed unlocked streets")


func test_unlocks_and_replay() -> void:
	var g := game()
	g.difficulty = "normal"
	g.play_level(0)
	var r1: Dictionary = g.record_level_complete({"level_score": 1000, "rank": "B"})
	check(bool(r1["unlocked_next"]) and bool(r1["first_clear"]), "first clear unlocks street 2")
	eq(int(g.data["unlocked"]), 2, "two streets unlocked")
	g.play_level(0)
	var r2: Dictionary = g.record_level_complete({"level_score": 500, "rank": "S"})
	check(not bool(r2["unlocked_next"]) and not bool(r2["first_clear"]), "replay does not unlock again")
	eq(int(g.data["unlocked"]), 2, "still two")
	eq(g.best_score(0), 1000, "lower replay score keeps the best")
	eq(g.best_rank(0), "S", "better rank replaces the old one")
	g.play_level(0)
	g.record_level_complete({"level_score": 2000, "rank": "C"})
	eq(g.best_score(0), 2000, "higher replay score saved")
	eq(g.best_rank(0), "S", "worse rank never overwrites")


func test_continue_campaign_resumes_run() -> void:
	var g := game()
	g.new_campaign("hard")
	eq(g.lives, 2, "hard = 2 lives")
	eq(g.continues_left, 2, "hard = 2 continues")
	g.score = 4321
	g.level_index = 0
	g.record_level_complete({"level_score": 4321, "rank": "B"})
	g.data = g.defaults()
	g.load_game()
	g.difficulty = "normal"
	g.continue_campaign()
	eq(g.level_index, 1, "continue resumes at street 2")
	eq(g.difficulty, "hard", "with the run's difficulty")
	eq(g.score, 4321, "and its score")


func test_reset_progress() -> void:
	var g := game()
	g.data["unlocked"] = 4
	g.data["campaign_complete"] = true
	g.save_game()
	g.reset_progress()
	eq(int(g.data["unlocked"]), 1, "reset")
	check(not g.has_progress(), "no progress after reset")
	g.load_game()
	eq(int(g.data["unlocked"]), 1, "reset persisted")


func test_settings_persist() -> void:
	var st: Node = tree.root.get_node("Settings")
	st.set_volume("music", 0.25)
	st.set_volume("sfx", 0.4)
	st.set_volume("master", 0.9)
	st.set_screen_shake(false)
	st.master_volume = 0.0
	st.music_volume = 0.0
	st.load_settings()
	near(st.music_volume, 0.25, 0.001, "music volume persists")
	near(st.sfx_volume, 0.4, 0.001, "sfx volume persists")
	near(st.master_volume, 0.9, 0.001, "master volume persists")
	eq(st.screen_shake, false, "screen shake setting persists")
	var bus := AudioServer.get_bus_index("Music")
	check(bus >= 0, "Music bus exists")
	near(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.25, 0.01, "music bus volume applied")
	check(AudioServer.get_bus_index("SFX") >= 0, "SFX bus exists")


func test_input_actions_registered() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "special", "grab", "run", "pause"]:
		check(InputMap.has_action(a), "action " + a)
		var keys := 0
		var pads := 0
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				keys += 1
			elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				pads += 1
		check(keys >= 1, a + " has a key")
		check(pads >= 1, a + " has a gamepad binding")


func test_main_menu_buttons() -> void:
	var g := game()
	var menu: Node = await spawn_scene("res://scenes/main_menu.tscn")
	var cont: Button = menu.find_child("Continue", true, false)
	check(cont.disabled, "Continue disabled without progress")
	var ls: Button = menu.find_child("LevelSelect", true, false)
	check(ls.disabled, "Level select locked at first")
	for id in ["Settings", "Controls", "Credits"]:
		var b: Button = menu.find_child(id, true, false)
		b.pressed.emit()
		await frames(2)
		var win: String = {"Settings": "SettingsWindow", "Controls": "ControlsWindow", "Credits": "CreditsWindow"}[id]
		var w: Node = menu.find_child(win, true, false)
		check(w != null, id + " opens its window")
		var close: Button = w.find_child("Close", true, false) if w else null
		check(close != null, id + " window has Close")
		if close:
			close.pressed.emit()
			await frames(2)
			check(menu.find_child(win, true, false) == null, id + " window closes")
	(menu.find_child("NewGame", true, false) as Button).pressed.emit()
	await frames(2)
	var dw: Node = menu.find_child("DifficultyWindow", true, false)
	check(dw != null, "New Game asks for difficulty")
	(dw.find_child("Diff_easy", true, false) as Button).pressed.emit()
	await tree.root.get_node("Transition").finished
	check(tree.current_scene.has_method("compute_result"), "New Game starts street 1")
	eq(g.difficulty, "easy", "difficulty chosen")
	eq(g.lives, 5, "easy = 5 lives")
	tree.current_scene.set_physics_process(false)
	var menu2: Node = await spawn_scene("res://scenes/main_menu.tscn")
	check(not (menu2.find_child("Continue", true, false) as Button).disabled, "Continue enabled once a run exists")
	g.data["unlocked"] = 3
	g.progress_changed.emit()
	check(not (menu2.find_child("LevelSelect", true, false) as Button).disabled, "Level select enabled")
	(menu2.find_child("LevelSelect", true, false) as Button).pressed.emit()
	await frames(2)
	var l3: Button = menu2.find_child("Level3", true, false)
	var l4: Button = menu2.find_child("Level4", true, false)
	check(l3 != null and not l3.disabled, "street 3 selectable")
	check(l4 != null and l4.disabled, "street 4 locked")
	l3.pressed.emit()
	await tree.root.get_node("Transition").finished
	eq(g.level_index, 2, "level select loads street 3")
	tree.current_scene.set_physics_process(false)


func test_pause_and_resume() -> void:
	var lv: Node = await start_level(0, 0)
	lv.overlays.open_pause()
	check(tree.paused, "tree paused")
	var pm: Node = lv.overlays.root.find_child("PauseMenu", true, false)
	check(pm != null, "pause menu shown")
	for id in ["Resume", "RestartCheckpoint", "RestartLevel", "Settings", "Controls", "MainMenu"]:
		check(pm.find_child(id, true, false) is Button, "pause has " + id)
	(pm.find_child("Settings", true, false) as Button).pressed.emit()
	await frames(2)
	check(lv.overlays.root.find_child("SettingsWindow", true, false) != null, "settings open from pause")
	(lv.overlays.root.find_child("SettingsWindow", true, false).find_child("Close", true, false) as Button).pressed.emit()
	await frames(2)
	(pm.find_child("Resume", true, false) as Button).pressed.emit()
	await frames(2)
	check(not tree.paused, "resumed")
	check(lv.overlays.root.get_child_count() == 0, "pause menu removed")
	var x0: float = lv.player.position.x
	(game().bot_input as Pad).move = Vector2(1, 0)
	step(lv, 20)
	check(lv.player.position.x > x0, "control works after resume")


func test_pause_main_menu_confirm() -> void:
	var lv: Node = await start_level(0, 0)
	lv.overlays.open_pause()
	var pm: Node = lv.overlays.root.find_child("PauseMenu", true, false)
	(pm.find_child("MainMenu", true, false) as Button).pressed.emit()
	await frames(2)
	var yes: Button = null
	for b in lv.overlays.root.find_children("*", "Button", true, false):
		if (b as Button).text == "Quit":
			yes = b
	check(yes != null, "quit asks for confirmation")
	yes.pressed.emit()
	await tree.root.get_node("Transition").finished
	eq(tree.current_scene.scene_file_path, "res://scenes/main_menu.tscn", "back at the main menu")
	check(not tree.paused, "not paused in the menu")


func test_hud_reflects_state() -> void:
	var lv: Node = await start_level(3, 99)
	var hud: Node = lv.hud
	lv.player.hp = 37.0
	var v: Node = hud.view
	for i in 120:
		v._process(1.0 / 60.0)
	near(float(v.shown_hp), 37.0, 0.5, "HUD health bar follows the player")
	var b: Node = lv.spawn_boss("bruno")
	lv.boss_intro(b)
	check(v.boss == b, "boss health bar shown")
	lv.hud.hide_boss()
	check(v.boss == null, "boss bar hidden")
	lv.hud.show_go()
	check(v.go_t > 0.0, "GO arrow after a fight")
