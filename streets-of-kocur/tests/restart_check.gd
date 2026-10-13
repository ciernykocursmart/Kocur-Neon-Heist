extends SceneTree
## Save persistence across a real application restart (two separate processes):
##   godot --headless --path . -s res://tests/restart_check.gd -- write
##   godot --headless --path . -s res://tests/restart_check.gd -- verify
## "write" starts a Hard campaign, lets the autoplay bot clear street 1 through
## the real level scene, changes settings and exits. "verify" is a fresh
## process that must load all of it back. Uses its own files, never the real save.

const Bot = preload("res://scripts/debug/autoplay_bot.gd")
const SAVE := "user://restart_save.json"
const CFG := "user://restart_settings.cfg"
const EXPECT := "user://restart_expect.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "write"
	var sm: Node = root.get_node("SaveManager")
	var st: Node = root.get_node("Settings")
	var game: Node = root.get_node("Game")
	sm.path = SAVE
	st.path = CFG
	var fail := 0
	if mode == "write":
		for f in [SAVE, CFG, EXPECT]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		game.data = game.defaults()
		game.new_campaign("hard")
		game.god_mode = true
		game.bot_input = Bot.new()
		change_scene_to_file("res://scenes/level.tscn")
		await process_frame
		await process_frame
		var lv: Node = current_scene
		lv.set_physics_process(false)
		var n := 0
		while lv.flow != "results" and n < 60 * 600:
			lv._physics_process(1.0 / 60.0)
			n += 1
		game.god_mode = false
		game.bot_input = null
		st.set_volume("music", 0.35)
		st.set_screen_shake(false)
		var expect := {"score": game.score, "best": game.best_score(0), "rank": game.best_rank(0), "flow": lv.flow}
		var f := FileAccess.open(EXPECT, FileAccess.WRITE)
		f.store_string(JSON.stringify(expect))
		f.close()
		print("RESTART WRITE: ", JSON.stringify(expect))
		if lv.flow != "results":
			fail += 1
			print("FAIL  street 1 was not cleared")
	else:
		game.load_game()
		st.load_settings()
		var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
		var checks := [
			[game.has_progress(), "progress found"],
			[String(game.data["difficulty"]) == "hard", "difficulty hard"],
			[game.is_completed(0), "street 1 completed"],
			[game.is_unlocked(1), "street 2 unlocked"],
			[game.best_score(0) == int(expect["best"]) and int(expect["best"]) > 0, "best score %d" % int(expect["best"])],
			[game.best_rank(0) == String(expect["rank"]), "best rank %s" % String(expect["rank"])],
			[bool(game.data["run"]["active"]) and int(game.data["run"]["level"]) == 1, "run continues at street 2"],
			[int(game.data["run"]["score"]) == int(expect["score"]), "run score %d" % int(expect["score"])],
			[absf(st.music_volume - 0.35) < 0.001, "music volume"],
			[st.screen_shake == false, "screen shake off"],
		]
		for c: Array in checks:
			print(("ok    " if c[0] else "FAIL  ") + "after restart: " + c[1])
			if not c[0]:
				fail += 1
		game.continue_campaign()
		var ok: bool = game.level_index == 1 and game.difficulty == "hard" and game.score == int(expect["score"])
		print(("ok    " if ok else "FAIL  ") + "after restart: Continue resumes street 2 with the saved score")
		if not ok:
			fail += 1
		# Replaying street 1 after the restart must not unlock anything twice.
		game.play_level(0)
		var rw: Dictionary = game.record_level_complete({"level_score": 1, "rank": "D"})
		ok = not rw["first_clear"] and not rw["unlocked_next"] and game.best_score(0) == int(expect["best"])
		print(("ok    " if ok else "FAIL  ") + "after restart: replay keeps bests and gives no duplicate unlock")
		if not ok:
			fail += 1
		for f in [SAVE, CFG, EXPECT]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("RESTART %s: %s" % [mode.to_upper(), "PASS" if fail == 0 else "%d FAILED" % fail])
	quit(1 if fail > 0 else 0)
