extends RefCounted
## Tactical AI: utility scoring over every (destination, action) pair.
##
## For each tile a unit can reach it scores the best action from there
## (damage, kills, target priority, heals, stances, objective interactions)
## plus the position itself (danger from opponents, cover, high ground,
## distance to its goals). The plan with the highest score wins; ties break
## deterministically. Used for enemies and by the automated test autoplayer
## for heroes. Every action goes through the same rules code as the player.

const Grid = preload("res://scripts/core/grid.gd")
const UD = preload("res://scripts/data/units_data.gd")

const PROFILES := {
	"melee": {"danger": 0.25, "approach": 1.0},
	"guard": {"danger": 0.3, "approach": 0.8, "escort_ranged": 3.0},
	"ranged": {"danger": 0.5, "approach": 0.8, "hill": 2.0, "adjacent": 6.0},
	"caster": {"danger": 0.5, "approach": 0.7, "adjacent": 5.0},
	"flanker": {"danger": 0.35, "approach": 1.2, "isolated": 4.0},
	"hero": {"danger": 0.5, "approach": 1.0},
	"hero_tank": {"danger": 0.1, "approach": 1.0},
	"hero_ranged": {"danger": 0.7, "approach": 0.8, "hill": 1.5, "adjacent": 5.0},
	"vip": {"danger": 2.0, "approach": 0.8},
}

var _danger_cache := {}
var _danger_key := ""


func take_turn(b: RefCounted, u: RefCounted) -> void:
	var plan := plan_turn(b, u)
	execute(b, u, plan, false)


## Plays one complete player phase with the AI (used by automated tests).
func play_hero_phase(b: RefCounted) -> void:
	var order: Array = b.side_units("hero")
	order.sort_custom(func(a: RefCounted, c: RefCounted) -> bool:
		var pa := _hero_order(a)
		var pc := _hero_order(c)
		return pa < pc or (pa == pc and a.uid < c.uid))
	for u: RefCounted in order:
		if not b.is_player_turn():
			return
		if not u.can_act():
			continue
		var plan := plan_turn(b, u)
		execute(b, u, plan, true)
	if b.is_player_turn():
		b.cmd_end_phase()


func _hero_order(u: RefCounted) -> int:
	match u.kind:
		"guardian": return 0
		"ranger": return 1
		"shadowblade": return 2
		"mender": return 4
		"elder": return 5
	return 3


func execute(b: RefCounted, u: RefCounted, plan: Dictionary, as_player: bool) -> void:
	var dest: Vector2i = plan.get("move", u.pos)
	if dest != u.pos:
		if as_player:
			b.cmd_move(u, dest)
		else:
			b._do_move(u, dest)
	var act: Dictionary = plan.get("action", {})
	if act.is_empty():
		if as_player:
			b.cmd_wait(u)
		return
	if act["type"] == "ability":
		var valid: bool = b.ability_targets(u, act["id"]).has(act["cell"])
		if not valid:
			if as_player:
				b.cmd_wait(u)
			return
		if as_player:
			b.cmd_ability(u, act["id"], act["cell"])
		else:
			b._do_ability(u, act["id"], act["cell"])
	elif act["type"] == "interact":
		if as_player:
			if not b.cmd_interact(u, act["kind"], act["cell"]):
				b.cmd_wait(u)
		else:
			b._do_interact(u, act["kind"], act["cell"])


func _profile(u: RefCounted) -> Dictionary:
	if u.side == "hero":
		if u.is_vip or u.kind == "elder":
			return PROFILES["vip"]
		match u.kind:
			"guardian": return PROFILES["hero_tank"]
			"ranger": return PROFILES["hero_ranged"]
		return PROFILES["hero"]
	return PROFILES.get(u.ai, PROFILES["melee"])


# --------------------------------------------------------------------------
# Planning
# --------------------------------------------------------------------------

func plan_turn(b: RefCounted, u: RefCounted) -> Dictionary:
	var prof := _profile(u)
	if u.side == "hero" and b.can_escape(u):
		# escaping is the job: weigh progress toward the exits much more
		prof = prof.duplicate()
		prof["approach"] = float(prof["approach"]) * 3.0
	var lim := int(b.mission.get("turn_limit", 0))
	if u.side == "hero" and lim > 0:
		# the clock is ticking: take more risks as the turn limit approaches
		var urgency := clampf(float(b.turn) / float(lim), 0.0, 1.0)
		prof = prof.duplicate()
		prof["danger"] = float(prof["danger"]) * (1.0 - 0.8 * urgency)
		prof["approach"] = float(prof["approach"]) * (1.0 + urgency)
	var field: Dictionary = b.move_field(u)
	var danger := danger_map(b, u.side)
	var goal := goal_field(b, u)
	var best := {"score": -INF, "move": u.pos, "action": {}}
	var cells: Array = field["cost"].keys()
	cells.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	var interacts_here := _is_hero_ai(u)
	for c: Vector2i in cells:
		if c != u.pos and b.unit_at(c) != null:
			continue
		var moved := 1 if c != u.pos else (1 if u.moved else 0)
		var pos_score := position_score(b, u, c, prof, danger, goal)
		# move / stay with no action
		_consider(best, pos_score - 0.01 * float(field["cost"][c]), c, {})
		for id: String in u.abilities:
			if b.ability_block_reason(u, id, moved) != "":
				continue
			var ab := UD.ability(id)
			for t: Vector2i in b.ability_targets(u, id, c, moved):
				var s := action_score(b, u, id, ab, c, t, moved, prof, danger, goal)
				if s <= -1000.0:
					continue
				var ps := pos_score
				if ab["kind"] == "pounce":
					var land: Vector2i = b.pounce_landing(u, t, c) if b.unit_at(t) != null else t
					ps = position_score(b, u, land, prof, danger, goal)
				_consider(best, ps + s - 0.01 * float(field["cost"][c]), c, {"type": "ability", "id": id, "cell": t})
		if interacts_here:
			for it: Dictionary in _interactions_at(b, u, c):
				_consider(best, pos_score + float(it["value"]), c, {"type": "interact", "kind": it["kind"], "cell": it["cell"]})
	return best


func _consider(best: Dictionary, score: float, c: Vector2i, action: Dictionary) -> void:
	if score > float(best["score"]) + 0.0001:
		best["score"] = score
		best["move"] = c
		best["action"] = action


func _is_hero_ai(u: RefCounted) -> bool:
	return u.side == "hero"


func _interactions_at(b: RefCounted, u: RefCounted, c: Vector2i) -> Array:
	var out := []
	if u.kind != "elder":
		for d: Vector2i in Grid.DIRS:
			if b.captives.has(c + d):
				out.append({"kind": "free", "cell": c + d, "value": 40.0})
		if b.relics.has(c) and not b.claimed.has(c):
			out.append({"kind": "claim", "cell": c, "value": 60.0})
	if b.exits.has(c) and b.can_escape(u):
		# in a pure escape mission, wait for the squad to gather a little first
		out.append({"kind": "escape", "cell": c, "value": 80.0})
	return out


func position_score(b: RefCounted, u: RefCounted, c: Vector2i, prof: Dictionary, danger: Dictionary, goal: Dictionary) -> float:
	var s := 0.0
	var dg := float(danger.get(c, 0.0))
	if dg > 0.0:
		s -= minf(dg, u.hp * 1.5) * float(prof.get("danger", 0.5))
		if dg >= u.hp:
			s -= 8.0 * float(prof.get("danger", 0.5))
	s += 1.5 * b.grid.defense(c)
	if b.grid.range_bonus(c) > 0:
		s += float(prof.get("hill", 0.0))
	if b.grid.hazard_damage(c) > 0:
		s -= 6.0
	var gd := float(goal.get(c, 999.0))
	if gd < 999.0:
		s -= gd * float(prof.get("approach", 1.0))
	else:
		s -= 60.0 * float(prof.get("approach", 1.0))
	if prof.has("adjacent"):
		for d: Vector2i in Grid.DIRS:
			var o: RefCounted = b.unit_at(c + d)
			if o != null and o != u and o.side != u.side and not o.is_object:
				s -= float(prof["adjacent"])
	if prof.has("escort_ranged"):
		for d: Vector2i in Grid.DIRS:
			var o: RefCounted = b.unit_at(c + d)
			if o != null and o != u and o.side == u.side and o.ai in ["ranged", "caster"]:
				s += float(prof["escort_ranged"])
				break
	# the escort target sticks close to its bodyguards
	if u.is_vip:
		var guards := 0
		for o: RefCounted in b.side_units("hero"):
			if o != u and Grid.dist(o.pos, c) <= 2:
				guards += 1
		s += minf(guards, 2) * 4.0
	# heroes: stay near friends (mutual protection against flankers)
	if u.side == "hero" and not u.is_vip:
		var near := 0
		for o: RefCounted in b.side_units("hero"):
			if o != u and Grid.dist(o.pos, c) <= 2:
				near += 1
		s += minf(near, 2) * 1.0
	return s


func action_score(b: RefCounted, u: RefCounted, id: String, ab: Dictionary, from: Vector2i, t: Vector2i, moved: int,
		prof: Dictionary, _danger: Dictionary, _goal: Dictionary) -> float:
	match str(ab["kind"]):
		"attack":
			var tgt: RefCounted = b.unit_at(t)
			if tgt == null:
				return -10000.0
			var dm: Dictionary = b.calc_damage(u, tgt, id, from, moved)
			return _damage_value(b, u, tgt, int(dm["dmg"]), prof)
		"pounce":
			var tgt: RefCounted = b.unit_at(t)
			if tgt == null:
				return -10000.0  # the AI never wastes a pounce on repositioning
			var land: Vector2i = b.pounce_landing(u, t, from)
			var dm: Dictionary = b.calc_damage(u, tgt, id, land, 1)
			return _damage_value(b, u, tgt, int(dm["dmg"]), prof) + 0.5
		"area":
			var total := 0.0
			for v: RefCounted in b.area_victims(u, t):
				var dm: Dictionary = b.calc_damage(u, v, id, from, moved)
				total += _damage_value(b, u, v, int(dm["dmg"]), prof)
			# keep the volley for groups
			return total - 4.0 if b.area_victims(u, t).size() < 2 else total
		"heal":
			var tgt: RefCounted = b.unit_at(t)
			if tgt == null:
				return -10000.0
			var amt := mini(b.heal_amount(u, id), tgt.max_hp - tgt.hp)
			var urgency: float = 1.0 + (1.0 - tgt.hp_ratio()) * 2.0
			if tgt.is_vip or tgt.is_boss:
				urgency += 1.0
			return amt * urgency - 3.0
		"stance":
			var dg := float(_danger.get(from, 0.0))
			var allies := 0
			for d: Vector2i in Grid.DIRS:
				var o: RefCounted = b.unit_at(from + d)
				if o != null and o.side == u.side and o != u and not o.is_object:
					allies += 1
			if dg <= 0.0 and allies == 0:
				return -2.0
			return minf(dg, 12.0) * 0.4 + allies * 3.0
	return -10000.0


func _damage_value(b: RefCounted, u: RefCounted, tgt: RefCounted, dmg: int, prof: Dictionary) -> float:
	if dmg <= 0:
		return -5.0
	var eff := mini(dmg, tgt.hp)
	var v := float(eff) * 1.2
	if dmg >= tgt.hp:
		v += 12.0 + tgt.atk * 0.5
	if tgt.is_vip:
		v += 6.0
	if tgt.is_object:
		if tgt.kind == "moonwell":
			v += 6.0
		elif tgt.kind == "pylon":
			v += 9.0
		else:
			v -= 2.0
	if tgt.is_boss or tgt.commander:
		v += 3.0
	if tgt.kind in ["ranger", "mender", "archer", "mage"]:
		v += 1.5
	if prof.has("isolated") and not b._adjacent_friend(tgt, tgt.pos, u):
		v += float(prof["isolated"])
	return v


# --------------------------------------------------------------------------
# Danger and goals
# --------------------------------------------------------------------------

## Expected damage a unit of `side` would take on each cell next opponent turn.
func danger_map(b: RefCounted, side: String) -> Dictionary:
	var opp_side := "enemy" if side == "hero" else "hero"
	var opps: Array = b.side_units(opp_side)
	var key := "%d|%s|%s|%d" % [b.turn, b.phase, side, opps.size()]
	if key == _danger_key:
		return _danger_cache
	var out := {}
	for o: RefCounted in opps:
		if o.abilities.is_empty():
			continue
		var power: int = o.atk
		for id: String in o.abilities:
			var ab := UD.ability(id)
			if str(ab["kind"]) in ["attack", "pounce"]:
				power = maxi(power, o.atk + int(ab.get("power", 0)))
		for c: Vector2i in _rough_threat(b, o):
			out[c] = float(out.get(c, 0.0)) + float(power)
	# telegraphed boss attacks are certain damage
	for tg: Dictionary in b.telegraphs:
		var owner: RefCounted = b.unit_by_uid(int(tg["uid"]))
		if owner != null and owner.side == opp_side:
			for c: Vector2i in tg["cells"]:
				out[c] = float(out.get(c, 0.0)) + float(tg["power"]) * 2.0
	_danger_key = key
	_danger_cache = out
	return out


func _rough_threat(b: RefCounted, o: RefCounted) -> Array:
	var f: Dictionary = b.move_field(o, o.effective_move())
	var rmax := 1
	var rmin := 1
	for id: String in o.abilities:
		var ab := UD.ability(id)
		if str(ab["kind"]) in ["attack", "pounce"]:
			rmax = maxi(rmax, int(ab["rmax"]))
			rmin = mini(rmin, int(ab["rmin"])) if int(ab["rmax"]) == 1 else rmin
			if int(ab["rmax"]) > 1 and rmin == 1 and o.abilities.size() == 1:
				rmin = int(ab["rmin"])
	var seen := {}
	for e: Vector2i in f["cost"]:
		var occ: RefCounted = b.unit_at(e)
		if occ != null and occ != o:
			continue
		for y in range(maxi(0, e.y - rmax), mini(b.grid.h, e.y + rmax + 1)):
			for x in range(maxi(0, e.x - rmax), mini(b.grid.w, e.x + rmax + 1)):
				var c := Vector2i(x, y)
				var d := Grid.dist(e, c)
				if d >= rmin and d <= rmax:
					seen[c] = true
	return seen.keys()


## Distance field (movement cost, ignoring units) to the unit's goals.
func goal_field(b: RefCounted, u: RefCounted) -> Dictionary:
	var sources := {}  ## cell -> starting offset (lower = more attractive)
	var ot: String = b.mission["objective"]["type"]
	var tag := str(b.mission["objective"].get("tag", ""))
	if u.side == "enemy":
		for o: RefCounted in b.opponents_of(u):
			var off := 4.0
			if o.is_vip or o.kind == "moonwell":
				off = 0.0
			elif o.kind in ["ranger", "mender"] and u.ai == "flanker":
				off = 2.0
			_add_source(b, sources, o.pos, off, true)
		if ot == "defend":
			for c: Vector2i in b.defend_cells:
				_add_source(b, sources, c, 0.0, false)
	else:
		if u.is_vip or (ot == "rescue_escape" and u.tag == tag) or (ot == "escape"):
			for c: Vector2i in b.exits:
				if b.unit_at(c) == null or b.unit_at(c) == u:
					_add_source(b, sources, c, 0.0 if (u.is_vip or u.tag == tag) else 2.0, false)
		if not u.is_vip and not (ot == "rescue_escape" and u.tag == tag):
			var king_immune := false
			for o: RefCounted in b.opponents_of(u):
				if o.kind == "pylon":
					king_immune = true
			for o: RefCounted in b.opponents_of(u):
				var off := 6.0
				if o.kind == "pylon":
					off = 0.0
				elif o.kind == "king" and king_immune:
					off = 14.0
				elif o.commander or o.is_boss:
					off = 3.0
				if ot == "escape":
					off += 8.0
				_add_source(b, sources, o.pos, off, true)
			if ot == "claim":
				for c: Vector2i in b.relics:
					if not b.claimed.has(c):
						_add_source(b, sources, c, 0.0, false)
			for c: Vector2i in b.captives:
				var off2 := 0.0 if (ot == "rescue_escape" and str(b.captives[c]) == tag) else 3.0
				_add_source(b, sources, c, off2, true)
			if b.treasure_cell.x >= 0 and not b.treasure_taken:
				_add_source(b, sources, b.treasure_cell, 4.0, false)
			if ot == "escort":
				for c: Vector2i in b.exits:
					_add_source(b, sources, c, 1.0, false)
				var el: RefCounted = b.unit_by_tag("elder")
				if el != null and el.on_field():
					_add_source(b, sources, el.pos, 3.0, true)
			if ot == "defend":
				for c: Vector2i in b.defend_cells:
					_add_source(b, sources, c, 3.0, true)
	return _multi_flood(b, u, sources)


func _add_source(b: RefCounted, sources: Dictionary, c: Vector2i, off: float, around: bool) -> void:
	var cells: Array[Vector2i] = []
	if around:
		for d: Vector2i in Grid.DIRS:
			cells.append(c + d)
	else:
		cells.append(c)
	for n: Vector2i in cells:
		if b.grid.walkable(n):
			sources[n] = minf(float(sources.get(n, 9999.0)), off)


func _multi_flood(b: RefCounted, u: RefCounted, sources: Dictionary) -> Dictionary:
	var best := sources.duplicate()
	var frontier: Array = []
	for c: Vector2i in sources:
		frontier.append([float(sources[c]), c])
	while not frontier.is_empty():
		var bi := 0
		for i in range(1, frontier.size()):
			if float(frontier[i][0]) < float(frontier[bi][0]):
				bi = i
		var cur: Array = frontier[bi]
		frontier.remove_at(bi)
		var cc: float = cur[0]
		var cell: Vector2i = cur[1]
		if cc > float(best.get(cell, 1e9)):
			continue
		for d: Vector2i in Grid.DIRS:
			var n: Vector2i = cell + d
			if not b.grid.walkable(n):
				continue
			var step := 1.0 if u.pathfinder else float(b.grid.move_cost(cell))
			var nc := cc + step
			if nc < float(best.get(n, 1e9)):
				best[n] = nc
				frontier.append([nc, n])
	return best
