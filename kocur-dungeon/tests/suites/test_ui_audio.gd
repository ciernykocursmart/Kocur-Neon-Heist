extends "res://tests/test_case.gd"
## Menus, pause, settings persistence, camp, HUD, death/results/ending
## screens and the audio manager (buses, music switching, no leaks).

const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")


func _wait_scene(not_this: Node, frames_max := 200) -> Node:
	var tr: Node = tree.root.get_node("Transition")
	for i in frames_max:
		await process_frames(1)
		var cur := tree.current_scene
		if cur != null and cur != not_this and is_instance_valid(cur) and not tr.busy:
			return cur
	return tree.current_scene


func _press(b: Button) -> void:
	check(b != null and not b.disabled, "button available: %s" % (b.text if b else "null"))
	if b and not b.disabled:
		b.pressed.emit()
	await process_frames(2)


func _find_button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and b.is_visible_in_tree():
			return b
	return null


func test_main_menu_without_save() -> void:
	var m := await spawn_scene("res://scenes/main_menu.tscn")
	for k in ["continue", "new", "levels", "upgrades", "settings", "credits", "quit"]:
		check(m.buttons.has(k), "main menu has " + k)
	check(m.buttons["continue"].disabled, "Continue disabled without a save")
	check(m.buttons["levels"].disabled, "Level Select disabled without a save")
	check(not m.buttons["new"].disabled, "New Game available")
	eq(Audio.current_music, "menu", "menu music plays")


func test_new_game_flow_with_confirmation() -> void:
	Progress.new_game()
	Progress.data["coins"] = 77
	Progress.save_game()
	var m := await spawn_scene("res://scenes/main_menu.tscn")
	check(not m.buttons["continue"].disabled, "Continue enabled with a save")
	await _press(m.buttons["new"])
	eq(m.screen, "confirm", "New Game asks before overwriting")
	await _press(m.buttons["no"])
	eq(m.screen, "main", "No returns to the menu")
	eq(Progress.coins(), 77, "save untouched after No")
	await _press(m.buttons["new"])
	await _press(m.buttons["yes"])
	eq(m.screen, "intro", "story intro shown")
	eq(Progress.coins(), 0, "progress reset by New Game")
	await _press(m.buttons["begin"])
	var lvl := await _wait_scene(m)
	check(lvl != null and lvl.get("level_id") == "1-1", "Begin starts level 1-1")
	eq(Audio.current_music, "r1", "region 1 music in level 1-1")


func test_continue_opens_camp() -> void:
	Progress.new_game()
	var m := await spawn_scene("res://scenes/main_menu.tscn")
	await _press(m.buttons["continue"])
	var camp := await _wait_scene(m)
	check(camp != null and camp.has_method("show_tab"), "Continue opens the camp")
	eq(camp.tab, "levels", "camp opens on the adventure tab")
	eq(Audio.current_music, "camp", "camp music")


func test_credits_and_back() -> void:
	var m := await spawn_scene("res://scenes/main_menu.tscn")
	await _press(m.buttons["credits"])
	eq(m.screen, "credits", "credits shown")
	await _press(m.buttons["back"])
	eq(m.screen, "main", "back to the main menu")


func test_settings_persist() -> void:
	var sp := SettingsPanel.new()
	tree.root.add_child(sp)
	await process_frames(2)
	Settings.set_volume("music", 0.25)
	Settings.set_volume("sfx", 0.5)
	Settings.set_volume("master", 0.0)
	Settings.set_difficulty("hard")
	Settings.screen_shake = false
	Settings.resolution_index = 2
	Settings.save_settings()
	var bus := AudioServer.get_bus_index("Music")
	near(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25), 0.01, "music bus follows the slider")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "master at 0 mutes")
	Settings.reset_defaults()
	Settings.load_settings()
	near(Settings.music_volume, 0.25, 0.001, "music volume saved")
	near(Settings.sfx_volume, 0.5, 0.001, "sfx volume saved")
	eq(Settings.difficulty, "hard", "difficulty saved")
	eq(Settings.screen_shake, false, "screen shake saved")
	eq(Settings.resolution_index, 2, "window size saved")
	eq(Settings.RESOLUTIONS[2], Vector2i(1920, 1080), "1920x1080 option")
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string("garbage [[[")
	f.close()
	Settings.reset_defaults()
	Settings.load_settings()
	eq(Settings.difficulty, "normal", "broken settings file falls back to defaults")
	check(sp.find_children("*", "HSlider", true, false).size() == 3, "three volume sliders")
	check(sp.find_children("*", "OptionButton", true, false).size() == 2, "window size + difficulty pickers")
	sp.queue_free()


func test_settings_reset_progress_needs_confirmation() -> void:
	Progress.new_game()
	Progress.data["coins"] = 50
	Progress.save_game()
	var m := await spawn_scene("res://scenes/main_menu.tscn")
	await _press(m.buttons["settings"])
	var reset := _find_button(m, "Reset Progress")
	await _press(reset)
	eq(Progress.coins(), 50, "nothing erased before confirming")
	var yes := _find_button(m, "Yes, erase")
	if yes == null:
		for b in m.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Yes"):
				yes = b
	await _press(yes)
	eq(Progress.coins(), 0, "progress erased after confirming")
	check(not SaveManager.has_save(), "save file deleted")


func test_pause_menu() -> void:
	var lvl := await spawn_level("1-1")
	await frames(5)
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frames(3)
	check(lvl.pause_menu.is_open, "Esc opens the pause menu")
	check(tree.paused, "game paused")
	var x0: float = lvl.player.global_position.x
	press("move_right")
	await process_frames(10)
	release("move_right")
	eq(lvl.player.global_position.x, x0, "player frozen while paused")
	for t in ["Resume", "Restart from Checkpoint", "Restart Level", "Settings", "Return to Camp", "Main Menu"]:
		check(_find_button(lvl.pause_menu.root, t) != null, "pause menu has " + t)
	await _press(_find_button(lvl.pause_menu.root, "Settings"))
	check(_find_button(lvl.pause_menu.root, "Controls") != null, "settings reachable from pause")
	await _press(_find_button(lvl.pause_menu.root, "Back"))
	await _press(_find_button(lvl.pause_menu.root, "Resume"))
	check(not lvl.pause_menu.is_open and not tree.paused, "Resume closes and unpauses")
	lvl.pause_menu.open()
	await process_frames(2)
	await _press(_find_button(lvl.pause_menu.root, "Main Menu"))
	check(_find_button(lvl.pause_menu.root, "Yes") != null, "quitting to the menu asks for confirmation")
	await _press(_find_button(lvl.pause_menu.root, "Yes"))
	var m := await _wait_scene(lvl)
	check(m != null and m.has_method("show_main"), "Main Menu returns to the title screen")
	check(not tree.paused, "tree unpaused after leaving")


func test_pause_restart_level() -> void:
	var lvl := await spawn_level("1-1")
	await frames(5)
	lvl.pause_menu.open()
	await process_frames(2)
	await _press(_find_button(lvl.pause_menu.root, "Restart Level"))
	await _press(_find_button(lvl.pause_menu.root, "Yes"))
	var again := await _wait_scene(lvl)
	check(again != null and again != lvl and again.get("level_id") == "1-1", "level restarted fresh")


func test_hud_reflects_state() -> void:
	var lvl := await spawn_level("1-1")
	await frames(5)
	var hud: Node = lvl.hud
	var p: CharacterBody2D = lvl.player
	await process_frames(2)
	eq(hud.hearts_box.get_child_count(), p.max_hp / 2, "one icon per heart")
	p.hurt(3, p.global_position, true)
	await process_frames(3)
	var names: Array[String] = []
	for c in hud.hearts_box.get_children():
		if not c.is_queued_for_deletion():
			names.append(c.texture.resource_path + str(c.texture.region))
	eq(names.size(), p.max_hp / 2, "heart icons rebuilt")
	lvl.run_coins["test"] = 5.0
	await process_frames(2)
	eq(hud.coin_label.text, str(Progress.coins() + 5), "coin counter includes this run's coins")
	eq(hud.gem_label.text, "0/%d" % lvl.gems_total, "gem counter")


func test_boss_bar_and_music() -> void:
	var lvl := await spawn_level("1-3")
	await frames(5)
	check(not lvl.hud.boss_panel.visible, "no boss bar before the fight")
	eq(Audio.current_music, "r1", "region music before the fight")
	lvl.player.invuln = 9999.0
	lvl.player.global_position = Vector2(lvl.boss_trigger_x + 30, lvl.boss.floor_y - 1)
	await frames(5)
	check(lvl.hud.boss_panel.visible, "boss health bar appears")
	eq(Audio.current_music, "boss", "boss music")
	lvl.boss.die()
	await frames(5)
	eq(Audio.current_music, "r1", "region music returns after the win")
	lvl = await spawn_level("final")
	lvl.player.invuln = 9999.0
	lvl.player.global_position = Vector2(lvl.boss_trigger_x + 30, lvl.boss.floor_y - 1)
	await frames(5)
	eq(Audio.current_music, "final", "the Pale King has his own theme")


func test_music_switching_never_stacks() -> void:
	for t in ["menu", "r1", "boss", "r2", "camp", "victory"]:
		Audio.play_music(t, 0.1)
		await process_frames(2)
		check(Audio.playing_music_count() <= 2, "at most two tracks while crossfading")
	await process_frames(30)
	for i in 30:
		await process_frames(1)
	check(Audio.playing_music_count() <= 1, "one music track after the crossfade")
	Audio.stop_music(0.05)
	for i in 30:
		await process_frames(1)
	eq(Audio.playing_music_count(), 0, "stop_music silences music")
	for name in ["Music", "SFX"]:
		check(AudioServer.get_bus_index(name) >= 0, "%s bus exists" % name)
	eq(Audio.MUSIC_NAMES.size(), 10, "ten music tracks")
	for t: String in Audio.MUSIC_NAMES:
		check(ResourceLoader.exists("res://assets/audio/music_%s.wav" % t), "music file " + t)
		var s: AudioStreamWAV = load("res://assets/audio/music_%s.wav" % t)
		eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "music file is imported looping: " + t)


func test_sfx_rate_limited() -> void:
	for i in 20:
		Audio.play("coin")
	var n := 0
	for p in Audio._pool:
		if p.playing and p.stream == Audio.streams["coin"]:
			n += 1
	check(n <= Audio.MAX_SAME, "same sound cannot stack endlessly (%d playing)" % n)


func test_camp_screens() -> void:
	Progress.new_game()
	Progress.data["coins"] = 1000
	Progress.commit_level("1-1", {"cats": [], "time": 30.0})
	Progress.data["rescued"].append("pip")
	Progress.save_game()
	var camp := await spawn_scene("res://scenes/camp.tscn")
	check(camp.level_buttons.has("1-1") and not camp.level_buttons["1-1"].disabled, "1-1 selectable")
	check(not camp.level_buttons["1-2"].disabled, "1-2 unlocked")
	check(camp.level_buttons["2-1"].disabled, "2-1 locked")
	camp.show_tab("upgrades")
	await process_frames(2)
	var coins: int = Progress.coins()
	await _press(camp.buy_buttons["heart"])
	eq(Progress.upgrade_level("heart"), 1, "bought an upgrade at camp")
	lt(Progress.coins(), coins, "coins spent")
	camp.show_tab("cats")
	await process_frames(2)
	var labels: Array[String] = []
	for l in camp.find_children("*", "Label", true, false):
		labels.append((l as Label).text)
	check(labels.has("Pip"), "rescued cat listed by name")
	check(labels.has("???"), "unrescued cats hidden")
	var cats_drawn := 0
	for c in camp._cats_root.get_children():
		if c is AnimatedSprite2D and not c.is_queued_for_deletion():
			cats_drawn += 1
	eq(cats_drawn, 2, "the hero and Pip sit by the campfire")
	camp.show_tab("records")
	await process_frames(2)
	camp.show_settings()
	await process_frames(2)
	check(camp.find_children("*", "HSlider", true, false).size() == 3, "settings open from camp")
	await _press(_find_button(camp, "Back"))
	eq(camp.tab, "records", "settings return to the tab they were opened from")
	camp.show_tab("levels")
	await process_frames(2)
	await _press(camp.level_buttons["continue"])
	var lvl := await _wait_scene(camp)
	check(lvl != null and lvl.get("level_id") == "1-2", "continue from camp loads the next level")


func test_death_screen_buttons() -> void:
	var lvl := await spawn_level("1-1")
	await frames(5)
	lvl.player.hurt(999, lvl.player.global_position, true)
	await frames(100)
	eq(lvl.overlays.state, "death", "defeat screen")
	for t in ["Retry from Checkpoint", "Restart Level", "Return to Camp"]:
		check(_find_button(lvl.overlays.root, t) != null, "defeat screen has " + t)
	await _press(_find_button(lvl.overlays.root, "Retry from Checkpoint"))
	await frames(3)
	check(not tree.paused and not lvl.player.is_dead(), "retry resumes play")


func test_ending_screen() -> void:
	Progress.new_game()
	Progress.data["rescued"] = ["pip", "soot"]
	var e := await spawn_scene("res://scenes/ending.tscn")
	eq(Audio.current_music, "victory", "victory music")
	eq(e.page, 0, "story page")
	await _press(e.continue_button)
	eq(e.page, 1, "stats page")
	await _press(e.continue_button)
	eq(e.page, 2, "credits page")
	check(_find_button(e, "Main Menu") != null, "ending offers the main menu")


func test_scene_changes_do_not_leak() -> void:
	var baseline := tree.root.get_child_count()
	for i in 3:
		await spawn_level("1-1")
		await spawn_scene("res://scenes/camp.tscn")
		await spawn_scene("res://scenes/main_menu.tscn")
	await clear_scene()
	eq(tree.root.get_child_count(), baseline, "no nodes left behind after many scene changes")
	eq(Audio.get_child_count(), Audio.POOL_SIZE + 2, "audio players are pooled, not duplicated")
