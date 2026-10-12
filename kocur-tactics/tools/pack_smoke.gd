extends SceneTree
## Smoke test for an exported build: loads the game's pack (embedded in the
## Windows .exe) with the Linux editor binary and exercises it headless:
##   godot --headless --main-pack build/windows/KocurTactics.exe -s $PWD/tools/pack_smoke.gd
## It cannot prove the .exe itself starts on Windows - only that the exported
## content (scenes, scripts, imported art/audio, missions) is complete and runs.

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


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "verify":
		await _verify_restart()
		return
	_check(ProjectSettings.get_setting("application/config/name") == "Kocur Tactics", "pack is Kocur Tactics")
	_check(not ResourceLoader.exists("res://tests/run_tests.gd"), "tests are not shipped")
	_check(not FileAccess.file_exists("res://tools/gen_art.py"), "tools are not shipped")
	for n in ["Settings", "SaveManager", "Campaign", "Audio", "Transition"]:
		_check(root.has_node(n), "autoload " + n)
	root.get_node("SaveManager").path = "user://smoke_save.json"
	root.get_node("Settings").path = "user://smoke_settings.cfg"
	var camp: Node = root.get_node("Campaign")
	camp.data = camp.defaults()
	camp.data["started"] = true
	var audio: Node = root.get_node("Audio")
	for s in audio.SFX_NAMES:
		_check(ResourceLoader.exists("res://assets/audio/%s.wav" % s), "sound " + s)
	for scene in ["res://scenes/main_menu.tscn", "res://scenes/campaign.tscn", "res://scenes/ending.tscn"]:
		change_scene_to_file(scene)
		await _frames(20)
		_check(current_scene != null and current_scene.scene_file_path == scene, "runs " + scene)
	var Missions: GDScript = load("res://scripts/data/missions.gd")
	var ids: Array = Missions.mission_ids()
	ids.append_array(Missions.challenge_ids())
	for id: String in ids:
		root.get_node("Transition").battle_request = {"mission_id": id, "squad": camp.default_squad(id)}
		change_scene_to_file("res://scenes/battle.tscn")
		await _frames(15)
		var sc: Node = current_scene
		var ok: bool = sc != null and sc.get("mission_id") == id and sc.b != null and sc.b.side_units("enemy").size() > 0
		_check(ok, "battle %s builds" % id)
		if ok:
			for c in sc.modal_layer.get_children():
				c.queue_free()
			sc.instant = true
			await sc.auto_player_turn()
			_check(sc.b.turn >= 2 or sc.b.result != "", "battle %s plays a turn" % id)
	# a complete encounter through the real battle scene: m01 from a fresh campaign
	camp.new_campaign("normal")
	root.get_node("Transition").battle_request = {"mission_id": "m01", "squad": camp.default_squad("m01")}
	change_scene_to_file("res://scenes/battle.tscn")
	await _frames(15)
	var bs: Node = current_scene
	for c in bs.modal_layer.get_children():
		c.queue_free()
	bs.instant = true
	var g := 0
	while bs.b.result == "" and g < 30:
		g += 1
		await bs.auto_player_turn()
	await _frames(10)
	_check(bs.b.result == "victory", "m01 won through the battle scene (%s, %d turns)" % [bs.b.result, bs.b.turn])
	var result_screen: Node = bs.modal_layer.find_child("Result", true, false)
	_check(result_screen != null, "victory screen shown")
	var cont: Button = bs.modal_layer.find_child("Continue", true, false) as Button
	_check(cont != null, "Continue button on the result screen")
	if cont:
		cont.pressed.emit()
		for i in 120:
			await process_frame
			if not root.get_node("Transition").busy:
				break
		await _frames(5)
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/campaign.tscn", "Continue returns to the campaign")
	_check(camp.is_completed("m01") and camp.is_unlocked("m02"), "m01 completed, m02 unlocked")
	_check(FileAccess.file_exists("user://smoke_save.json"), "progress written to disk")
	print("SMOKE RESULT: %s" % ("PASS" if _fail == 0 else "%d FAILED" % _fail))
	quit(1 if _fail > 0 else 0)


## Second process: the save written by the first run must load back.
func _verify_restart() -> void:
	root.get_node("SaveManager").path = "user://smoke_save.json"
	root.get_node("Settings").path = "user://smoke_settings.cfg"
	var camp: Node = root.get_node("Campaign")
	camp.load_game()
	_check(camp.has_progress(), "after restart: campaign loaded from disk")
	_check(camp.is_completed("m01"), "after restart: m01 still completed")
	_check(camp.is_unlocked("m02"), "after restart: m02 still unlocked")
	_check(int(camp.data["shards"]) >= 3, "after restart: shards kept (%d)" % int(camp.data["shards"]))
	for f in ["user://smoke_save.json", "user://smoke_settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("SMOKE RESTART RESULT: %s" % ("PASS" if _fail == 0 else "%d FAILED" % _fail))
	quit(1 if _fail > 0 else 0)
