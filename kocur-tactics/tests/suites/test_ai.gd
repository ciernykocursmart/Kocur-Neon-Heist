extends "res://tests/test_case.gd"
## Enemy utility AI: legal moves, sensible targets, archetype behaviour.

const AI = preload("res://scripts/core/ai.gd")


func _enemy_turn(b: RefCounted, u: RefCounted) -> Dictionary:
	var ai := AI.new()
	return ai.plan_turn(b, u)


func test_plans_are_legal() -> void:
	for id in ["m02", "m05", "m08", "m11"]:
		var m := Missions.get_mission(id)
		var b := Battle.new()
		b.setup(m, [{"hero_id": "nox", "level": 3, "upgrades": {}}, {"hero_id": "bramble", "level": 3, "upgrades": {}},
			{"hero_id": "willow", "level": 3, "upgrades": {}}, {"hero_id": "moss", "level": 3, "upgrades": {}}], "normal")
		for e in b.side_units("enemy"):
			e.awake = true
			var plan := _enemy_turn(b, e)
			var dest: Vector2i = plan["move"]
			check(dest == e.pos or b.reachable_cells(e).has(dest), "%s %s plans a reachable destination" % [id, e.name])
			var act: Dictionary = plan["action"]
			if act.get("type", "") == "ability":
				check(b.ability_targets(e, act["id"], dest, 1 if dest != e.pos else 0).has(act["cell"]),
					"%s %s plans a valid target" % [id, e.name])


func test_melee_attacks_reachable_hero() -> void:
	var b := make_battle(["1...", "...r", "...."], [["willow", 1]])
	var r = unit_named(b, "recruit")
	var plan := _enemy_turn(b, r)
	eq(plan["action"].get("id", ""), "jab", "recruit attacks a hero it can reach")
	eq(Vector2i(plan["action"]["cell"]), Vector2i(0, 0), "targets the hero")


func test_prefers_kill() -> void:
	var b := make_battle(["1.r.2", "....."], [["bramble", 1], ["willow", 1]])
	var r = unit_named(b, "recruit")
	var w = unit_named(b, "ranger")
	w.hp = 4
	var plan := _enemy_turn(b, r)
	eq(Vector2i(plan["action"].get("cell", Vector2i(-1, -1))), w.pos, "AI goes for the hero it can knock out")


func test_archer_keeps_distance() -> void:
	var b := make_battle(["1......", ".......", "...a...", "......."], [["nox", 1]])
	var a = unit_named(b, "archer")
	var nox = unit_named(b, "shadowblade")
	nox.pos = Vector2i(3, 1)
	var plan := _enemy_turn(b, a)
	var dest: Vector2i = plan["move"]
	check(abs(dest.x - nox.pos.x) + abs(dest.y - nox.pos.y) >= 2, "archer steps away from an adjacent hero")
	eq(plan["action"].get("id", ""), "arrow", "and shoots")


func test_mage_heals_or_chills() -> void:
	var b := make_battle(["1.......", "........", "....m.r.", "........"], [["nox", 1]])
	var mg = unit_named(b, "mage")
	var r = unit_named(b, "recruit")
	r.hp = 3
	var plan := _enemy_turn(b, mg)
	var id: String = plan["action"].get("id", "")
	check(id == "mend_ally" or id == "frost", "mage uses a spell (got %s)" % id)
	eq(id, "mend_ally", "mage heals a badly hurt ally")


func test_guard_protects() -> void:
	var b := make_battle(["1.........", "..........", "......ag..", ".........."], [["nox", 1]])
	var g = unit_named(b, "guard")
	var a = unit_named(b, "archer")
	var plan := _enemy_turn(b, g)
	var dest: Vector2i = plan["move"]
	check(abs(dest.x - a.pos.x) + abs(dest.y - a.pos.y) <= 3, "guard stays close to the archer it escorts")


func test_stalker_hunts_isolated() -> void:
	var b := make_battle([
		"1.2.........",
		"............",
		"............",
		".........3..",
		"............",
		"s...........",
	], [["bramble", 1], ["nox", 1], ["willow", 1]])
	var s = unit_named(b, "stalker")
	s.pos = Vector2i(11, 5)
	var w = unit_named(b, "ranger")
	var plan := _enemy_turn(b, s)
	var act: Dictionary = plan["action"]
	if act.get("type", "") == "ability":
		eq(Vector2i(act["cell"]), w.pos, "stalker strikes the isolated ranger")
	else:
		var dest: Vector2i = plan["move"]
		check(abs(dest.x - w.pos.x) + abs(dest.y - w.pos.y) < abs(11 - w.pos.x) + abs(5 - w.pos.y), "stalker closes in on the isolated ranger")


func test_dormant_enemies_idle() -> void:
	var b := make_battle(["1.........", "........r."], [["nox", 1]], {"type": "eliminate", "text": ""}, {"alert": 2})
	var r = unit_named(b, "recruit")
	var p0: Vector2i = r.pos
	b.cmd_end_phase()
	eq(r.pos, p0, "dormant recruit stays put")


func test_no_target_stays_reasonable() -> void:
	var b := make_battle(["1#....", "##....", ".....r"], [["nox", 1]])
	var r = unit_named(b, "recruit")
	var plan := _enemy_turn(b, r)
	check(plan["action"].is_empty(), "no target -> no attack")
	check(b.reachable_cells(r).has(plan["move"]) or plan["move"] == r.pos, "still a legal move")


func test_ai_does_not_freeze_on_full_mission() -> void:
	var m := Missions.get_mission("m09")
	var b := Battle.new()
	b.setup(m, [{"hero_id": "nox", "level": 4, "upgrades": {}}, {"hero_id": "bramble", "level": 4, "upgrades": {}},
		{"hero_id": "willow", "level": 4, "upgrades": {}}, {"hero_id": "moss", "level": 4, "upgrades": {}}], "normal")
	var t0 := Time.get_ticks_msec()
	var turns := 0
	while b.result == "" and turns < 3:
		b.cmd_end_phase()
		turns += 1
	var ms := Time.get_ticks_msec() - t0
	check(ms < 3000, "3 enemy phases on m09 finish quickly (%d ms)" % ms)
	note("m09 enemy phases: %d ms for %d turns" % [ms, turns])
