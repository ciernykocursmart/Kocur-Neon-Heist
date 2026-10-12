extends SceneTree
## Save persistence across a real application restart (two separate processes):
##   godot --headless --path . -s res://tests/restart_check.gd -- write
##   godot --headless --path . -s res://tests/restart_check.gd -- verify
## "write" plays m01 with the AI through the campaign API, buys an upgrade,
## changes settings and exits. "verify" is a fresh process that must load all
## of it back from disk exactly. Uses its own files, never the real save.

const SAVE := "user://restart_save.json"
const CFG := "user://restart_settings.cfg"
const EXPECT := "user://restart_expect.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "write"
	var sm: Node = root.get_node("SaveManager")
	var st: Node = root.get_node("Settings")
	var camp: Node = root.get_node("Campaign")
	sm.path = SAVE
	st.path = CFG
	var fail := 0
	if mode == "write":
		for f in [SAVE, CFG, EXPECT]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		camp.new_campaign("hard")
		var Battle: GDScript = load("res://scripts/core/battle.gd")
		var AI: GDScript = load("res://scripts/core/ai.gd")
		var b: RefCounted = Battle.new()
		b.setup(camp.battle_mission("m01"), camp.squad_entries("m01", camp.default_squad("m01")), "normal")
		var ai: RefCounted = AI.new()
		var g := 0
		while b.result == "" and g < 30:
			g += 1
			ai.play_hero_phase(b)
		var rw: Dictionary = camp.record_result("m01", b.summary())
		camp.buy("nox", "vitality")
		st.set_volume("music", 0.35)
		st.set_speed(1)
		st.save_settings()
		var expect := {"shards": camp.data["shards"], "nox_xp": camp.hero_xp("nox"), "medal": camp.mission_record("m01")["medal"],
			"vitality": camp.upgrade_rank("nox", "vitality"), "result": b.result, "first_clear": rw["first_clear"]}
		var f := FileAccess.open(EXPECT, FileAccess.WRITE)
		f.store_string(JSON.stringify(expect))
		f.close()
		print("RESTART WRITE: ", JSON.stringify(expect))
		if b.result != "victory":
			fail += 1
			print("FAIL  m01 was not won")
	else:
		camp.load_game()
		st.load_settings()
		var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
		var checks := [
			[camp.has_progress(), "campaign started"],
			[camp.difficulty() == "hard", "difficulty hard"],
			[camp.is_completed("m01"), "m01 completed"],
			[camp.is_unlocked("m02"), "m02 unlocked"],
			[int(camp.data["shards"]) == int(expect["shards"]), "shards %d" % int(expect["shards"])],
			[camp.hero_xp("nox") == int(expect["nox_xp"]), "Nox XP %d" % int(expect["nox_xp"])],
			[int(camp.mission_record("m01")["medal"]) == int(expect["medal"]), "medal"],
			[camp.upgrade_rank("nox", "vitality") == int(expect["vitality"]) and int(expect["vitality"]) == 1, "upgrade"],
			[absf(st.music_volume - 0.35) < 0.001, "music volume"],
			[st.speed_index == 1, "animation speed"],
		]
		for c: Array in checks:
			print(("ok    " if c[0] else "FAIL  ") + "after restart: " + c[1])
			if not c[0]:
				fail += 1
		# replaying after the restart must not pay the first-clear reward again
		var shards: int = int(camp.data["shards"])
		var rw: Dictionary = camp.record_result("m01", {"result": "victory", "turns": 9, "deployed": ["nox"], "kills": {}, "optional": [false, false]})
		var ok: bool = not rw["first_clear"] and int(camp.data["shards"]) == shards
		print(("ok    " if ok else "FAIL  ") + "after restart: replay gives no duplicate reward")
		if not ok:
			fail += 1
		for f in [SAVE, CFG, EXPECT]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("RESTART %s: %s" % [mode.to_upper(), "PASS" if fail == 0 else "%d FAILED" % fail])
	quit(1 if fail > 0 else 0)
