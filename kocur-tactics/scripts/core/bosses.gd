extends RefCounted
## Boss rules: the Ironpaw Commander and the Pale King.
##
## Every big boss attack is telegraphed: it marks its tiles during the enemy
## phase and resolves at the START of the next enemy phase, so the player
## always gets a full turn to step out, defend or interrupt.

const Grid = preload("res://scripts/core/grid.gd")
const UD = preload("res://scripts/data/units_data.gd")
const AI = preload("res://scripts/core/ai.gd")

const CRUSH_BONUS := 6
const LANCE_BONUS := 4
const NOVA_BONUS := 4
const MAX_ENEMIES_FOR_SUMMON := 7

var _ai := AI.new()


func setup(b: RefCounted) -> void:
	for u: RefCounted in b.units:
		match u.kind:
			"ironpaw":
				u.boss_state = {"guard_used": false}
			"king":
				u.boss_state = {"phase": 1, "lance_cd": 0, "summon_cd": 2, "nova_cd": 0}
				u.move = 0  # phase 1: stays on the throne


func is_immune(b: RefCounted, t: RefCounted) -> bool:
	if t.kind != "king":
		return false
	for u: RefCounted in b.units:
		if u.kind == "pylon" and u.on_field():
			return true
	return false


func pending_for(b: RefCounted, u: RefCounted) -> Dictionary:
	for tg: Dictionary in b.telegraphs:
		if int(tg["uid"]) == u.uid:
			return tg
	return {}


# --------------------------------------------------------------------------
# Reactions to damage (phase changes)
# --------------------------------------------------------------------------

func on_damaged(b: RefCounted, t: RefCounted) -> void:
	if t.kind == "ironpaw" and t.on_field() and not bool(t.boss_state.get("guard_used", false)) and t.hp <= t.max_hp / 2:
		t.boss_state["guard_used"] = true
		t.status["iron_guard"] = 2
		b._emit({"t": "status", "uid": t.uid, "status": "iron_guard"})
		b._emit({"t": "banner", "text": "Ironpaw raises his IRON GUARD! (+3 DEF for 2 turns)"})
		b._emit({"t": "sfx", "name": "boss"})
		b._log("Ironpaw roars for help and raises his Iron Guard!")
		_spawn_near(b, "guard", t.pos, 2)
	elif t.kind == "king" and t.on_field() and int(t.boss_state.get("phase", 1)) == 1 and t.hp <= t.max_hp / 2:
		t.boss_state["phase"] = 2
		t.move = 3
		t.boss_state["nova_cd"] = 0
		b._emit({"t": "banner", "text": "PHASE 2: The Pale King leaves his throne!"})
		b._emit({"t": "sfx", "name": "phase"})
		b._log("The Pale King rises from the throne, crackling with pale light!")
		_spawn_near(b, "stalker", t.pos, 2)
	elif t.kind == "pylon" and not t.alive:
		var k: RefCounted = b.unit_by_tag("king")
		if k != null and k.on_field() and not is_immune(b, k):
			if true:
				b._emit({"t": "banner", "text": "The King's shield shatters! He can be hurt!"})
				b._emit({"t": "sfx", "name": "phase"})
				b._log("Both Crown Pylons are down - the Pale King is vulnerable!")


func _spawn_near(b: RefCounted, kind: String, c: Vector2i, n: int) -> void:
	var count := 0
	for d: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, 1)]:
		if count >= n:
			break
		var cell: Vector2i = b.free_cell_near(c + d)
		if cell.x < 0:
			continue
		var u: RefCounted = b.spawn_enemy(kind, cell)
		u.moved = true
		u.acted = true
		b._emit({"t": "spawn", "uid": u.uid})
		count += 1


# --------------------------------------------------------------------------
# Telegraph resolution (start of the enemy phase)
# --------------------------------------------------------------------------

func resolve_telegraphs(b: RefCounted) -> void:
	for tg: Dictionary in b.telegraphs.duplicate():
		if int(tg["resolve_turn"]) > b.turn:
			continue
		b.telegraphs.erase(tg)
		var owner: RefCounted = b.unit_by_uid(int(tg["uid"]))
		b._emit({"t": "telegraph_clear", "uid": int(tg["uid"])})
		if owner == null or not owner.on_field():
			continue
		match str(tg["kind"]):
			"crush", "lance", "nova":
				b._emit({"t": "blast", "uid": owner.uid, "kind": tg["kind"], "cells": tg["cells"]})
				var names := {"crush": "Crushing Blow", "lance": "Royal Lance", "nova": "Pale Nova"}
				b._log("%s unleashes %s!" % [owner.name, names[tg["kind"]]])
				for c: Vector2i in tg["cells"]:
					var v: RefCounted = b.unit_at(c)
					if v != null and v.side != owner.side:
						var d: int = b.defense_of(v)["def"]
						var dmg := maxi(1, int(tg["power"]) - d)
						b._log("  %s is hit for %d!" % [v.name, dmg])
						b.apply_damage(v, dmg, owner)
				if tg["kind"] == "crush":
					owner.status["exhausted"] = 1
					b._emit({"t": "status", "uid": owner.uid, "status": "exhausted"})
					b._log("Ironpaw is EXHAUSTED: DEF 0 until his next turn!")
				elif tg["kind"] == "nova":
					owner.status["drained"] = 1
					b._emit({"t": "status", "uid": owner.uid, "status": "drained"})
					b._log("The Pale King is DRAINED: DEF 0 until his next turn!")
			"summon":
				var n := 0
				for c: Vector2i in tg["cells"]:
					var cell: Vector2i = b.free_cell_near(c)
					if cell.x >= 0:
						var u: RefCounted = b.spawn_enemy("recruit", cell)
						u.moved = true
						u.acted = true
						b._emit({"t": "spawn", "uid": u.uid})
						n += 1
				b._log("The Pale King summons %d recruits!" % n)
		if b.result != "":
			return


func _declare(b: RefCounted, u: RefCounted, kind: String, cells: Array, power: int, label: String) -> void:
	var tg := {"uid": u.uid, "kind": kind, "cells": cells, "power": power, "resolve_turn": b.turn + 1, "label": label}
	b.telegraphs.append(tg)
	b._emit({"t": "telegraph", "uid": u.uid, "kind": kind, "cells": cells})
	b._emit({"t": "sfx", "name": "warn"})
	b._log("%s prepares %s! (marked tiles, lands next enemy turn)" % [u.name, label])


# --------------------------------------------------------------------------
# Boss turns
# --------------------------------------------------------------------------

func take_turn(b: RefCounted, u: RefCounted) -> void:
	match u.kind:
		"ironpaw": _ironpaw_turn(b, u)
		"king": _king_turn(b, u)
		_: _ai.take_turn(b, u)


func _ironpaw_turn(b: RefCounted, u: RefCounted) -> void:
	if u.has_status("exhausted"):
		b._log("Ironpaw is catching his breath.")
		return
	if not pending_for(b, u).is_empty():
		return
	var target := _adjacent_hero(b, u, u.pos)
	if target == null:
		# move to the best tile next to a hero (or as close as possible)
		var dest := _approach_cell(b, u)
		if dest != u.pos:
			b._do_move(u, dest)
		target = _adjacent_hero(b, u, u.pos)
	if target != null:
		var dir: Vector2i = target.pos - u.pos
		var perp := Vector2i(dir.y, dir.x)
		var cells: Array[Vector2i] = []
		for c: Vector2i in [target.pos, target.pos + perp, target.pos - perp]:
			if b.grid.in_bounds(c) and not b.grid.blocks_los(c):
				cells.append(c)
		_declare(b, u, "crush", cells, u.atk + CRUSH_BONUS, "a CRUSHING BLOW")


func _adjacent_hero(b: RefCounted, u: RefCounted, from: Vector2i) -> RefCounted:
	var best: RefCounted = null
	for d: Vector2i in Grid.DIRS:
		var o: RefCounted = b.unit_at(from + d)
		if o != null and o.side != u.side:
			if best == null or o.hp < best.hp or (o.hp == best.hp and o.uid < best.uid):
				best = o
	return best


func _approach_cell(b: RefCounted, u: RefCounted) -> Vector2i:
	var field: Dictionary = b.move_field(u)
	var goal: Dictionary = _ai.goal_field(b, u)
	var best: Vector2i = u.pos
	var best_s := -INF
	var cells: Array = field["cost"].keys()
	cells.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	for c: Vector2i in cells:
		if c != u.pos and b.unit_at(c) != null:
			continue
		var s := -float(goal.get(c, 999.0)) - 0.01 * float(field["cost"][c])
		var adj := _adjacent_hero(b, u, c)
		if adj != null:
			s += 20.0 + (30.0 - adj.hp) * 0.2
		if s > best_s:
			best_s = s
			best = c
	return best


func _king_turn(b: RefCounted, u: RefCounted) -> void:
	var st: Dictionary = u.boss_state
	for k in ["lance_cd", "summon_cd", "nova_cd"]:
		st[k] = maxi(0, int(st.get(k, 0)) - 1)
	if u.has_status("drained"):
		b._log("The Pale King is drained and cannot act.")
		return
	var has_pending := not pending_for(b, u).is_empty()
	if int(st["phase"]) == 1:
		if not has_pending and int(st["lance_cd"]) <= 0:
			var line := _best_line(b, u)
			if not line.is_empty():
				_declare(b, u, "lance", line, u.atk + LANCE_BONUS, "the ROYAL LANCE")
				st["lance_cd"] = 2
				has_pending = true
		if not has_pending and int(st["summon_cd"]) <= 0 and b.side_units("enemy").size() < MAX_ENEMIES_FOR_SUMMON:
			var cells: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(-2, 1), Vector2i(2, 1)]:
				var c: Vector2i = b.free_cell_near(u.pos + d)
				if c.x >= 0 and not cells.has(c):
					cells.append(c)
			if not cells.is_empty():
				_declare(b, u, "summon", cells, 0, "to SUMMON reinforcements")
				st["summon_cd"] = 4
		# claw anyone foolish enough to stand next to the throne
		var adj := _adjacent_hero(b, u, u.pos)
		if adj != null:
			b._do_ability(u, "royal_claw", adj.pos)
		return
	# phase 2: mobile
	if not has_pending and int(st["nova_cd"]) <= 0:
		var dest := _approach_cell(b, u)
		if dest != u.pos:
			b._do_move(u, dest)
		var center := _best_nova(b, u)
		if center.x >= 0:
			var cells: Array[Vector2i] = []
			for y in range(-1, 2):
				for x in range(-1, 2):
					var c := center + Vector2i(x, y)
					if b.grid.in_bounds(c) and not b.grid.blocks_los(c):
						cells.append(c)
			_declare(b, u, "nova", cells, u.atk + NOVA_BONUS, "a PALE NOVA")
			st["nova_cd"] = 3
			return
	if not has_pending and int(st["lance_cd"]) <= 0:
		var line := _best_line(b, u)
		if not line.is_empty():
			_declare(b, u, "lance", line, u.atk + LANCE_BONUS, "the ROYAL LANCE")
			st["lance_cd"] = 2
			var adj2 := _adjacent_hero(b, u, u.pos)
			if adj2 != null:
				b._do_ability(u, "royal_claw", adj2.pos)
			return
	# otherwise fight normally
	_ai.take_turn(b, u)


## The row or column (through the King's reach) holding the most heroes.
func _best_line(b: RefCounted, u: RefCounted) -> Array:
	var best: Array = []
	var best_n := 0
	var best_d := 999
	var heroes: Array = b.side_units("hero", true)
	for horiz in [true, false]:
		var count: int = b.grid.h if horiz else b.grid.w
		for i in count:
			var n := 0
			for hu: RefCounted in heroes:
				if (horiz and hu.pos.y == i) or (not horiz and hu.pos.x == i):
					n += 1
			if n == 0:
				continue
			var d := absi((u.pos.y if horiz else u.pos.x) - i)
			if n > best_n or (n == best_n and d < best_d):
				best_n = n
				best_d = d
				var cells: Array[Vector2i] = []
				var length: int = b.grid.w if horiz else b.grid.h
				for j in length:
					var c := Vector2i(j, i) if horiz else Vector2i(i, j)
					if not b.grid.blocks_los(c) and c != u.pos:
						cells.append(c)
				best = cells
	return best


func _best_nova(b: RefCounted, u: RefCounted) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_n := 0
	for hu: RefCounted in b.side_units("hero", true):
		if Grid.dist(hu.pos, u.pos) > 5:
			continue
		var n := 0
		for o: RefCounted in b.side_units("hero", true):
			if absi(o.pos.x - hu.pos.x) <= 1 and absi(o.pos.y - hu.pos.y) <= 1:
				n += 1
		if n > best_n:
			best_n = n
			best = hu.pos
	return best
