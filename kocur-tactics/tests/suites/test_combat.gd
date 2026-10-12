extends "res://tests/test_case.gd"
## Damage, defence, range, line of sight, abilities and knock-outs.
## Level-1 stats: Nox ATK7 DEF1, Bramble ATK6 DEF4, Willow ATK6 DEF0, Moss ATK4.
## Normal enemies: recruit HP10 ATK5 DEF0, guard HP16 DEF3, stalker ATK5 DEF1.


func test_basic_damage_and_cover() -> void:
	var b := make_battle(["1r..", "....", "T..."], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var r = unit_named(b, "recruit")
	eq(b.calc_damage(nox, r, "claw")["dmg"], 7, "Claw Strike = ATK 7 - DEF 0")
	check(b.cmd_ability(nox, "claw", r.pos), "attack accepted")
	eq(r.hp, 3, "recruit took exactly 7")
	var b2 := make_battle(["1T..", "....", "...."], [["nox", 1]], {"type": "eliminate", "text": ""})
	var n2 = unit_named(b2, "shadowblade")
	var r2 = b2.spawn_enemy("recruit", Vector2i(1, 0))
	eq(b2.calc_damage(n2, r2, "claw")["dmg"], 6, "forest cover gives +1 DEF")


func test_minimum_damage_and_stance() -> void:
	var b := make_battle(["1r..", "...."], [["bramble", 1]])
	var br = unit_named(b, "guardian")
	var r = unit_named(b, "recruit")
	eq(b.calc_damage(r, br, "jab")["dmg"], 1, "5 ATK vs 4 DEF = 1")
	br.status["stance"] = 1
	eq(b.calc_damage(r, br, "jab")["dmg"], 1, "damage never drops below 1")
	eq(int(b.defense_of(br)["def"]), 7, "stance adds +3 DEF")


func test_flanking() -> void:
	var b := make_battle(["1r2", "..."], [["nox", 1], ["bramble", 1]])
	var nox = unit_named(b, "shadowblade")
	var r = unit_named(b, "recruit")
	var d: Dictionary = b.calc_damage(nox, r, "claw")
	eq(d["dmg"], 9, "flanking adds +2 (7+2)")
	check(", ".join(d["parts"]).contains("flank"), "breakdown mentions flank")
	# enemies flank too
	var b2 := make_battle(["r1r", "..."], [["willow", 1]])
	var w = unit_named(b2, "ranger")
	var rr = unit_named(b2, "recruit")
	eq(b2.calc_damage(rr, w, "jab")["dmg"], 7, "enemy flanking: 5+2 vs DEF 0")


func test_ranged_rules() -> void:
	var b := make_battle([
		"1..r.",
		".....",
		"..#..",
		"..r..",
	], [["willow", 1]])
	var w = unit_named(b, "ranger")
	var far = b.unit_at(Vector2i(3, 0))
	var hidden = b.unit_at(Vector2i(2, 3))
	var t: Array[Vector2i] = b.ability_targets(w, "shot")
	check(t.has(far.pos), "enemy at range 3 in sight is a target")
	eq(b.calc_damage(w, far, "shot")["dmg"], 8, "Steady: unmoved ranger deals ATK+2")
	check(b.cmd_move(w, Vector2i(0, 1)), "move")
	eq(b.calc_damage(w, far, "shot")["dmg"], 6, "after moving: no Steady bonus")
	var b2 := make_battle(["1r...", "....."], [["willow", 1]])
	var w2 = unit_named(b2, "ranger")
	check(b2.ability_targets(w2, "shot").is_empty(), "ranger cannot shoot an adjacent enemy (min range 2)")
	var b3 := make_battle(["1.#.r", "....."], [["willow", 1]])
	var w3 = unit_named(b3, "ranger")
	check(not b3.ability_targets(w3, "shot").has(Vector2i(4, 0)), "wall blocks the shot")
	check(not b3.cmd_ability(w3, "shot", Vector2i(4, 0)), "shot through wall rejected")
	var b4 := make_battle(["1.~.r", "....."], [["willow", 1]])
	check(b4.ability_targets(unit_named(b4, "ranger"), "shot").has(Vector2i(4, 0)), "can shoot across water")
	# hill range bonus
	var b5 := make_battle(["^.....r", "1......"], [["willow", 1]])
	var w5 = unit_named(b5, "ranger")
	w5.pos = Vector2i(0, 0)
	check(b5.ability_targets(w5, "shot").has(Vector2i(6, 0)), "hill: range 6 reachable from high ground")
	w5.pos = Vector2i(0, 1)
	check(not b5.ability_targets(w5, "shot").has(Vector2i(6, 0)), "range 7 not reachable from flat ground")


func test_heavy_strike_requires_no_move() -> void:
	var b := make_battle(["1.r", "..."], [["bramble", 1]])
	var br = unit_named(b, "guardian")
	check(b.cmd_move(br, Vector2i(1, 0)), "move next to the enemy")
	check(b.ability_block_reason(br, "heavy") != "", "Heavy Strike blocked after moving")
	check(not b.cmd_ability(br, "heavy", Vector2i(2, 0)), "Heavy Strike command rejected after moving")
	check(b.cmd_ability(br, "strike", Vector2i(2, 0)), "plain Strike still allowed")
	var b2 := make_battle(["1r.", "..."], [["bramble", 1]])
	var br2 = unit_named(b2, "guardian")
	eq(b2.calc_damage(br2, unit_named(b2, "recruit"), "heavy")["dmg"], 10, "Heavy Strike = ATK+4")


func test_auras_shield_wall_and_guard() -> void:
	var b := make_battle(["1rg", "..."], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var r = unit_named(b, "recruit")
	eq(b.calc_damage(nox, r, "claw")["dmg"], 6, "Shield Wall: recruit next to a guard gets +1 DEF")
	var b2 := make_battle(["12r", "..."], [["bramble", 1], ["willow", 1]])
	var br = unit_named(b2, "guardian")
	var w = unit_named(b2, "ranger")
	var rr = unit_named(b2, "recruit")
	var before: int = b2.calc_damage(rr, w, "jab")["dmg"]
	check(b2.cmd_ability(br, "stance", br.pos), "stance accepted")
	eq(b2.calc_damage(rr, w, "jab")["dmg"], before - 2, "an ally next to a stanced Guardian gets +2 DEF")
	eq(int(br.cooldowns.get("stance", 0)), 2, "stance cooldown set (1 turn + this one)")


func test_isolated_bonus() -> void:
	var b := make_battle(["1s.", "...", "..2"], [["willow", 1], ["moss", 1]])
	var w = unit_named(b, "ranger")
	var s = unit_named(b, "stalker")
	eq(b.calc_damage(s, w, "ambush")["dmg"], 7, "Ambush +2 vs an isolated hero (5+2-0)")
	var moss = unit_named(b, "mender")
	moss.pos = Vector2i(0, 1)
	eq(b.calc_damage(s, w, "ambush")["dmg"], 5, "no Ambush bonus once an ally stands next to the target")


func test_volley_hits_enemies_only() -> void:
	var b := make_battle([
		".......",
		".......",
		"....r..",
		"1..rr2.",
		"....r..",
	], [["willow", 1], ["nox", 1]])
	var w = unit_named(b, "ranger")
	var nox = unit_named(b, "shadowblade")
	var center := Vector2i(4, 3)
	check(b.ability_targets(w, "volley").has(center), "volley target valid")
	var hp_nox: int = nox.hp
	check(b.cmd_ability(w, "volley", center), "volley accepted")
	var hit := 0
	for u in b.units:
		if u.side == "enemy" and u.hp < u.max_hp:
			hit += 1
	eq(hit, 4, "volley hits all 4 enemies in the plus shape")
	eq(nox.hp, hp_nox, "volley never hits allies")
	eq(unit_named(b, "recruit").hp, 5, "volley deals ATK-1 = 5")
	eq(int(w.cooldowns.get("volley", 0)), 3, "volley cooldown 2 (+ this turn)")


func test_shadow_pounce() -> void:
	var b := make_battle([
		"1....",
		".....",
		"...r.",
		".....",
	], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var r = unit_named(b, "recruit")
	check(b.ability_targets(nox, "pounce").has(r.pos) == false, "enemy at distance 5 out of pounce range (3)")
	check(b.cmd_move(nox, Vector2i(1, 1)), "move closer")
	check(b.ability_targets(nox, "pounce").has(r.pos), "enemy within 3 is a pounce target")
	var land: Vector2i = b.pounce_landing(nox, r.pos)
	check(land.x >= 0 and b.grid.walkable(land) and b.unit_at(land) == null, "landing tile is free and walkable")
	eq(abs(land.x - r.pos.x) + abs(land.y - r.pos.y), 1, "lands next to the target")
	check(b.cmd_ability(nox, "pounce", r.pos), "pounce accepted")
	eq(nox.pos, land, "Nox moved to the landing tile")
	eq(r.hp, 1, "pounce deals ATK+2 = 9")
	check(not nox.ability_ready("pounce"), "pounce on cooldown")
	# never through walls / onto occupied tiles
	var b2 := make_battle(["1#r", "###"], [["nox", 1]])
	var n2 = unit_named(b2, "shadowblade")
	check(not b2.ability_targets(n2, "pounce").has(Vector2i(2, 0)), "cannot pounce through a wall")
	var b3 := make_battle(["1..", "..."], [["nox", 1]])
	var n3 = unit_named(b3, "shadowblade")
	check(b3.ability_targets(n3, "pounce").has(Vector2i(2, 1)), "reposition pounce to an empty tile")
	check(b3.cmd_ability(n3, "pounce", Vector2i(2, 1)), "reposition accepted")
	eq(n3.pos, Vector2i(2, 1), "repositioned")


func test_heal_rules() -> void:
	var b := make_battle(["12.", "..."], [["moss", 1], ["bramble", 1]])
	var moss = unit_named(b, "mender")
	var br = unit_named(b, "guardian")
	check(b.ability_targets(moss, "mend").is_empty(), "no heal targets when everyone is healthy")
	br.hp -= 3
	check(not b.ability_targets(moss, "mend").has(moss.pos), "cannot heal self")
	check(b.cmd_ability(moss, "mend", br.pos), "heal accepted")
	eq(br.hp, br.max_hp, "heal is capped at max HP")


func test_knockout_and_invalid_targets() -> void:
	var b := make_battle(["1r.", "2.."], [["nox", 1], ["bramble", 1]])
	var nox = unit_named(b, "shadowblade")
	var br = unit_named(b, "guardian")
	var r = unit_named(b, "recruit")
	check(not b.cmd_ability(nox, "claw", Vector2i(2, 0)), "attacking an empty tile is rejected")
	check(not b.cmd_ability(nox, "claw", br.pos), "attacking an ally is rejected")
	check(not nox.acted, "rejected commands do not use the action")
	r.hp = 5
	check(b.cmd_ability(nox, "claw", r.pos), "finishing blow accepted")
	check(not r.alive, "enemy at 0 HP is defeated")
	check(b.unit_at(Vector2i(1, 0)) == null, "defeated enemy no longer occupies its tile")
	var ko := false
	for e in b.take_events():
		if e["t"] == "ko":
			ko = true
	check(ko, "a KO event is produced for the view")
	eq(nox.kills, 1, "kill credited")


func test_exhausted_and_immune() -> void:
	var b := make_battle(["1g.", "..."], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var g = unit_named(b, "guard")
	eq(b.calc_damage(nox, g, "claw")["dmg"], 4, "guard DEF 3")
	g.status["exhausted"] = 1
	eq(b.calc_damage(nox, g, "claw")["dmg"], 7, "exhausted: DEF 0")
	var b2 := make_battle(["1K.", "..Y"], [["nox", 1]])
	var n2 = unit_named(b2, "shadowblade")
	var k = unit_named(b2, "king")
	var d: Dictionary = b2.calc_damage(n2, k, "claw")
	eq(d["dmg"], 0, "the Pale King is immune while a pylon stands")
	check(bool(d["immune"]), "preview flags IMMUNE")


func test_hazard_damage() -> void:
	var b := make_battle(["1x.", "...", "..r"], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	check(b.cmd_move(nox, Vector2i(1, 0)), "step onto thorns")
	var hp: int = nox.hp
	b.cmd_end_phase()
	check(nox.hp <= hp - 3, "thorns dealt at least 3 damage by the start of the next hero turn")


func test_combat_is_deterministic() -> void:
	var results := []
	for i in 2:
		var m := Missions.get_mission("m02")
		var b := Battle.new()
		b.setup(m, [{"hero_id": "nox", "level": 2, "upgrades": {}}, {"hero_id": "bramble", "level": 2, "upgrades": {}},
			{"hero_id": "willow", "level": 2, "upgrades": {}}], "normal")
		var ai := preload("res://scripts/core/ai.gd").new()
		for t in 3:
			ai.play_hero_phase(b)
		var snap := []
		for u in b.units:
			snap.append([u.uid, u.pos, u.hp, u.alive])
		results.append(snap)
	eq(results[0], results[1], "identical inputs give identical battles")
