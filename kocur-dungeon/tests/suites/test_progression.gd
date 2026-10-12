extends "res://tests/test_case.gd"
## Currency, upgrades, unlocks, rewards (no duplicates), saving and loading.

const GameData := preload("res://scripts/data/game_data.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")


func _result(extra := {}) -> Dictionary:
	var r := {"coins": {"c1": 1.0, "c2": 1.0, "c3": 1.0}, "items": [], "secrets": [], "gems": [], "cats": [],
		"relic": "", "deaths": 1, "heals": 1, "time": 60.0, "boss": false, "secrets_total": 1, "gems_total": 1}
	r.merge(extra, true)
	return r


func test_new_game_defaults() -> void:
	Progress.new_game()
	eq(Progress.coins(), 0, "new game starts with no coins")
	check(Progress.has_progress(), "new game marks the save as started")
	check(Progress.is_unlocked("1-1"), "1-1 unlocked")
	check(not Progress.is_unlocked("1-2"), "1-2 locked at start")
	eq(Progress.next_level_id(), "1-1", "continue starts at 1-1")
	eq(Progress.max_hp(), 10, "5 hearts (10 halves) at start")
	check(SaveManager.has_save(), "new game writes a save file")


func test_commit_awards_and_unlocks() -> void:
	Progress.new_game()
	var s := Progress.commit_level("1-1", _result())
	eq(s["coins"], 3 + 20, "3 coins + first clear bonus 20")
	eq(s["unlocked"], "1-2", "clearing 1-1 unlocks 1-2")
	check(Progress.is_completed("1-1"), "1-1 completed")
	check(Progress.is_unlocked("1-2"), "1-2 unlocked")
	eq(Progress.next_level_id(), "1-2", "continue moves on")
	eq(Progress.data["stats"]["levels_done"], 1, "levels_done stat")


func test_rewards_never_duplicate() -> void:
	Progress.new_game()
	var r := _result({"secrets": ["secret:1,1"], "gems": ["gem:5,5"], "cats": ["pip"], "deaths": 0})
	var first := Progress.commit_level("1-2", r)
	var coins_after_first := Progress.coins()
	var second := Progress.commit_level("1-2", r)
	eq(second["coins"], 0, "replaying with the same items earns nothing extra")
	eq(Progress.coins(), coins_after_first, "coin total unchanged on duplicate commit")
	eq(second["new_secrets"], 0, "secret not counted twice")
	eq(second["new_gems"], 0, "gem not counted twice")
	eq((second["new_cats"] as Array).size(), 0, "cat not rescued twice")
	eq(Progress.data["rescued"].count("pip"), 1, "cat stored once")
	eq(Progress.total_gems(), 1, "one gem in total")
	check((first["challenges"] as Array).has("deathless"), "deathless challenge awarded")
	check(not (second["challenges"] as Array).has("deathless"), "challenge reward paid once")
	var third := Progress.commit_level("1-2", _result({"coins": {"c1": 1.0, "new": 1.0}}))
	eq(third["coins"], 1, "only the coin not banked before pays out")


func test_challenges() -> void:
	Progress.new_game()
	var s := Progress.commit_level("1-3", _result({"boss": true, "heals": 0, "deaths": 0, "secrets": ["a"],
		"secrets_total": 1, "gems": ["g"], "gems_total": 1, "coins": {}}))
	for ch in ["secrets", "gems", "deathless", "no_heal"]:
		check((s["challenges"] as Array).has(ch), "challenge earned: " + ch)
	eq(s["coins"], 20 + 50 + 4 * GameData.CHALLENGE_REWARD, "first clear + guardian + 4 challenges")
	eq(Progress.data["stats"]["bosses"], 1, "boss stat counted")


func test_upgrades_change_gameplay_values() -> void:
	Progress.new_game()
	Progress.data["coins"] = 5000
	var hp0 := Progress.max_hp()
	var claw0 := Progress.claw_damage()
	var cd0 := Progress.pounce_cooldown()
	var heal0 := Progress.heal_amount()
	check(Progress.buy("heart"), "buy heart")
	eq(Progress.max_hp(), hp0 + 2, "heart upgrade adds a heart")
	check(Progress.buy("claws"), "buy claws")
	eq(Progress.claw_damage(), claw0 + 1, "claw upgrade adds damage")
	check(Progress.buy("pounce"), "buy pounce")
	lt(Progress.pounce_cooldown(), cd0, "pounce cooldown shorter")
	check(Progress.buy("remedy"), "buy remedy")
	eq(Progress.heal_amount(), heal0 + 1, "fish heal more")
	check(not Progress.buy("heavy"), "heavy pounce needs 3 gems")
	Progress.data["levels"]["1-1"] = Progress.new_record()
	Progress.data["levels"]["1-1"]["gems"] = ["a", "b", "c"]
	var pd := Progress.pounce_damage()
	check(Progress.buy("heavy"), "heavy pounce buyable with gems")
	eq(Progress.pounce_damage(), pd + 2, "heavy pounce adds 2 damage")
	eq(Progress.total_gems(), 3, "gems are not spent")
	check(not Progress.buy("heavy"), "cannot exceed max level")
	eq(Progress.upgrade_cost("heavy"), -1, "maxed upgrade has no price")


func test_cannot_buy_without_coins() -> void:
	Progress.new_game()
	Progress.data["coins"] = 10
	check(not Progress.can_buy("heart"), "too expensive")
	check(not Progress.buy("heart"), "buy refused")
	eq(Progress.coins(), 10, "coins untouched")
	eq(Progress.upgrade_level("heart"), 0, "level untouched")


func test_rescued_cats_have_effects() -> void:
	Progress.new_game()
	var hp := Progress.max_hp()
	var price := Progress.upgrade_cost("heart")
	var mult := Progress.coin_multiplier()
	var hz := Progress.hazard_damage()
	var cd := Progress.pounce_cooldown()
	var sh := Progress.start_shields()
	Progress.data["rescued"] = ["pip", "bramble", "soot", "cinder", "nibbles", "old_tom", "moonpaw"]
	eq(Progress.max_hp(), hp + 4, "Pip and Moonpaw add a heart each")
	lt(Progress.upgrade_cost("heart"), price, "Bramble discount")
	gt(Progress.coin_multiplier(), mult, "Soot coin bonus")
	lt(Progress.hazard_damage(), hz, "Cinder halves hazard damage")
	lt(Progress.pounce_cooldown(), cd, "Nibbles shortens pounce cooldown")
	eq(Progress.start_shields(), sh + 1, "Old Tom adds a shield")


func test_blessings_are_temporary() -> void:
	Progress.new_game()
	var offers := Progress.offer_blessings(3)
	eq(offers.size(), 3, "three blessings offered")
	var claw := Progress.claw_damage()
	Progress.add_blessing("sharp")
	eq(Progress.claw_damage(), claw + 1, "blessing applies")
	Progress.save_game()
	var saved := SaveManager.read()
	check(not JSON.stringify(saved).contains("sharp"), "blessings are not written to the save")
	Progress.clear_run()
	eq(Progress.claw_damage(), claw, "blessing gone after returning to camp")


func test_save_and_load_roundtrip() -> void:
	Progress.new_game()
	Progress.data["coins"] = 321
	Progress.data["upgrades"]["claws"] = 1
	Progress.commit_level("1-1", _result({"gems": ["gem:1,1"], "cats": ["pip"]}))
	Progress.data["relics"].append("mouser")
	Progress.save_game()
	var coins := Progress.coins()
	Progress.data = Progress.defaults()
	eq(Progress.coins(), 0, "memory cleared")
	Progress.load_game()
	eq(Progress.coins(), coins, "coins restored")
	eq(Progress.upgrade_level("claws"), 1, "upgrade restored")
	check(Progress.is_completed("1-1"), "level completion restored")
	check(Progress.has_cat("pip"), "rescued cat restored")
	eq(Progress.total_gems(), 1, "gems restored")
	check(Progress.data["relics"].has("mouser"), "relic restored")
	eq(int(SaveManager.read().get("version", 0)), SaveManager.SAVE_VERSION, "save carries its version")


func test_missing_and_malformed_saves() -> void:
	SaveManager.delete_save()
	Progress.load_game()
	check(not Progress.has_progress(), "no save -> fresh defaults")
	var f := FileAccess.open(SaveManager.path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Progress.load_game()
	check(not Progress.has_progress(), "malformed save -> defaults, no crash")
	check(FileAccess.file_exists("user://" + SaveManager.path.get_file().get_basename() + "_corrupt.json"),
		"malformed save kept aside for inspection")
	f = FileAccess.open(SaveManager.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "started": true, "coins": "lots", "unlocked": 999,
		"levels": {"1-1": {"completed": true, "gems": "nope"}, "bogus": 3}, "upgrades": {"heart": 99, "fake": 1},
		"rescued": ["pip", "not_a_cat", 7], "stats": {"deaths": "x"}}))
	f.close()
	Progress.load_game()
	check(Progress.has_progress(), "partially valid save loads")
	eq(Progress.coins(), 0, "garbage coin value sanitised")
	eq(int(Progress.data["unlocked"]), LevelCatalog.count() - 1, "unlock index clamped")
	eq(Progress.upgrade_level("heart"), Progress.upgrade_max("heart"), "upgrade level clamped")
	check(not Progress.data["upgrades"].has("fake"), "unknown upgrade dropped")
	eq(Progress.data["rescued"], ["pip"], "unknown cats dropped")
	check(not Progress.data["levels"].has("bogus"), "unknown level dropped")
	eq(Progress.record("1-1")["gems"], [], "bad gem list replaced")


func test_reset_progress() -> void:
	Progress.new_game()
	Progress.data["coins"] = 99
	Progress.save_game()
	Progress.reset_progress()
	eq(Progress.coins(), 0, "coins reset")
	check(not SaveManager.has_save(), "save file removed")
	check(not Progress.has_progress(), "no progress after reset")


func test_new_game_overwrites_old_progress() -> void:
	Progress.new_game()
	Progress.commit_level("1-1", _result({"cats": ["pip"]}))
	Progress.new_game()
	check(not Progress.is_completed("1-1"), "old completion gone")
	check(not Progress.has_cat("pip"), "old cats gone")
	eq(Progress.coins(), 0, "old coins gone")


func test_difficulty_scales_damage() -> void:
	Settings.difficulty = "easy"
	eq(Settings.incoming_damage(2), 1, "easy halves damage")
	eq(Settings.incoming_damage(1), 1, "easy never below half a heart")
	Settings.difficulty = "normal"
	eq(Settings.incoming_damage(2), 2, "normal damage")
	Settings.difficulty = "hard"
	eq(Settings.incoming_damage(2), 3, "hard +50%")


func test_completion_percent() -> void:
	Progress.new_game()
	eq(Progress.completion_percent(), 0, "0% at start")
	for lv: Dictionary in LevelCatalog.LEVELS:
		var t := LevelCatalog.totals(lv["id"])
		var gems: Array = []
		for i in int(t["gems"]):
			gems.append("g%d" % i)
		var secrets: Array = []
		for i in int(t["secrets"]):
			secrets.append("s%d" % i)
		Progress.commit_level(lv["id"], _result({"gems": gems, "secrets": secrets,
			"cats": [lv["cat"]] if lv["cat"] != "" else []}))
	eq(Progress.completion_percent(), 100, "100% when everything is found")
	check(Progress.data["game_complete"], "game marked complete after the final level")
