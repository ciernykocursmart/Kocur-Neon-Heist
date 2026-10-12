extends RefCounted
## Battle model: the complete rules of one tactical mission.
##
## Pure logic (no nodes). The battle scene sends commands (move, ability,
## interact, end phase) and plays back the `events` list this model produces;
## visuals can never change game state. Every command is validated, so
## repeated clicks or commands in the wrong phase are simply rejected.

const Grid = preload("res://scripts/core/grid.gd")
const Unit = preload("res://scripts/core/unit.gd")
const UD = preload("res://scripts/data/units_data.gd")
const AI = preload("res://scripts/core/ai.gd")
const Bosses = preload("res://scripts/core/bosses.gd")

const FLANK_BONUS := 2
const ESCAPE_TYPES := ["escape", "rescue_escape", "escort"]

var grid: Grid
var units: Array = []  ## Array of Unit
var mission: Dictionary = {}
var difficulty := "normal"
var turn := 1
var phase := "setup"  ## setup, player, enemy, ended
var result := ""  ## "", victory, defeat
var defeat_reason := ""
var events: Array = []
var log_lines: Array[String] = []

var exits: Array[Vector2i] = []
var defend_cells: Array[Vector2i] = []
var relics: Array[Vector2i] = []
var claimed := {}
var treasure_cell := Vector2i(-1, -1)
var treasure_taken := false
var captives := {}  ## cell -> captive type
var captives_total := 0
var freed: Array[String] = []
var deploy_cells: Array[Vector2i] = []
var reinforcements: Array = []  ## remaining [{turn, units}]
var telegraphs: Array = []  ## [{uid, kind, cells, power, resolve_turn}]
var ko_count := 0
var kills_by_kind := {}
var _next_uid := 1
var _ai: AI
var _bosses: Bosses
var enemy_order_log: Array = []  ## uids that acted in the last enemy phase (tests)


func _init() -> void:
	_ai = AI.new()
	_bosses = Bosses.new()


# ==========================================================================
# Setup
# ==========================================================================

## squad: Array of {hero_id, level, upgrades} (deployed in slot order).
func setup(m: Dictionary, squad: Array, diff := "normal", roster := {}) -> void:
	mission = m
	difficulty = diff if diff in UD.DIFFICULTIES else "normal"
	var rows: Array = m["map"]
	grid = Grid.new()
	grid.setup(str(rows[0]).length(), rows.size())
	var slots := {}
	var cage_i := 0
	var cap_list: Array = m.get("captives", [])
	var enemy_spawns := []
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var c := Vector2i(x, y)
			if Grid.CHAR_TERRAIN.has(ch):
				grid.set_terrain(c, Grid.CHAR_TERRAIN[ch])
			else:
				grid.set_terrain(c, "grass")
			match ch:
				"E": exits.append(c)
				"D": defend_cells.append(c)
				"R": relics.append(c)
				"$": treasure_cell = c
				"C":
					captives[c] = cap_list[cage_i] if cage_i < cap_list.size() else "kitten"
					cage_i += 1
				"V": enemy_spawns.append(["V", c])
				"W": enemy_spawns.append(["W", c])
				_:
					if ch >= "1" and ch <= "9":
						slots[int(ch)] = c
					elif UD.ENEMY_CHARS.has(ch) or m.get("named", {}).has(ch):
						enemy_spawns.append([ch, c])
	captives_total = captives.size()
	var keys := slots.keys()
	keys.sort()
	for k: int in keys:
		deploy_cells.append(slots[k])
	for i in mini(squad.size(), deploy_cells.size()):
		var s: Dictionary = squad[i]
		spawn_hero(str(s["hero_id"]), int(s.get("level", 1)), s.get("upgrades", {}), deploy_cells[i])
	for sp: Array in enemy_spawns:
		var ch: String = sp[0]
		var c: Vector2i = sp[1]
		if ch == "V":
			var e := spawn_hero_special("elder", "Elder Whiskerton", c)
			e.is_vip = true
			e.tag = "elder"
		elif ch == "W":
			var w := spawn_enemy("moonwell", c, "hero")
			w.tag = "moonwell"
		elif m.get("named", {}).has(ch):
			var nd: Dictionary = m["named"][ch]
			var u := spawn_enemy(str(nd["kind"]), c)
			u.name = str(nd["name"])
			u.tag = str(nd.get("tag", ""))
			u.max_hp += int(nd.get("hp", 0))
			u.hp = u.max_hp
			u.atk += int(nd.get("atk", 0))
			u.commander = bool(nd.get("commander", false))
		else:
			var u2 := spawn_enemy(UD.ENEMY_CHARS[ch], c)
			if u2.kind == "ironpaw" or u2.kind == "king":
				u2.tag = u2.kind
	var alert := int(m.get("alert", 0))
	if alert > 0:
		for u: Unit in units:
			if u.side == "enemy" and not u.is_object and not u.is_boss:
				u.awake = false
	reinforcements = (m.get("reinforcements", []) as Array).duplicate(true)
	_bosses.setup(self)
	phase = "player"
	turn = 1
	_wake_check()
	_start_side("hero", true)
	_emit({"t": "phase", "phase": "player", "turn": turn})


func spawn_hero(hero_id: String, level: int, upgrades: Dictionary, c: Vector2i) -> Unit:
	var hd: Dictionary = UD.HEROES[hero_id]
	var cls: Dictionary = UD.CLASSES[hd["class"]]
	var st := UD.hero_stats(hero_id, level, upgrades)
	var u := Unit.new()
	u.uid = _next_uid
	_next_uid += 1
	u.side = "hero"
	u.kind = hd["class"]
	u.hero_id = hero_id
	u.name = hd["name"]
	u.max_hp = st["hp"]
	u.hp = u.max_hp
	u.atk = st["atk"]
	u.def = st["def"]
	u.move = st["move"]
	u.special = int(upgrades.get("special", 0)) > 0
	for a: String in cls["abilities"]:
		u.abilities.append(a)
	u.pos = c
	u.start_pos = c
	u.tag = hero_id
	units.append(u)
	return u


func spawn_hero_special(cls_id: String, uname: String, c: Vector2i) -> Unit:
	var cls: Dictionary = UD.CLASSES[cls_id]
	var u := Unit.new()
	u.uid = _next_uid
	_next_uid += 1
	u.side = "hero"
	u.kind = cls_id
	u.name = uname
	u.max_hp = cls["hp"]
	u.hp = u.max_hp
	u.atk = cls["atk"]
	u.def = cls["def"]
	u.move = cls["move"]
	u.pos = c
	u.start_pos = c
	units.append(u)
	return u


func spawn_enemy(kind: String, c: Vector2i, side := "enemy") -> Unit:
	var d: Dictionary = UD.ENEMIES[kind]
	var u := Unit.new()
	u.uid = _next_uid
	_next_uid += 1
	u.side = side
	u.kind = kind
	u.name = d["name"]
	var diff: Dictionary = UD.DIFFICULTY_INFO[difficulty]
	var hp := int(d["hp"])
	var atk := int(d["atk"])
	if side == "enemy" and not bool(d.get("object", false)):
		hp = maxi(1, int(round(hp * float(diff["enemy_hp"]))))
		atk = maxi(1, atk + int(diff["enemy_atk"]))
	u.max_hp = hp
	u.hp = hp
	u.atk = atk
	u.def = int(d["def"])
	u.move = int(d["move"])
	for a: String in d["abilities"]:
		u.abilities.append(a)
	u.ai = d["ai"]
	u.is_object = bool(d.get("object", false))
	u.is_boss = bool(d.get("boss", false))
	u.pathfinder = bool(d.get("pathfinder", false))
	u.pos = c
	u.start_pos = c
	units.append(u)
	return u


# ==========================================================================
# Queries
# ==========================================================================

func unit_by_uid(uid: int) -> Unit:
	for u: Unit in units:
		if u.uid == uid:
			return u
	return null


func unit_at(c: Vector2i) -> Unit:
	for u: Unit in units:
		if u.on_field() and u.pos == c:
			return u
	return null


func unit_by_tag(tag: String) -> Unit:
	for u: Unit in units:
		if u.tag == tag:
			return u
	return null


func side_units(side: String, include_objects := false) -> Array:
	var out := []
	for u: Unit in units:
		if u.side == side and u.on_field() and (include_objects or not u.is_object):
			out.append(u)
	return out


func opponents_of(u: Unit) -> Array:
	return side_units("enemy" if u.side == "hero" else "hero", true)


func is_opponent(a: Unit, b: Unit) -> bool:
	return a.side != b.side


func occupied(c: Vector2i) -> bool:
	return unit_at(c) != null


func is_player_turn() -> bool:
	return phase == "player" and result == ""


func can_command(u: Unit) -> bool:
	return is_player_turn() and u != null and u.side == "hero" and u.can_act()


func heroes_left_to_act() -> int:
	var n := 0
	for u: Unit in side_units("hero"):
		if u.can_act():
			n += 1
	return n


## Movement field for a unit: friendly units can be passed through, enemies
## block. Returns {"cost": {cell: cost}, "prev": {...}} including cells that
## are occupied by friends (they can be crossed but not ended on).
func move_field(u: Unit, budget := -1) -> Dictionary:
	if budget < 0:
		budget = u.effective_move()
	var passable := func(c: Vector2i) -> bool:
		if not grid.walkable(c):
			return false
		var o := unit_at(c)
		return o == null or (o.side == u.side and not o.is_object)
	var cost_fn := func(c: Vector2i) -> int:
		return 1 if u.pathfinder else grid.move_cost(c)
	return grid.flood(u.pos, budget, passable, cost_fn)


## Cells the unit can end its move on (excluding its own cell).
func reachable_cells(u: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if u.moved or u.acted or not u.on_field() or u.is_object:
		return out
	var f := move_field(u)
	for c: Vector2i in f["cost"]:
		if c != u.pos and unit_at(c) == null:
			out.append(c)
	return out


func path_to(u: Unit, dest: Vector2i) -> Array[Vector2i]:
	var f := move_field(u)
	return Grid.path_from(f["prev"], u.pos, dest)


## Attack range bonus for a ranged ability used from `from`.
func range_max(u: Unit, ab: Dictionary, from: Vector2i) -> int:
	var r := int(ab["rmax"])
	if r > 1 and str(ab["kind"]) in ["attack", "area"]:
		r += grid.range_bonus(from)
	if str(ab["kind"]) == "pounce" and u.special:
		r += 1
	return r


func ability_cooldown(u: Unit, id: String) -> int:
	var ab := UD.ability(id)
	var cd := int(ab.get("cd", 0))
	if u.special:
		match id:
			"stance": cd = maxi(0, cd - 1)
			"volley": cd = maxi(0, cd - 1)
	return cd


## Why an ability cannot be used right now ("" if it can).
func ability_block_reason(u: Unit, id: String, moved_override := -1) -> String:
	var ab := UD.ability(id)
	if ab.is_empty() or not u.abilities.has(id):
		return "Unknown ability"
	if not u.ability_ready(id):
		return "Ready in %d turn(s)" % int(u.cooldowns.get(id, 0))
	var moved := u.moved if moved_override < 0 else bool(moved_override)
	if bool(ab.get("no_move", false)) and moved:
		return "Only before moving"
	return ""


## Valid target cells for an ability used from `from` (default: current cell).
func ability_targets(u: Unit, id: String, from := Vector2i(-999, -999), moved_override := -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from.x == -999:
		from = u.pos
	if ability_block_reason(u, id, moved_override) != "":
		return out
	var ab := UD.ability(id)
	var kind: String = ab["kind"]
	var rmin := int(ab["rmin"])
	var rmax := range_max(u, ab, from)
	match kind:
		"attack":
			for o: Unit in opponents_of(u):
				var d := Grid.dist(from, o.pos)
				if d >= rmin and d <= rmax and (not bool(ab["los"]) or grid.has_los(from, o.pos)):
					out.append(o.pos)
		"heal":
			for a: Unit in side_units(u.side):
				if a == u or a.hp >= a.max_hp:
					continue
				var d := Grid.dist(from, a.pos)
				if d >= rmin and d <= rmax:
					out.append(a.pos)
		"stance":
			out.append(from)
		"area":
			for y in grid.h:
				for x in grid.w:
					var c := Vector2i(x, y)
					var d := Grid.dist(from, c)
					if d < rmin or d > rmax or grid.blocks_los(c) or not grid.has_los(from, c):
						continue
					if not area_victims(u, c).is_empty():
						out.append(c)
		"pounce":
			for y in grid.h:
				for x in grid.w:
					var c := Vector2i(x, y)
					var d := Grid.dist(from, c)
					if d < 1 or d > rmax or not grid.has_los(from, c):
						continue
					var o := unit_at(c)
					if o == null:
						if grid.walkable(c):
							out.append(c)
					elif is_opponent(u, o) and pounce_landing(u, c, from).x >= 0:
						out.append(c)
	return out


func area_cells(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [center]
	for d: Vector2i in Grid.DIRS:
		if grid.in_bounds(center + d):
			out.append(center + d)
	return out


func area_victims(u: Unit, center: Vector2i) -> Array:
	var out := []
	for c: Vector2i in area_cells(center):
		var o := unit_at(c)
		if o != null and is_opponent(u, o):
			out.append(o)
	return out


## Landing cell for a pounce at the enemy on `target`: the free walkable
## neighbour of the target that is closest to the pouncer, within range and in
## line of sight. (-1,-1) if none.
func pounce_landing(u: Unit, target: Vector2i, from := Vector2i(-999, -999)) -> Vector2i:
	if from.x == -999:
		from = u.pos
	var rmax := range_max(u, UD.ability("pounce"), from)
	var best := Vector2i(-1, -1)
	var best_d := 999
	for d: Vector2i in Grid.DIRS:
		var c: Vector2i = target + d
		if not grid.walkable(c):
			continue
		var o := unit_at(c)
		if o != null and o != u:
			continue
		var dd := Grid.dist(from, c)
		if dd > rmax or not grid.has_los(from, c):
			continue
		if dd < best_d:
			best_d = dd
			best = c
	return best


func _adjacent_friend(of: Unit, cell: Vector2i, exclude: Unit = null) -> bool:
	for d: Vector2i in Grid.DIRS:
		var o := unit_at(cell + d)
		if o != null and o != of and o != exclude and o.side == of.side and not o.is_object:
			return true
	return false


## Defence of `target` against an attack, with a readable breakdown.
func defense_of(target: Unit) -> Dictionary:
	var parts: Array[String] = []
	if target.has_status("exhausted") or target.has_status("drained"):
		return {"def": 0, "parts": ["Exhausted: DEF 0"]}
	var d := target.def
	parts.append("DEF %d" % target.def)
	var td := grid.defense(target.pos)
	if td > 0:
		d += td
		parts.append("cover +%d" % td)
	if target.has_status("stance"):
		d += 3
		parts.append("stance +3")
	if target.has_status("iron_guard"):
		d += 3
		parts.append("Iron Guard +3")
	# allies' auras
	var guard_aura := 0
	var wall := 0
	for dd: Vector2i in Grid.DIRS:
		var o := unit_at(target.pos + dd)
		if o == null or o.side != target.side or o == target:
			continue
		if o.has_status("stance"):
			guard_aura = maxi(guard_aura, 3 if o.special else 2)
		var ed: Dictionary = UD.ENEMIES.get(o.kind, {})
		wall = maxi(wall, int(ed.get("shield_wall", 0)))
	if guard_aura > 0:
		d += guard_aura
		parts.append("guarded +%d" % guard_aura)
	if wall > 0:
		d += wall
		parts.append("shield wall +%d" % wall)
	return {"def": d, "parts": parts}


## Deterministic damage of `ab_id` from attacker (standing on `from`) to target.
func calc_damage(att: Unit, target: Unit, ab_id: String, from := Vector2i(-999, -999), moved_override := -1) -> Dictionary:
	if from.x == -999:
		from = att.pos
	var ab := UD.ability(ab_id)
	var moved := att.moved if moved_override < 0 else bool(moved_override)
	var power := att.atk + int(ab.get("power", 0))
	var parts: Array[String] = ["ATK %d" % att.atk]
	if int(ab.get("power", 0)) != 0:
		parts.append("%s %+d" % [ab["name"], int(ab["power"])])
	if ab_id == "pounce" and att.special:
		power += 1
		parts.append("mastery +1")
	if ab.has("steady") and not moved:
		power += int(ab["steady"])
		parts.append("steady +%d" % int(ab["steady"]))
	var melee: bool = int(ab["rmax"]) == 1 or ab["kind"] == "pounce"
	if melee and str(ab["kind"]) in ["attack", "pounce"] and not target.is_object:
		var flank := false
		for d: Vector2i in Grid.DIRS:
			var o := unit_at(target.pos + d)
			if o != null and o != att and o.side == att.side and not o.is_object and o.pos != from:
				flank = true
		if flank:
			power += FLANK_BONUS
			parts.append("flank +%d" % FLANK_BONUS)
	if ab.has("isolated") and not target.is_object and not _adjacent_friend(target, target.pos, att):
		power += int(ab["isolated"])
		parts.append("isolated +%d" % int(ab["isolated"]))
	if _bosses.is_immune(self, target):
		return {"dmg": 0, "kills": false, "parts": parts + ["IMMUNE (pylons)"], "immune": true}
	var dinfo := defense_of(target)
	var dmg := maxi(1, power - int(dinfo["def"]))
	var all_parts: Array[String] = []
	all_parts.append_array(parts)
	for p: String in dinfo["parts"]:
		all_parts.append("-" + p if not p.begins_with("Exhausted") else p)
	return {"dmg": dmg, "kills": dmg >= target.hp, "parts": all_parts, "immune": false}


## True while the Pale King is shielded by a standing Crown Pylon.
func boss_immune(u: Unit) -> bool:
	return _bosses.is_immune(self, u)


func heal_amount(u: Unit, ab_id: String) -> int:
	var amt := int(UD.ability(ab_id)["power"])
	if ab_id == "mend" and u.special:
		amt += 4
	return amt


## Preview of using an ability on a target cell (for the HUD).
func preview(u: Unit, ab_id: String, cell: Vector2i) -> Dictionary:
	var ab := UD.ability(ab_id)
	var res := {"valid": ability_targets(u, ab_id).has(cell), "hits": [], "landing": Vector2i(-1, -1), "text": ""}
	match str(ab["kind"]):
		"attack":
			var t := unit_at(cell)
			if t:
				var dm := calc_damage(u, t, ab_id)
				res["hits"].append({"uid": t.uid, "dmg": dm["dmg"], "kills": dm["kills"]})
				res["text"] = "%s -> %s: %d dmg%s   (%s)" % [ab["name"], t.name, dm["dmg"], "  KO!" if dm["kills"] else "", ", ".join(dm["parts"])]
		"pounce":
			var t := unit_at(cell)
			if t and is_opponent(u, t):
				var land := pounce_landing(u, cell)
				res["landing"] = land
				var dm := calc_damage(u, t, ab_id, land, 1)
				res["hits"].append({"uid": t.uid, "dmg": dm["dmg"], "kills": dm["kills"]})
				res["text"] = "Pounce -> %s: %d dmg%s   (%s)" % [t.name, dm["dmg"], "  KO!" if dm["kills"] else "", ", ".join(dm["parts"])]
			else:
				res["landing"] = cell
				res["text"] = "Pounce: leap to this tile"
		"area":
			var names: Array[String] = []
			for v: Unit in area_victims(u, cell):
				var dm := calc_damage(u, v, ab_id)
				res["hits"].append({"uid": v.uid, "dmg": dm["dmg"], "kills": dm["kills"]})
				names.append("%s %d%s" % [v.name, dm["dmg"], " KO" if dm["kills"] else ""])
			res["text"] = "Volley: " + (", ".join(names) if not names.is_empty() else "no targets")
		"heal":
			var t := unit_at(cell)
			if t:
				var amt := mini(heal_amount(u, ab_id), t.max_hp - t.hp)
				res["text"] = "Mend %s: +%d HP" % [t.name, amt]
		"stance":
			res["text"] = "Protective Stance: +3 DEF self, +%d DEF to adjacent allies until your next turn" % (3 if u.special else 2)
	return res


## Every cell a unit could attack next turn (move + attack range), used for
## the threat overlay and the AI danger map. Ignores line of sight for speed
## except along the final check.
func threat_cells(u: Unit) -> Dictionary:
	var out := {}
	if not u.on_field() or u.is_object or u.abilities.is_empty():
		return out
	var f := move_field(u, u.effective_move())
	var ends: Array[Vector2i] = []
	for c: Vector2i in f["cost"]:
		var o := unit_at(c)
		if o == null or o == u:
			ends.append(c)
	for id: String in u.abilities:
		var ab := UD.ability(id)
		if str(ab["kind"]) not in ["attack", "pounce", "area"]:
			continue
		for e: Vector2i in ends:
			var rmax := range_max(u, ab, e)
			var rmin := int(ab["rmin"])
			for y in range(maxi(0, e.y - rmax), mini(grid.h, e.y + rmax + 1)):
				for x in range(maxi(0, e.x - rmax), mini(grid.w, e.x + rmax + 1)):
					var c := Vector2i(x, y)
					var d := Grid.dist(e, c)
					if d >= rmin and d <= rmax and not out.has(c):
						if bool(ab["los"]) and not grid.has_los(e, c):
							continue
						out[c] = true
	return out


# ==========================================================================
# Player commands (validated)
# ==========================================================================

func cmd_move(u: Unit, dest: Vector2i) -> bool:
	if not can_command(u) or u.moved:
		return false
	if not reachable_cells(u).has(dest):
		return false
	_do_move(u, dest)
	_check_end()
	return true


func cmd_undo_move(u: Unit) -> bool:
	if not can_command(u) or not u.moved or u.boss_state.get("move_locked", false):
		return false
	if unit_at(u.start_pos) != null:
		return false
	u.pos = u.start_pos
	u.moved = false
	_emit({"t": "teleport", "uid": u.uid, "to": u.pos})
	return true


func cmd_ability(u: Unit, id: String, cell: Vector2i) -> bool:
	if not can_command(u):
		return false
	if not ability_targets(u, id).has(cell):
		return false
	_do_ability(u, id, cell)
	_check_end()
	return true


func cmd_wait(u: Unit) -> bool:
	if not can_command(u):
		return false
	u.acted = true
	_emit({"t": "done", "uid": u.uid})
	return true


## Interactions available to a hero right now: [{kind, cell, text}]
func interactions(u: Unit) -> Array:
	var out := []
	if u == null or u.side != "hero" or not u.can_act() or u.is_object:
		return out
	if u.kind != "elder":
		for d: Vector2i in Grid.DIRS:
			var c: Vector2i = u.pos + d
			if captives.has(c):
				out.append({"kind": "free", "cell": c, "text": "Free captive"})
		if relics.has(u.pos) and not claimed.has(u.pos):
			out.append({"kind": "claim", "cell": u.pos, "text": "Claim relic"})
	if exits.has(u.pos) and can_escape(u):
		out.append({"kind": "escape", "cell": u.pos, "text": "Escape"})
	return out


func can_escape(u: Unit) -> bool:
	var ot: String = mission["objective"]["type"]
	if ot == "escape":
		return u.side == "hero" and not u.is_object
	if ot == "rescue_escape" or ot == "escort":
		return u.tag == str(mission["objective"].get("tag", ""))
	return false


func cmd_interact(u: Unit, kind: String, cell: Vector2i) -> bool:
	if not can_command(u):
		return false
	var ok := false
	for it: Dictionary in interactions(u):
		if it["kind"] == kind and it["cell"] == cell:
			ok = true
	if not ok:
		return false
	_do_interact(u, kind, cell)
	_check_end()
	return true


func cmd_end_phase() -> bool:
	if not is_player_turn():
		return false
	_run_enemy_phase()
	return true


# ==========================================================================
# Shared action resolution (used by player commands and the AI)
# ==========================================================================

func _do_move(u: Unit, dest: Vector2i) -> void:
	var path := path_to(u, dest)
	if path.is_empty():
		return
	u.pos = dest
	u.moved = true
	_emit({"t": "move", "uid": u.uid, "path": path})
	if u.side == "hero" and dest == treasure_cell and not treasure_taken:
		treasure_taken = true
		u.boss_state["move_locked"] = true
		_emit({"t": "treasure", "cell": dest, "uid": u.uid})
		_log("%s found the treasure!" % u.name)


func _do_ability(u: Unit, id: String, cell: Vector2i) -> void:
	var ab := UD.ability(id)
	var cd := ability_cooldown(u, id)
	if cd > 0:
		u.cooldowns[id] = cd + 1
	u.acted = true
	match str(ab["kind"]):
		"attack":
			var t := unit_at(cell)
			_emit({"t": "attack", "uid": u.uid, "target": t.uid, "ability": id, "ranged": int(ab["rmax"]) > 1,
				"from": u.pos, "to": cell})
			var dm := calc_damage(u, t, id)
			_log("%s uses %s on %s: %d damage." % [u.name, ab["name"], t.name, dm["dmg"]])
			apply_damage(t, int(dm["dmg"]), u)
			if bool(ab.get("chill", false)) and t.on_field():
				t.status["chilled"] = 2
				_emit({"t": "status", "uid": t.uid, "status": "chilled"})
		"pounce":
			var t := unit_at(cell)
			var from := u.pos
			if t != null and is_opponent(u, t):
				var land := pounce_landing(u, cell)
				u.pos = land
				u.moved = true
				_emit({"t": "pounce", "uid": u.uid, "from": from, "to": land})
				var dm := calc_damage(u, t, id, land, 1)
				_emit({"t": "attack", "uid": u.uid, "target": t.uid, "ability": id, "ranged": false, "from": land, "to": cell})
				_log("%s pounces on %s: %d damage." % [u.name, t.name, dm["dmg"]])
				apply_damage(t, int(dm["dmg"]), u)
			else:
				u.pos = cell
				u.moved = true
				_emit({"t": "pounce", "uid": u.uid, "from": from, "to": cell})
				_log("%s leaps into position." % u.name)
			if u.side == "hero" and u.pos == treasure_cell and not treasure_taken:
				treasure_taken = true
				_emit({"t": "treasure", "cell": u.pos, "uid": u.uid})
		"area":
			var cells := area_cells(cell)
			_emit({"t": "area", "uid": u.uid, "ability": id, "center": cell, "cells": cells, "from": u.pos})
			_log("%s fires a Volley!" % u.name)
			for v: Unit in area_victims(u, cell):
				var dm := calc_damage(u, v, id)
				apply_damage(v, int(dm["dmg"]), u)
		"heal":
			var t := unit_at(cell)
			var amt := mini(heal_amount(u, id), t.max_hp - t.hp)
			t.hp += amt
			_emit({"t": "heal", "uid": t.uid, "amount": amt, "hp": t.hp, "src": u.uid})
			_log("%s heals %s for %d." % [u.name, t.name, amt])
		"stance":
			u.status["stance"] = 1
			_emit({"t": "status", "uid": u.uid, "status": "stance"})
			_emit({"t": "sfx", "name": "stance"})
			_log("%s takes a Protective Stance." % u.name)


func _do_interact(u: Unit, kind: String, cell: Vector2i) -> void:
	u.acted = true
	match kind:
		"free":
			var who: String = captives[cell]
			captives.erase(cell)
			grid.set_terrain(cell, "grass")
			freed.append(who)
			var nu: Unit = null
			if UD.HEROES.has(who):
				var lvl := 1
				var ups := {}
				if mission.has("roster_levels") and mission["roster_levels"].has(who):
					lvl = int(mission["roster_levels"][who]["level"])
					ups = mission["roster_levels"][who].get("upgrades", {})
				nu = spawn_hero(who, lvl, ups, cell)
				nu.moved = true
				nu.acted = true
				_log("%s frees %s! %s joins the fight." % [u.name, nu.name, nu.name])
			else:
				_log("%s frees a captive kitten. It scampers to safety!" % u.name)
			_emit({"t": "free", "cell": cell, "captive": who, "uid": nu.uid if nu else -1})
		"claim":
			claimed[cell] = true
			_emit({"t": "claim", "cell": cell, "uid": u.uid})
			_log("%s claims a Crown Relic (%d/%d)." % [u.name, claimed.size(), relics.size()])
		"escape":
			u.escaped = true
			_emit({"t": "escape", "uid": u.uid})
			_log("%s escapes!" % u.name)


func apply_damage(t: Unit, amount: int, src: Unit = null) -> void:
	if not t.on_field() or amount <= 0:
		if amount <= 0 and t.on_field():
			_emit({"t": "damage", "uid": t.uid, "amount": 0, "hp": t.hp, "immune": true})
		return
	t.hp = maxi(0, t.hp - amount)
	_emit({"t": "damage", "uid": t.uid, "amount": amount, "hp": t.hp})
	if not t.awake:
		_wake(t)
	if t.hp <= 0:
		t.alive = false
		if src != null:
			src.kills += 1
		if t.side == "hero" and not t.is_object:
			ko_count += 1
			_log("%s is knocked out!" % t.name)
		else:
			_log("%s is defeated!" % t.name)
		if t.side == "enemy":
			kills_by_kind[t.kind] = int(kills_by_kind.get(t.kind, 0)) + 1
		_emit({"t": "ko", "uid": t.uid})
		for tg: Dictionary in telegraphs.duplicate():
			if int(tg["uid"]) == t.uid:
				telegraphs.erase(tg)
				_emit({"t": "telegraph_clear", "uid": t.uid})
	_bosses.on_damaged(self, t)


# ==========================================================================
# Phases
# ==========================================================================

func _start_side(side: String, first := false) -> void:
	for u: Unit in units:
		if u.side != side or not u.on_field():
			continue
		u.moved = false
		u.acted = false
		u.start_pos = u.pos
		u.boss_state.erase("move_locked")
		if not first:
			for k: String in u.cooldowns.keys():
				u.cooldowns[k] = maxi(0, int(u.cooldowns[k]) - 1)
			for k: String in u.status.keys():
				u.status[k] = int(u.status[k]) - 1
				if int(u.status[k]) <= 0:
					u.status.erase(k)
					_emit({"t": "status_end", "uid": u.uid, "status": k})
	if first:
		return
	# hazards
	for u: Unit in units.duplicate():
		if u.side == side and u.on_field() and not u.is_object:
			var hz := grid.hazard_damage(u.pos)
			if hz > 0:
				_log("%s is hurt by thorns." % u.name)
				apply_damage(u, hz, null)
	_check_end()


func _run_enemy_phase() -> void:
	phase = "enemy"
	enemy_order_log.clear()
	_emit({"t": "phase", "phase": "enemy", "turn": turn})
	_start_side("enemy")
	if result != "":
		return
	_bosses.resolve_telegraphs(self)
	_check_end()
	if result != "":
		return
	_spawn_reinforcements()
	_wake_check()
	var order := side_units("enemy")
	order.sort_custom(func(a: Unit, b: Unit) -> bool:
		var pa := _ai_priority(a)
		var pb := _ai_priority(b)
		return pa < pb or (pa == pb and a.uid < b.uid))
	for u: Unit in order:
		if result != "":
			break
		if not u.on_field() or u.is_object or not u.awake:
			continue
		enemy_order_log.append(u.uid)
		if u.is_boss:
			_bosses.take_turn(self, u)
		else:
			_ai.take_turn(self, u)
		u.acted = true
		_check_end()
	if result != "":
		return
	_end_round()
	if result != "":
		return
	turn += 1
	phase = "player"
	_emit({"t": "phase", "phase": "player", "turn": turn})
	_start_side("hero")


func _ai_priority(u: Unit) -> int:
	match u.ai:
		"caster": return 0
		"ranged": return 1
		"guard": return 2
		"melee": return 3
		"flanker": return 4
	return 5


func _end_round() -> void:
	var ot: String = mission["objective"]["type"]
	var n := int(mission["objective"].get("turns", 0))
	if ot == "defend":
		for c: Vector2i in defend_cells:
			var o := unit_at(c)
			if o != null and o.side == "enemy":
				_finish("defeat", "The shrine was overrun.")
				return
	if ot in ["defend", "survive", "protect"] and turn >= n:
		_finish("victory")
		return
	var lim := int(mission.get("turn_limit", 0))
	if lim > 0 and turn >= lim:
		_finish("defeat", "Out of time.")


func _spawn_reinforcements() -> void:
	for r: Dictionary in reinforcements.duplicate():
		if int(r["turn"]) != turn:
			continue
		reinforcements.erase(r)
		var n := 0
		for spec: Array in r["units"]:
			var c := free_cell_near(Vector2i(int(spec[1]), int(spec[2])))
			if c.x < 0:
				continue
			var u := spawn_enemy(UD.ENEMY_CHARS[spec[0]], c)
			u.moved = true  # arrives this phase but acts next turn
			u.acted = true
			_emit({"t": "spawn", "uid": u.uid})
			n += 1
		if n > 0:
			_emit({"t": "banner", "text": "Enemy reinforcements!"})
			_log("%d enemy reinforcements arrive!" % n)


## Reinforcement cells announced for the current turn's enemy phase.
func incoming_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Dictionary in reinforcements:
		if int(r["turn"]) == turn:
			for spec: Array in r["units"]:
				out.append(Vector2i(int(spec[1]), int(spec[2])))
	return out


func free_cell_near(c: Vector2i) -> Vector2i:
	var seen := {c: true}
	var q: Array[Vector2i] = [c]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if grid.walkable(cur) and unit_at(cur) == null:
			return cur
		for d: Vector2i in Grid.DIRS:
			var n: Vector2i = cur + d
			if grid.in_bounds(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return Vector2i(-1, -1)


func _wake(u: Unit) -> void:
	if u.awake:
		return
	u.awake = true
	_emit({"t": "wake", "uid": u.uid})
	# wake nearby sleepers too
	for o: Unit in side_units(u.side):
		if not o.awake and Grid.dist(o.pos, u.pos) <= 4:
			_wake(o)


func _wake_check() -> void:
	var r := int(mission.get("alert", 0))
	if r <= 0:
		return
	for e: Unit in side_units("enemy"):
		if e.awake:
			continue
		for h: Unit in side_units("hero"):
			if Grid.dist(e.pos, h.pos) <= r:
				_wake(e)
				break


# ==========================================================================
# Objectives
# ==========================================================================

func _check_end() -> void:
	if result != "":
		return
	var ob: Dictionary = mission["objective"]
	var ot: String = ob["type"]
	var tag := str(ob.get("tag", ""))
	# defeat conditions
	var heroes_on := side_units("hero")
	var escaped := 0
	for u: Unit in units:
		if u.side == "hero" and u.escaped:
			escaped += 1
	if heroes_on.is_empty():
		if ot == "escape" and escaped > 0:
			_finish("victory")
		else:
			_finish("defeat", "All heroes were knocked out.")
		return
	if ot in ["escort", "rescue_escape", "protect"]:
		var t := unit_by_tag(tag)
		if t != null and not t.alive:
			var why := {"escort": "Elder Whiskerton was knocked out.", "rescue_escape": "Moss was knocked out.",
				"protect": "The Moonwell was destroyed."}
			_finish("defeat", why[ot])
			return
	# victory conditions
	match ot:
		"eliminate":
			if _no_enemies_left():
				_finish("victory")
		"commander", "boss":
			var t := unit_by_tag(tag)
			if t != null and not t.alive:
				_finish("victory")
		"claim":
			if relics.size() > 0 and claimed.size() >= relics.size():
				_finish("victory")
		"escape":
			if escaped > 0 and heroes_on.is_empty():
				_finish("victory")
		"rescue_escape", "escort":
			var t := unit_by_tag(tag)
			if t != null and t.escaped:
				_finish("victory")
		"defend", "survive", "protect":
			if _no_enemies_left():
				_finish("victory")


func _no_enemies_left() -> bool:
	return side_units("enemy").is_empty() and reinforcements.is_empty()


func _finish(res: String, why := "") -> void:
	if result != "":
		return
	result = res
	defeat_reason = why
	phase = "ended"
	telegraphs.clear()
	_emit({"t": "end", "result": res, "reason": why})
	_log("VICTORY!" if res == "victory" else "DEFEAT. " + why)


## Live status of the optional objectives: [{text, state}] state: done/failed/open
func optional_status() -> Array:
	var out := []
	for o: Dictionary in mission.get("optional", []):
		out.append({"text": o["text"], "state": _optional_state(o)})
	return out


func _optional_state(o: Dictionary) -> String:
	var fin := result == "victory"
	match str(o["type"]):
		"turns":
			if turn > int(o["turns"]):
				return "failed"
			return "done" if fin else "open"
		"no_ko":
			if ko_count > 0:
				return "failed"
			return "done" if fin else "open"
		"treasure":
			return "done" if treasure_taken else ("failed" if fin else "open")
		"free_all":
			if freed.size() >= captives_total:
				return "done"
			return "failed" if fin else "open"
		"kill_tag":
			var t := unit_by_tag(str(o["tag"]))
			if t != null and not t.alive:
				return "done"
			return "failed" if fin else "open"
		"kill_kind":
			var alive_n := 0
			for u: Unit in units:
				if u.kind == str(o["kind"]) and u.on_field():
					alive_n += 1
			if alive_n == 0 and int(kills_by_kind.get(str(o["kind"]), 0)) > 0:
				return "done"
			return "failed" if fin else "open"
		"hp_tag":
			var t := unit_by_tag(str(o["tag"]))
			if t == null or not t.alive or t.hp_ratio() <= float(o["ratio"]):
				return "failed"
			return "done" if fin else "open"
		"kill_all":
			if _no_enemies_left():
				return "done"
			return "failed" if fin else "open"
	return "open"


func objective_text() -> String:
	var ob: Dictionary = mission["objective"]
	var t: String = ob["text"]
	match str(ob["type"]):
		"defend", "survive", "protect":
			t += "  (turn %d/%d)" % [mini(turn, int(ob["turns"])), int(ob["turns"])]
		"claim":
			t += "  (%d/%d)" % [claimed.size(), relics.size()]
		"rescue_escape":
			if not freed.has(str(ob.get("tag", ""))):
				t += "  - first free her"
	var lim := int(mission.get("turn_limit", 0))
	if lim > 0:
		t += "  [turn limit %d]" % lim
	return t


# ==========================================================================
# Events / log
# ==========================================================================

func _emit(e: Dictionary) -> void:
	events.append(e)


func _log(text: String) -> void:
	log_lines.append(text)
	_emit({"t": "log", "text": text})


func take_events() -> Array:
	var e := events
	events = []
	return e


## Summary used by the campaign when the battle ends.
func summary() -> Dictionary:
	var deployed := []
	var kills := {}
	for u: Unit in units:
		if u.side == "hero" and u.hero_id != "":
			deployed.append(u.hero_id)
			kills[u.hero_id] = u.kills
	var opt := []
	for o: Dictionary in optional_status():
		opt.append(o["state"] == "done")
	return {"result": result, "turns": turn, "deployed": deployed, "kills": kills, "optional": opt,
		"ko": ko_count, "freed": freed.duplicate()}
