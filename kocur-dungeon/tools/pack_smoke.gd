extends SceneTree
## Smoke test for an exported build: loads the game's pack (embedded in the
## Windows .exe) with the Linux editor binary and exercises it headless:
##   godot --headless --main-pack build/windows/KocurDungeon.exe -s $PWD/tools/pack_smoke.gd
## It cannot prove the .exe itself starts on Windows - only that the exported
## content (scenes, scripts, imported art/audio) is complete and runs.

var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	print(("ok    " if cond else "FAIL  ") + msg)
	if not cond:
		_fail += 1


func _run() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "Kocur Dungeon", "pack is Kocur Dungeon")
	_check(not ResourceLoader.exists("res://tests/run_tests.gd"), "tests are not shipped")
	for n in ["Settings", "SaveManager", "Progress", "Audio", "Transition"]:
		_check(root.has_node(n), "autoload " + n)
	root.get_node("SaveManager").path = "user://smoke_save.json"
	root.get_node("Settings").path = "user://smoke_settings.cfg"
	var catalog: GDScript = load("res://scripts/data/level_catalog.gd")
	_check(catalog != null, "level catalog loads")
	for scene in ["res://scenes/main_menu.tscn", "res://scenes/camp.tscn", "res://scenes/ending.tscn"]:
		change_scene_to_file(scene)
		for i in 20:
			await process_frame
		_check(current_scene != null and current_scene.scene_file_path == scene, "runs " + scene)
	for lv: Dictionary in catalog.LEVELS:
		root.get_node("Transition").next_level_id = lv["id"]
		change_scene_to_file("res://scenes/level.tscn")
		for i in 30:
			await physics_frame
		var ok: bool = current_scene != null and current_scene.get("level_id") == lv["id"] and current_scene.player != null
		_check(ok, "level %s builds and runs" % lv["id"])
	for f in ["user://smoke_save.json", "user://smoke_settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("SMOKE RESULT: %s" % ("PASS" if _fail == 0 else "%d FAILED" % _fail))
	quit(1 if _fail > 0 else 0)
