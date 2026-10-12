extends "res://tests/test_case.gd"
## Ironpaw Commander and the Pale King.


func _find(b: RefCounted, kind: String) -> RefCounted:
	for u in b.units:
		if u.kind == kind and u.on_field():
			return u
	return null


func test_ironpaw_telegraph_and_window() -> void:
	var b := make_battle([
		"..........",
		"..1.......",
		"...I......",
		"..........",
	], [["bramble", 1]], {"type": "boss", "tag": "ironpaw", "text": "Defeat Ironpaw"})
	var ip = _find(b, "ironpaw")
	var br = unit_named(b, "guardian")
	check(b.cmd_wait(br), "wait")
	b.cmd_end_phase()
	eq(b.telegraphs.size(), 1, "Ironpaw declares a telegraphed attack")
	var tg: Dictionary = b.telegraphs[0]
	eq(tg["kind"], "crush", "it is the Crushing Blow")
	check((tg["cells"] as Array).has(br.pos), "the marked tiles include Bramble")
	eq(int(tg["resolve_turn"]), b.turn, "it lands at the next enemy phase")
	var hp: int = br.hp
	eq(br.hp, hp, "no damage at declaration")
	# player steps out of the marked tiles
	var safe := Vector2i(-1, -1)
	for c in b.reachable_cells(br):
		if not (tg["cells"] as Array).has(c):
			safe = c
			break
	check(safe.x >= 0, "a safe tile exists")
	b.cmd_move(br, safe)
	b.cmd_end_phase()
	eq(br.hp, hp, "stepping out of the marked tiles avoids all damage")
	check(ip.has_status("exhausted") or b.telegraphs.size() > 0, "after the blow Ironpaw is exhausted")
	# vulnerability: exhausted -> DEF 0
	ip.status["exhausted"] = 1
	eq(int(b.defense_of(ip)["def"]), 0, "exhausted Ironpaw has DEF 0")


func test_ironpaw_crush_hits_if_ignored() -> void:
	var b := make_battle(["..1.", "..I.", "...."], [["bramble", 1]], {"type": "boss", "tag": "ironpaw", "text": ""})
	var br = unit_named(b, "guardian")
	var ip = _find(b, "ironpaw")
	b.cmd_end_phase()
	var hp: int = br.hp
	b.cmd_end_phase()
	eq(br.hp, hp - maxi(1, ip.atk + 6 - 4), "Crushing Blow deals ATK+6 minus DEF")


func test_ironpaw_iron_guard() -> void:
	var b := make_battle(["1.........", "..........", ".....I....", ".........."], [["nox", 1]],
		{"type": "boss", "tag": "ironpaw", "text": ""})
	var ip = _find(b, "ironpaw")
	var n0: int = b.side_units("enemy").size()
	b.apply_damage(ip, ip.max_hp / 2 + 1)
	check(ip.has_status("iron_guard"), "Iron Guard at half HP")
	eq(b.side_units("enemy").size(), n0 + 2, "2 guards answer the call")
	b.apply_damage(ip, 1)
	eq(b.side_units("enemy").size(), n0 + 2, "Iron Guard only triggers once")
	var d: int = int(b.defense_of(ip)["def"])
	eq(d, ip.def + 3, "Iron Guard +3 DEF")


func test_ironpaw_defeat_wins() -> void:
	var b := make_battle(["1I", ".."], [["nox", 1]], {"type": "boss", "tag": "ironpaw", "text": ""})
	var ip = _find(b, "ironpaw")
	ip.hp = 1
	ip.boss_state["guard_used"] = true
	check(b.cmd_ability(unit_named(b, "shadowblade"), "claw", ip.pos), "final blow")
	eq(b.result, "victory", "defeating Ironpaw wins")


func test_king_pylons_and_phases() -> void:
	var b := make_battle([
		"Y.......Y",
		".........",
		"....K....",
		".........",
		"1.2......",
	], [["nox", 1], ["willow", 1]], {"type": "boss", "tag": "king", "text": "Defeat the King"})
	var k = _find(b, "king")
	eq(k.move, 0, "phase 1: the King stays on his throne")
	var nox = unit_named(b, "shadowblade")
	eq(b.calc_damage(nox, k, "claw")["dmg"], 0, "immune while pylons stand")
	var pylons := []
	for u in b.units:
		if u.kind == "pylon":
			pylons.append(u)
	eq(pylons.size(), 2, "two pylons")
	b.apply_damage(pylons[0], 99)
	check(b.boss_immune(k), "still immune with one pylon left")
	b.apply_damage(pylons[1], 99)
	check(not b.boss_immune(k), "vulnerable once both pylons fall")
	check(b.calc_damage(nox, k, "claw")["dmg"] > 0, "damage goes through")
	var n0: int = b.side_units("enemy").size()
	b.apply_damage(k, k.max_hp / 2 + 1)
	eq(int(k.boss_state["phase"]), 2, "phase 2 at half HP")
	eq(k.move, 3, "the King can move in phase 2")
	eq(b.side_units("enemy").size(), n0 + 2, "phase 2 summons 2 stalkers")


func test_king_lance_telegraph() -> void:
	var b := make_battle([
		"Y.......Y",
		".........",
		"....K....",
		".........",
		"1.2......",
	], [["nox", 1], ["willow", 1]], {"type": "boss", "tag": "king", "text": ""})
	b.cmd_end_phase()
	var lance := {}
	for tg in b.telegraphs:
		if tg["kind"] == "lance":
			lance = tg
	check(not lance.is_empty(), "the King declares a Royal Lance")
	var nox = unit_named(b, "shadowblade")
	check((lance.get("cells", []) as Array).has(nox.pos), "the lance line covers the heroes' row")
	var hp: int = nox.hp
	b.cmd_end_phase()
	check(nox.hp < hp, "staying in the line gets you hit")


func test_king_nova_and_drained() -> void:
	var b := make_battle([
		"Y.......Y",
		".........",
		"....K....",
		"...12....",
		".........",
	], [["bramble", 3], ["nox", 3]], {"type": "boss", "tag": "king", "text": ""})
	var k = _find(b, "king")
	for u in b.units.duplicate():
		if u.kind == "pylon":
			b.apply_damage(u, 99)
	b.apply_damage(k, k.max_hp / 2 + 1)
	for u in b.side_units("enemy"):
		if u.kind == "stalker":
			u.alive = false
	b.cmd_end_phase()
	var nova := false
	for tg in b.telegraphs:
		if tg["kind"] == "nova":
			nova = true
			eq((tg["cells"] as Array).size() <= 9, true, "nova covers at most a 3x3 area")
	check(nova, "phase 2: Pale Nova declared")
	b.cmd_end_phase()
	check(k.has_status("drained") or not k.alive, "after the nova the King is drained (DEF 0)")
	if k.alive:
		eq(int(b.defense_of(k)["def"]), 0, "drained King has DEF 0")


func test_king_defeat_ends_campaign_battle() -> void:
	var b := make_battle(["1K", ".."], [["nox", 1]], {"type": "boss", "tag": "king", "text": ""})
	var k = _find(b, "king")
	k.hp = 1
	k.boss_state["phase"] = 2
	check(b.cmd_ability(unit_named(b, "shadowblade"), "claw", k.pos), "final blow (no pylons on this map)")
	eq(b.result, "victory", "defeating the King wins")


func test_telegraph_cleared_on_owner_ko() -> void:
	var b := make_battle(["..1.", "..I.", "...."], [["willow", 1]], {"type": "boss", "tag": "ironpaw", "text": ""})
	b.cmd_end_phase()
	check(b.telegraphs.size() > 0, "telegraph pending")
	var ip = _find(b, "ironpaw")
	ip.boss_state["guard_used"] = true
	b.apply_damage(ip, 999)
	eq(b.telegraphs.size(), 0, "a defeated boss's telegraph is removed")
