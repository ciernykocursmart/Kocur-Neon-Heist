class_name Puzzle
extends RefCounted
## Pure, deterministic puzzle logic (no nodes). Used by the game, the tests and the solver.
##
## Legend: # wall  . floor  @ cat  $ crate  T target  E exit  f fish  p switch  D door
##         k key  L locked door  i ice  a/b/c teleport pairs  x/y timed gates (open on even/odd move)
## The exit opens when every target holds a crate. Doors open while every switch is pressed.

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

var w := 0
var h := 0
var base: Array = []            # Array of PackedStringArray-like rows (Array of String chars)
var start := Vector2i.ZERO
var player := Vector2i.ZERO
var crates: Array = []          # Array[Vector2i], index = identity
var fish: Dictionary = {}       # remaining fish tiles
var floor_keys: Dictionary = {} # remaining keys on the floor
var keys := 0
var unlocked: Dictionary = {}   # opened locked doors
var moves := 0
var doors_open := false
var won := false
var fish_total := 0
var targets: Array = []
var switches: Array = []
var pads: Dictionary = {}       # char -> Array[Vector2i]
var has_gates := false
var _start_crates: Array = []
var _start_fish: Dictionary = {}
var _start_keys: Dictionary = {}
var undo_stack: Array = []

func _init(rows: Array = []) -> void:
	if rows.size() > 0:
		load_rows(rows)

func load_rows(rows: Array) -> void:
	h = rows.size()
	w = 0
	for r in rows:
		w = max(w, String(r).length())
	base = []
	crates = []
	fish = {}
	floor_keys = {}
	targets = []
	switches = []
	pads = {}
	has_gates = false
	for y in h:
		var line := []
		var s := String(rows[y])
		for x in w:
			var c := s[x] if x < s.length() else "#"
			var p := Vector2i(x, y)
			match c:
				"@": start = p; c = "."
				"$": crates.append(p); c = "."
				"f": fish[p] = true; c = "."
				"k": floor_keys[p] = true; c = "."
				" ": c = "#"
			match c:
				"T": targets.append(p)
				"p": switches.append(p)
				"a", "b", "c":
					if not pads.has(c): pads[c] = []
					pads[c].append(p)
				"x", "y": has_gates = true
			line.append(c)
		base.append(line)
	_start_crates = crates.duplicate()
	_start_fish = fish.duplicate()
	_start_keys = floor_keys.duplicate()
	fish_total = fish.size()
	restart()

func restart() -> void:
	player = start
	crates = _start_crates.duplicate()
	fish = _start_fish.duplicate()
	floor_keys = _start_keys.duplicate()
	keys = 0
	unlocked = {}
	moves = 0
	won = false
	undo_stack = []
	_update_state()

func tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return "#"
	return base[p.y][p.x]

func crate_at(p: Vector2i) -> int:
	return crates.find(p)

func fish_collected() -> int:
	return fish_total - fish.size()

func exit_open() -> bool:
	for t in targets:
		if crate_at(t) < 0:
			return false
	return true

func _update_state() -> void:
	var all := switches.size() > 0
	for s in switches:
		if crate_at(s) < 0 and player != s:
			all = false
	doors_open = all
	won = tile(player) == "E" and exit_open()

func _passable(p: Vector2i, d: Vector2i, for_crate: bool) -> bool:
	match tile(p):
		"#": return false
		"D": return doors_open
		"L": return unlocked.has(p) or (not for_crate and keys > 0)
		"x": return moves % 2 == 0
		"y": return moves % 2 == 1
	return true

func _enter(p: Vector2i) -> void:
	player = p
	fish.erase(p)
	if floor_keys.erase(p):
		keys += 1
	if tile(p) == "L" and not unlocked.has(p):
		keys -= 1
		unlocked[p] = true

func _snap() -> Dictionary:
	return {"p": player, "c": crates.duplicate(), "f": fish.duplicate(), "k": floor_keys.duplicate(),
		"n": keys, "u": unlocked.duplicate(), "m": moves}

func _restore(s: Dictionary) -> void:
	player = s.p
	crates = s.c.duplicate()
	fish = s.f.duplicate()
	floor_keys = s.k.duplicate()
	keys = s.n
	unlocked = s.u.duplicate()
	moves = s.m
	_update_state()

## Returns {ok, pushed, fish, key, door, tp, slid, won}. ok=false means nothing changed.
func move(dir: String, record := true) -> Dictionary:
	var res := {"ok": false, "pushed": false, "fish": 0, "key": false, "door": false, "tp": false, "slid": false, "won": false}
	if won:
		return res
	var d: Vector2i = DIRS[dir]
	var before := _snap()
	var n := player + d
	var ci := crate_at(n)
	if ci >= 0:
		if not _push(ci, d):
			return res
		res.pushed = true
	elif not _passable(n, d, false):
		return res
	var f0 := fish.size()
	var k0 := keys
	var u0 := unlocked.size()
	_enter(n)
	while tile(player) == "i":
		var nn := player + d
		if crate_at(nn) >= 0 or not _passable(nn, d, false):
			break
		_enter(nn)
		res.slid = true
	moves += 1  # note: gates use the move count *before* this move for the whole move
	var pad := tile(player)
	if pads.has(pad):
		for q in pads[pad]:
			if q != player and crate_at(q) < 0:
				_enter(q)
				res.tp = true
				break
	res.fish = f0 - fish.size()
	res.key = keys > k0
	res.door = unlocked.size() > u0
	res.ok = true
	if record:
		undo_stack.append(before)
	_update_state()
	res.won = won
	return res

## Spend a beat without moving (timed gates open and close with the move count).
func wait(record := true) -> Dictionary:
	if won:
		return {"ok": false}
	if record:
		undo_stack.append(_snap())
	moves += 1
	_update_state()
	return {"ok": true, "won": won}

func _push(i: int, d: Vector2i) -> bool:
	var c: Vector2i = crates[i]
	var nn := c + d
	if crate_at(nn) >= 0 or nn == player or not _passable(nn, d, true):
		return false
	c = nn
	while tile(c) == "i":
		var n2 := c + d
		if crate_at(n2) >= 0 or not _passable(n2, d, true):
			break
		c = n2
	crates[i] = c
	return true

func can_undo() -> bool:
	return undo_stack.size() > 0

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	_restore(undo_stack.pop_back())
	return true

## True when a crate sits in a wall corner on a tile that needs no crate (cannot ever be moved again).
func stuck_crates() -> Array:
	var out := []
	for i in crates.size():
		var c: Vector2i = crates[i]
		var t := tile(c)
		if t == "T" or t == "p":
			continue
		var hx := tile(c + Vector2i.LEFT) == "#" or tile(c + Vector2i.RIGHT) == "#"
		var hy := tile(c + Vector2i.UP) == "#" or tile(c + Vector2i.DOWN) == "#"
		if hx and hy:
			out.append(i)
	return out

func state_key(with_fish := false) -> String:
	var cs := crates.duplicate()
	cs.sort()
	var ks := floor_keys.keys()
	ks.sort()
	var us := unlocked.keys()
	us.sort()
	var s := "%s|%s|%d|%s|%s" % [player, cs, keys, ks, us]
	if has_gates:
		s += "|%d" % (moves % 2)
	if with_fish:
		var fs := fish.keys()
		fs.sort()
		s += "|%s" % [fs]
	return s
