extends "res://tests/test_case.gd"
## Campaign progression, rewards, upgrades and save/settings persistence.

var camp: Node
var sm: Node
var st: Node


func before_each() -> void:
	camp = tree.root.get_node("Campaign")
	sm = tree.root.get_node("SaveManager")
	st = tree.root.get_node("Settings")
	camp.new_campaign("normal")


func _win(id: String, opt: Array, kills := {"nox": 2}, deployed := ["nox", "bramble", "willow"]) -> Dictionary:
	return camp.record_result(id, {"result": "victory", "turns": 6, "deployed": deployed, "kills": kills, "optional": opt})


func test_unlock_chain() -> void:
	check(camp.is_unlocked("m01"), "m01 unlocked at start")
	check(not camp.is_unlocked("m02"), "m02 locked at start")
	check(not camp.is_unlocked("c1"), "challenge locked at start")
	eq(camp.next_mission(), "m01", "next mission m01")
	camp.record_result("m01", {"result": "defeat", "turns": 3, "deployed": ["nox"], "kills": {}, "optional": []})
	check(not camp.is_unlocked("m02"), "a defeat does not unlock")
	eq(int(camp.data["battles_lost"]), 1, "defeat recorded")
	_win("m01", [false, false])
	check(camp.is_unlocked("m02"), "victory unlocks the next mission")
	eq(camp.next_mission(), "m02", "next mission m02")
	for id in ["m02", "m03", "m04"]:
		_win(id, [false, false])
	check(camp.is_unlocked("c1"), "c1 unlocks after m04")


func test_xp_and_levels() -> void:
	var r := _win("m01", [false, false], {"nox": 5, "bramble": 0}, ["nox", "bramble"])
	eq(r["xp"]["nox"], 40 + 30, "deployed XP: 40 + kills (capped at 30)")
	eq(r["xp"]["bramble"], 40, "deployed with no kills: 40")
	eq(r["xp"]["willow"], 20, "reserve heroes get 20")
	eq(camp.hero_xp("nox"), 70, "XP stored")
	eq(camp.hero_level("nox"), 1, "still level 1 at 70 XP")
	_win("m02", [false, false], {"nox": 3})
	eq(camp.hero_level("nox"), 2, "level 2 after 100 XP")
	var s1: Dictionary = UD.hero_stats("nox", 1, {})
	var s2: Dictionary = camp.hero_stats("nox")
	eq(int(s2["hp"]), int(s1["hp"]) + 2, "+2 HP per level")


func test_no_duplicate_rewards() -> void:
	var r1 := _win("m01", [true, false])
	check(r1["first_clear"], "first clear")
	var shards1: int = int(camp.data["shards"])
	eq(shards1, 3 + 1, "first clear: mission shards + optional shard")
	var xp1: int = camp.hero_xp("nox")
	var r2 := _win("m01", [true, false])
	check(not r2["first_clear"], "replay is not a first clear")
	eq(camp.hero_xp("nox"), xp1, "replay gives no XP")
	eq(int(camp.data["shards"]), shards1, "replay of the same optional gives no shards")
	var r3 := _win("m01", [true, true])
	eq(r3["new_optional"], [1], "a newly achieved optional is reported")
	eq(int(camp.data["shards"]), shards1 + 1, "only the new optional pays out")
	eq(r3["medal"], 3, "all optionals -> gold medal (3)")
	_win("m01", [false, false])
	eq(int(camp.mission_record("m01")["medal"]), 3, "medal never goes down")
	eq(int(camp.mission_record("m01")["plays"]), 4, "plays counted")


func test_recruits() -> void:
	check(not camp.is_recruited("moss"), "Moss not recruited at start")
	check(not camp.available_heroes("m03").has("moss"), "Moss cannot be deployed in her own rescue")
	for id in ["m01", "m02"]:
		_win(id, [false, false])
	var r := _win("m03", [false, false])
	eq(r["recruits"], ["moss"], "Moss joins after m03")
	check(camp.is_recruited("moss"), "Moss recruited")
	eq(camp.hero_xp("moss"), 0, "Moss had no XP before joining")
	var r2 := _win("m03", [false, false])
	eq(r2["recruits"], [], "no duplicate recruit on replay")
	eq((camp.data["recruited"] as Array).count("moss"), 1, "Moss listed once")


func test_upgrades() -> void:
	eq(camp.upgrade_cost("nox", "vitality"), 2, "first vitality rank costs 2")
	check(not camp.buy("nox", "vitality"), "cannot buy without shards")
	camp.data["shards"] = 20
	var hp0: int = int(camp.hero_stats("nox")["hp"])
	check(camp.buy("nox", "vitality"), "buy vitality")
	eq(int(camp.data["shards"]), 18, "shards spent")
	eq(int(camp.hero_stats("nox")["hp"]), hp0 + 3, "+3 HP")
	eq(camp.upgrade_cost("nox", "vitality"), 3, "next rank costs more")
	check(camp.buy("nox", "vitality") and camp.buy("nox", "vitality"), "ranks 2 and 3")
	eq(camp.upgrade_cost("nox", "vitality"), -1, "maxed out")
	check(not camp.buy("nox", "vitality"), "cannot exceed max rank")
	check(not camp.buy("moss", "power"), "cannot upgrade a hero not yet recruited")
	camp.data["shards"] = 20
	check(camp.buy("nox", "special"), "buy the special mastery")
	var b := make_battle(["1....", ".....", "....r"], [["nox", 1, camp.hero_upgrades("nox")]])
	var nox = unit_named(b, "shadowblade")
	check(nox.special, "mastery carried into battle")
	eq(b.range_max(nox, UD.ability("pounce"), nox.pos), 4, "Pounce mastery: +1 range")
	var entries: Array = camp.squad_entries("m02", ["nox"])
	eq(entries[0]["upgrades"]["vitality"], 3, "squad entries carry upgrades")


func test_challenge_squads_fixed() -> void:
	var e: Array = camp.squad_entries("c1", ["nox"])
	eq(e.size(), 2, "challenge c1 uses its fixed 2-hero squad")
	eq(e[0]["hero_id"], "bramble", "fixed squad member")
	camp.record_result("c1", {"result": "victory", "turns": 7, "deployed": [], "kills": {}, "optional": []})
	check(camp.is_completed("c1"), "challenge completion recorded")
	eq(int(camp.data["challenges"]["c1"]["best_turns"]), 7, "best turns recorded")
	camp.record_result("c1", {"result": "victory", "turns": 5, "deployed": [], "kills": {}, "optional": []})
	eq(int(camp.data["challenges"]["c1"]["best_turns"]), 5, "best turns improves")
	eq(int(camp.data["shards"]), 0, "challenges give no shards (no farming)")


func test_campaign_complete() -> void:
	for id in Missions.mission_ids():
		_win(id, [false, false])
	check(camp.data["campaign_complete"], "campaign complete after m12")
	eq(camp.completed_count(), 12, "12 completed")
	check(camp.is_unlocked("c3"), "c3 unlocked after m12")


func test_save_roundtrip() -> void:
	_win("m01", [true, true])
	camp.data["shards"] = 9
	camp.buy("nox", "power")
	var snapshot: Dictionary = camp.data.duplicate(true)
	check(sm.has_save(), "save file written")
	camp.data = {}
	camp.load_game()
	eq(camp.data["shards"], snapshot["shards"], "shards restored")
	eq(camp.hero_xp("nox"), int(snapshot["roster"]["nox"]["xp"]), "XP restored")
	eq(camp.upgrade_rank("nox", "power"), 1, "upgrade restored")
	check(camp.is_completed("m01"), "completion restored")
	eq(int(camp.mission_record("m01")["medal"]), 3, "medal restored")
	var raw: Dictionary = sm.read()
	eq(int(raw["version"]), 1, "save is versioned")


func _write_raw(text: String) -> void:
	var f := FileAccess.open(sm.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_malformed_saves() -> void:
	_write_raw("{ this is not json")
	camp.load_game()
	eq(sm.last_error, "malformed save", "malformed save detected")
	check(not camp.has_progress(), "falls back to a fresh campaign")
	check(FileAccess.file_exists("user://test_save_corrupt.json"), "corrupt save moved aside, not deleted")
	_write_raw("[1, 2, 3]")
	camp.load_game()
	eq(camp.data["shards"], 0, "wrong top-level type -> defaults")
	_write_raw(JSON.stringify({"started": true, "shards": -50, "difficulty": "nightmare",
		"missions": {"m01": {"completed": true, "medal": 99, "optional": "yes"}, "zzz": 5},
		"roster": {"nox": {"xp": "lots", "upgrades": {"vitality": 77, "bogus": 3}}, "ghost": {}},
		"recruited": ["nox", "ghost", 42, "moss", "moss"]}))
	camp.load_game()
	check(camp.has_progress(), "valid fields kept")
	eq(camp.data["shards"], 0, "negative shards clamped")
	eq(camp.difficulty(), "normal", "unknown difficulty -> normal")
	eq(int(camp.mission_record("m01")["medal"]), 3, "medal clamped to 3")
	eq(camp.mission_record("m01")["optional"], [false, false], "bad optional list repaired")
	check(not camp.data["missions"].has("zzz"), "unknown mission dropped")
	eq(camp.upgrade_rank("nox", "vitality"), 3, "upgrade rank clamped to max")
	check(not camp.hero_upgrades("nox").has("bogus"), "unknown upgrade dropped")
	check(not camp.data["roster"].has("ghost"), "unknown hero dropped")
	eq((camp.data["recruited"] as Array).count("moss"), 1, "duplicate recruits removed")
	check(not (camp.data["recruited"] as Array).has("ghost"), "unknown recruit dropped")
	_write_raw(JSON.stringify({"version": 99, "started": true, "shards": 4}))
	camp.load_game()
	eq(sm.last_error, "save from newer version", "newer save version detected")
	eq(camp.data["shards"], 4, "newer save still loads known fields")
	_write_raw("")
	camp.load_game()
	check(not camp.has_progress(), "empty file -> fresh campaign")


func test_new_and_reset() -> void:
	_win("m01", [true, true])
	camp.new_campaign("hard")
	check(not camp.is_completed("m01"), "new campaign clears progress")
	eq(camp.difficulty(), "hard", "difficulty chosen")
	check(camp.has_progress(), "new campaign is started")
	_win("m01", [true, true])
	camp.reset_progress()
	check(not sm.has_save(), "reset deletes the save")
	check(not camp.has_progress(), "reset clears progress")
	camp.load_game()
	check(not camp.is_completed("m01"), "nothing comes back after reset")


func test_difficulty_change_persists() -> void:
	camp.set_difficulty("story")
	camp.data = {}
	camp.load_game()
	eq(camp.difficulty(), "story", "difficulty persisted")
	camp.set_difficulty("impossible")
	eq(camp.difficulty(), "story", "invalid difficulty ignored")


func test_settings_persist() -> void:
	st.set_volume("music", 0.25)
	st.set_volume("sfx", 0.4)
	st.set_speed(2)
	st.set_resolution(2)
	st.save_settings()
	st.reset_defaults()
	eq(st.music_volume, 0.6, "defaults restored in memory")
	st.load_settings()
	eq(st.music_volume, 0.25, "music volume persisted")
	eq(st.sfx_volume, 0.4, "sfx volume persisted")
	eq(st.speed_index, 2, "speed persisted")
	eq(st.resolution_index, 2, "resolution persisted")
	var f := FileAccess.open(st.path, FileAccess.WRITE)
	f.store_string("[audio]\nmusic=\"loud\"\nsfx=7.5\n[video]\nresolution=99\n")
	f.close()
	st.load_settings()
	check(st.music_volume >= 0.0 and st.music_volume <= 1.0, "bad music value sanitized")
	check(st.sfx_volume <= 1.0, "volume clamped")
	check(st.resolution_index >= 0 and st.resolution_index < st.RESOLUTIONS.size(), "resolution index clamped")
	check(InputMap.has_action("end_turn") and InputMap.has_action("threat"), "input actions registered")
	check(st.key_name("end_turn") != "", "key names available for the controls screen")
