extends SceneTree
## Smoke test for an exported build: loads the game's pack (embedded in the
## Windows .exe) with the Linux editor binary and exercises it headless:
##   godot --headless --main-pack build/windows/StreetsOfKocur.exe -s $PWD/tools/pack_smoke.gd
## It cannot prove the .exe itself starts on Windows - only that the exported
## content (scenes, scripts, audio, level data) is complete and runs.
## The scripted player lives in the shipped scripts/debug/autoplay_bot.gd and
## is only ever enabled by tests like this one.

var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	print(("ok    " if cond else "FAIL  ") + msg)
	if not cond:
		_fail += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_transition() -> void:
	var tr: Node = root.get_node("Transition")
	for i in 240:
		await process_frame
		if not tr.busy:
			break
	await _frames(3)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "verify":
		await _verify_restart()
		return
	_check(ProjectSettings.get_setting("application/config/name") == "Streets of Kocur", "pack is Streets of Kocur")
	_check(not ResourceLoader.exists("res://tests/run_tests.gd"), "tests are not shipped")
	_check(not FileAccess.file_exists("res://tools/gen_audio.py"), "tools are not shipped")
	for n in ["Settings", "SaveManager", "Game", "Audio", "Transition"]:
		_check(root.has_node(n), "autoload " + n)
	root.get_node("SaveManager").path = "user://smoke_save.json"
	root.get_node("Settings").path = "user://smoke_settings.cfg"
	var game: Node = root.get_node("Game")
	game.data = game.defaults()
	var audio: Node = root.get_node("Audio")
	for s in audio.SFX_NAMES:
		_check(audio.streams.has(s), "sound " + s)
	for m in audio.MUSIC_NAMES:
		_check(audio._music_stream(m) != null, "music " + m)
	for scene in ["res://scenes/main_menu.tscn", "res://scenes/ending.tscn"]:
		change_scene_to_file(scene)
		await _frames(20)
		_check(current_scene != null and current_scene.scene_file_path == scene, "runs " + scene)
	# Every street loads and runs a few seconds.
	for i in 6:
		game.play_level(i)
		change_scene_to_file("res://scenes/level.tscn")
		await _frames(30)
		var lv: Node = current_scene
		_check(lv != null and lv.has_method("compute_result") and int(lv.data["num"]) == i + 1, "street %d loads" % (i + 1))
	# A real encounter + food + level transition through the level scene, with the bot.
	var Bot: GDScript = load("res://scripts/debug/autoplay_bot.gd")
	game.new_campaign("normal")
	game.bot_input = Bot.new()
	change_scene_to_file("res://scenes/level.tscn")
	await _frames(5)
	var lv: Node = current_scene
	lv.set_physics_process(false)
	var n := 0
	while lv.enc.next_index() == 0 and n < 60 * 120:
		lv._physics_process(1.0 / 60.0)
		n += 1
	_check(lv.enc.next_index() == 1, "first encounter of street 1 cleared by the bot (%.0f s)" % (n / 60.0))
	_check(int(game.attempt["enemies"]) >= 1, "enemies defeated: %d" % int(game.attempt["enemies"]))
	lv.player.hp = 30.0
	var pk: Node = lv._add_pickup("chicken", "smoke", lv.player.position, false)
	pk.t = 1.0
	lv.hitstop = 0
	lv._physics_process(1.0 / 60.0)
	_check(absf(lv.player.hp - 70.0) < 0.01, "chicken healed 30 -> %d" % int(lv.player.hp))
	game.god_mode = true
	while lv.flow != "results" and n < 60 * 600:
		lv._physics_process(1.0 / 60.0)
		n += 1
	_check(lv.flow == "results", "street 1 cleared")
	var cont: Button = lv.overlays.root.find_child("Continue", true, false) as Button
	_check(cont != null, "Next street button on the results screen")
	if cont:
		cont.pressed.emit()
		await _wait_transition()
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/level.tscn" and int(current_scene.data["num"]) == 2, "Next street loads street 2")
	game.bot_input = null
	game.god_mode = false
	_check(game.is_completed(0) and game.is_unlocked(1), "street 1 completed, street 2 unlocked")
	_check(FileAccess.file_exists("user://smoke_save.json"), "progress written to disk")
	print("SMOKE RESULT: %s" % ("PASS" if _fail == 0 else "%d FAILED" % _fail))
	quit(1 if _fail > 0 else 0)


## Second process: the save written by the first run must load back.
func _verify_restart() -> void:
	root.get_node("SaveManager").path = "user://smoke_save.json"
	root.get_node("Settings").path = "user://smoke_settings.cfg"
	var game: Node = root.get_node("Game")
	game.load_game()
	_check(game.has_progress(), "after restart: progress loaded from disk")
	_check(game.is_completed(0), "after restart: street 1 still completed")
	_check(game.is_unlocked(1), "after restart: street 2 still unlocked")
	_check(game.best_score(0) > 0, "after restart: best score kept (%d)" % game.best_score(0))
	_check(game.continue_level() == 1, "after restart: Continue points at street 2")
	for f in ["user://smoke_save.json", "user://smoke_save.json.tmp", "user://smoke_settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("SMOKE RESTART RESULT: %s" % ("PASS" if _fail == 0 else "%d FAILED" % _fail))
	quit(1 if _fail > 0 else 0)
