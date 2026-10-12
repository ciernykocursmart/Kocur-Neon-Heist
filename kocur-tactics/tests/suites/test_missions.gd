extends "res://tests/test_case.gd"
## Validates every mission and challenge definition, then autoplays each one
## with the hero AI to prove it can be won.

const Sim = preload("res://tests/sim.gd")
const Grid = preload("res://scripts/core/grid.gd")
const OBJECTIVES := ["eliminate", "defend", "survive", "escape", "rescue_escape", "escort", "protect", "commander", "claim", "boss"]
const OPTIONALS := ["turns", "no_ko", "treasure", "free_all", "kill_tag", "kill_kind", "hp_tag", "kill_all"]
const MUSIC := ["act1", "act2", "act3", "boss", "final"]


func _all_ids() -> Array[String]:
	var ids := Missions.mission_ids()
	ids.append_array(Missions.challenge_ids())
	return ids


func test_campaign_shape() -> void:
	eq(Missions.mission_ids().size(), 12, "12 campaign missions")
	eq(Missions.challenge_ids().size(), 3, "3 challenge missions")
	var acts := {}
	var types := {}
	for id in Missions.mission_ids():
		var m := Missions.get_mission(id)
		acts[int(m["act"])] = int(acts.get(int(m["act"]), 0)) + 1
		types[m["objective"]["type"]] = true
	eq(acts.keys().size(), 3, "3 acts")
	for a in acts:
		check(int(acts[a]) == 4, "act %d has 4 missions" % a)
	check(types.size() >= 4, "at least 4 objective types (%d)" % types.size())
	eq(Missions.get_mission("m06")["objective"]["tag"], "ironpaw", "mid-campaign boss is Ironpaw")
	eq(Missions.get_mission("m12")["objective"]["tag"], "king", "final boss is the Pale King")


func test_definitions_valid() -> void:
	var seen := {}
	for id in _all_ids():
		var m := Missions.get_mission(id)
		check(not seen.has(id), "%s unique id" % id)
		seen[id] = true
		for k in ["name", "brief", "objective", "map", "optional"]:
			check(m.has(k), "%s has %s" % [id, k])
		check(m.has("slots") or m.has("squad"), "%s has slots or a fixed squad" % id)
		var slots: int = (m["squad"] as Array).size() if m.has("squad") else int(m["slots"])
		var rows: Array = m["map"]
		var w: int = str(rows[0]).length()
		for r: String in rows:
			check(r.length() == w, "%s: all map rows have equal width" % id)
		check(OBJECTIVES.has(m["objective"]["type"]), "%s objective type known" % id)
		check(MUSIC.has(str(m.get("music", "act1"))), "%s music track exists" % id)
		for o: Dictionary in m["optional"]:
			check(OPTIONALS.has(o["type"]), "%s optional type %s known" % [id, o["type"]])
			check(o.has("text"), "%s optional has text" % id)
		var b := Battle.new()
		b.setup(m, Sim.default_squad(m, 3), "normal")
		check(b.deploy_cells.size() >= slots, "%s: %d deploy tiles for %d slots" % [id, b.deploy_cells.size(), slots])
		check(b.side_units("hero").size() >= 1, "%s: heroes deployed" % id)
		check(b.side_units("enemy").size() >= 1, "%s: enemies present" % id)
		for u in b.units:
			check(b.grid.walkable(u.pos), "%s: %s starts on a walkable tile" % [id, u.name])
		var ot: String = m["objective"]["type"]
		match ot:
			"escape", "rescue_escape", "escort":
				check(b.exits.size() > 0, "%s: has exit tiles" % id)
			"defend":
				check(b.defend_cells.size() > 0, "%s: has shrine tiles" % id)
			"claim":
				check(b.relics.size() > 0, "%s: has relics" % id)
		if ot in ["rescue_escape"]:
			check((m.get("captives", []) as Array).has(m["objective"]["tag"]), "%s: rescue target is caged" % id)
		elif ot in ["escort", "protect", "commander", "boss"]:
			check(b.unit_by_tag(str(m["objective"]["tag"])) != null, "%s: objective unit '%s' exists" % [id, m["objective"]["tag"]])
		if m.has("captives"):
			eq(b.captives.size(), (m["captives"] as Array).size(), "%s: one cage per captive" % id)
		if ot in ["defend", "survive", "protect"]:
			check(int(m["objective"].get("turns", 0)) > 0, "%s: has a turn count" % id)
		for o: Dictionary in m["optional"]:
			if o["type"] == "treasure":
				check(b.treasure_cell.x >= 0, "%s: treasure on the map" % id)
			if o["type"] in ["kill_tag", "hp_tag"]:
				check(b.unit_by_tag(str(o["tag"])) != null, "%s: optional tag %s exists" % [id, o["tag"]])
		for r: Dictionary in m.get("reinforcements", []):
			for spec: Array in r["units"]:
				var c := Vector2i(int(spec[1]), int(spec[2]))
				check(b.grid.in_bounds(c) and b.grid.walkable(c), "%s: reinforcement tile %s valid" % [id, str(c)])
				check(UD.ENEMY_CHARS.has(spec[0]), "%s: reinforcement kind known" % id)


func test_maps_connected() -> void:
	# every hero deployment tile can reach every enemy's tile (ignoring units)
	for id in _all_ids():
		var m := Missions.get_mission(id)
		var b := Battle.new()
		b.setup(m, Sim.default_squad(m, 3), "normal")
		var start: Vector2i = b.deploy_cells[0]
		var pass_fn := func(c: Vector2i) -> bool: return b.grid.walkable(c) or b.captives.has(c)
		var cost_fn := func(c: Vector2i) -> int: return 1
		var f: Dictionary = b.grid.flood(start, 9999, pass_fn, cost_fn)
		var cost: Dictionary = f["cost"]
		for u in b.units:
			if u.side == "enemy" and not u.is_object:
				check(cost.has(u.pos) or u.pathfinder, "%s: %s reachable from deployment" % [id, u.name])
		for c in b.exits + b.defend_cells + b.relics:
			check(cost.has(c), "%s: objective tile %s reachable" % [id, str(c)])
		for c in b.captives:
			var adj := false
			for d: Vector2i in Grid.DIRS:
				if cost.has(c + d) and b.grid.walkable(c + d):
					adj = true
			check(adj, "%s: cage %s can be reached" % [id, str(c)])


func test_autoplay_wins_every_mission() -> void:
	var t0 := Time.get_ticks_msec()
	for id in _all_ids():
		var r: Dictionary = Sim.run(id, "normal", false)
		eq(r["result"], "victory", "%s winnable by the AI on Normal (turns %d, %s)" % [id, r["turns"], r["reason"]])
		note("%s normal: %s in %d turns, KO %d" % [id, r["result"], r["turns"], r["ko"]])
	note("autoplay of 15 missions: %d ms" % (Time.get_ticks_msec() - t0))


func test_autoplay_story_difficulty() -> void:
	for id in ["m01", "m04", "m06", "m10", "m12"]:
		var r: Dictionary = Sim.run(id, "story", false)
		eq(r["result"], "victory", "%s winnable on Story" % id)


func test_hard_difficulty_is_harder() -> void:
	var m := Missions.get_mission("m02")
	var bn := Battle.new()
	bn.setup(m, Sim.default_squad(m, 2), "normal")
	var bh := Battle.new()
	bh.setup(m, Sim.default_squad(m, 2), "hard")
	var bs := Battle.new()
	bs.setup(m, Sim.default_squad(m, 2), "story")
	var e_n = bn.side_units("enemy")[0]
	var e_h = bh.side_units("enemy")[0]
	var e_s = bs.side_units("enemy")[0]
	check(e_h.max_hp > e_n.max_hp and e_h.atk > e_n.atk, "hard enemies have more HP and ATK")
	check(e_s.max_hp < e_n.max_hp and e_s.atk < e_n.atk, "story enemies have less HP and ATK")
	for id in ["m03", "m08"]:
		var r: Dictionary = Sim.run(id, "hard", false)
		note("%s hard (AI): %s in %d turns" % [id, r["result"], r["turns"]])
