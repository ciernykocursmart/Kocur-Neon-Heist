extends RefCounted
## Physics-based reachability analysis for level maps.
##
## Simulates the player's real movement model (same constants as
## scripts/player/player.gd) from every standing spot: walking, walking off
## ledges, dropping through one-way platforms, jumps with different hold
## lengths/directions/delays, springs and (optionally) pounces. Trajectories
## that touch spikes/lava are discarded. The result tells which standing
## spots and which cells are reachable, so tests can assert that the exit,
## checkpoints and every collectible can be reached and that no reachable
## spot is a dead end.

const P := preload("res://scripts/player/movement.gd")
const LevelGrid := preload("res://scripts/world/level_grid.gd")
const DT := 1.0 / 60.0
const HW := 4.5
const HH := 14.0
const POUNCE_FRAMES := 12
const POUNCE_SPEED := P.POUNCE_SPEED

var g: RefCounted
var allow_pounce := false
var gates_open := false
var w := 0
var h := 0
var _solid := PackedByteArray()
var _oneway := PackedByteArray()
var _hazard := PackedByteArray()
var _spring := {}
var nodes := {}         ## Vector2i -> true (standing cells)
var edges := {}         ## Vector2i -> Array[Vector2i]
var touched := {}       ## Vector2i -> true (cells the body passed through safely)
var sims := 0


func setup(map_text: String) -> void:
	g = LevelGrid.new()
	g.parse(map_text)
	w = g.width
	h = g.height
	_spring.clear()
	for e in g.entities_of("J"):
		_spring[e["cell"]] = true
	_build_tables()


func _build_tables() -> void:
	_solid.resize(w * h)
	_oneway.resize(w * h)
	_hazard.resize(w * h)
	for y in h:
		for x in w:
			var c: String = g.ch(x, y)
			var i := y * w + x
			_solid[i] = 1 if (c == "#" or c == "I" or c == "~" or (c == "D" and not gates_open)) else 0
			_oneway[i] = 1 if c == "=" else 0
			_hazard[i] = 1 if (c == "^" or c == "v" or c == "L") else 0
	# Moving platforms become one-way cells along their whole path.
	for e in g.entities_of("HV"):
		var cell: Vector2i = e["cell"]
		if e["ch"] == "H":
			var n: int = g.path_length(cell, Vector2i.RIGHT, 4)
			for x in range(cell.x - 1, cell.x + n + 2):
				_set_oneway(x, cell.y)
		else:
			var n2: int = g.path_length(cell, Vector2i.UP, 4)
			for k in range(0, n2 + 1):
				for x in range(cell.x - 1, cell.x + 2):
					_set_oneway(x, cell.y - k)


func _set_oneway(x: int, y: int) -> void:
	if x >= 0 and x < w and y >= 0 and y < h and _solid[y * w + x] == 0:
		_oneway[y * w + x] = 1


func solid(x: int, y: int) -> bool:
	if x < 0 or x >= w or y < 0:
		return true
	if y >= h:
		return false
	return _solid[y * w + x] == 1


func oneway(x: int, y: int) -> bool:
	if x < 0 or x >= w or y < 0 or y >= h:
		return false
	return _oneway[y * w + x] == 1


func hazard_hit(x0: float, y0: float, x1: float, y1: float) -> bool:
	var cx0 := floori(x0 / 16.0)
	var cx1 := floori((x1 - 0.01) / 16.0)
	var cy0 := floori(y0 / 16.0)
	var cy1 := floori((y1 - 0.01) / 16.0)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if cx < 0 or cx >= w or cy < 0 or cy >= h:
				continue
			if _hazard[cy * w + cx] == 1:
				var c: String = g.ch(cx, cy)
				var top := cy * 16.0 + (9.0 if c == "^" else (0.0 if c == "v" else 6.0))
				var bot := cy * 16.0 + (7.0 if c == "v" else 16.0)
				var hx0 := cx * 16.0 + (2.0 if c != "L" else 0.0)
				var hx1 := cx * 16.0 + (14.0 if c != "L" else 16.0)
				if x1 > hx0 and x0 < hx1 and y1 > top and y0 < bot:
					return true
	return false


func box_solid(x0: float, y0: float, x1: float, y1: float) -> bool:
	var cx0 := floori(x0 / 16.0)
	var cx1 := floori((x1 - 0.01) / 16.0)
	var cy0 := floori(y0 / 16.0)
	var cy1 := floori((y1 - 0.01) / 16.0)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if solid(cx, cy):
				return true
	return false


## Simulates one airborne trajectory. Returns the landing cell or (-1,-1).
func simulate(fx: float, fy: float, vx: float, vy: float, dir: float, hold: int, delay: int, pounce_at := -1,
		pounce_dir := Vector2.ZERO) -> Vector2i:
	sims += 1
	var x := fx
	var y := fy
	var seen: Array[Vector2i] = []
	var pounce_left := 0
	for frame in 200:
		if frame == pounce_at:
			pounce_left = POUNCE_FRAMES
		if pounce_left > 0:
			vx = pounce_dir.x * POUNCE_SPEED
			vy = pounce_dir.y * POUNCE_SPEED
			pounce_left -= 1
			if pounce_left == 0:
				vx *= 0.55
				vy = minf(vy * 0.4, 0.0)
		else:
			var d := dir if frame >= delay else 0.0
			var acc := P.AIR_ACCEL if absf(d) > 0.0 else P.AIR_DECEL
			vx = move_toward(vx, d * P.RUN_SPEED, acc * DT)
			var held := frame < hold
			var grav := P.GRAVITY_DOWN
			if vy < 0.0:
				grav = P.GRAVITY_UP if held else P.GRAVITY_CUT
				if held and absf(vy) < P.APEX_THRESHOLD:
					grav *= P.APEX_GRAVITY_MULT
			elif held and vy < P.APEX_THRESHOLD:
				grav *= P.APEX_GRAVITY_MULT
			vy = minf(vy + grav * DT, P.MAX_FALL)
		# Horizontal move
		var nx := x + vx * DT
		if box_solid(nx - HW, y - HH, nx + HW, y - 0.01):
			if vx > 0:
				nx = floorf((nx + HW) / 16.0) * 16.0 - HW - 0.01
			else:
				nx = ceilf((nx - HW) / 16.0) * 16.0 + HW + 0.01
			if box_solid(nx - HW, y - HH, nx + HW, y - 0.01):
				nx = x
			vx = 0.0
		x = nx
		# Vertical move
		var ny := y + vy * DT
		if vy > 0.0:
			var landed := false
			var cx0 := floori((x - HW) / 16.0)
			var cx1 := floori((x + HW - 0.01) / 16.0)
			for row in range(ceili((y - 0.5) / 16.0), floori(ny / 16.0) + 1):
				var top := row * 16.0
				if top < y - 0.5 or top > ny:
					continue
				for cx in range(cx0, cx1 + 1):
					if solid(cx, row) or oneway(cx, row):
						landed = true
				if landed:
					ny = top
					break
			if landed:
				y = ny
				if hazard_hit(x - HW, y - HH, x + HW, y):
					return Vector2i(-1, -1)
				_touch(seen, x, y)
				for c in seen:
					touched[c] = true
				return Vector2i(floori(x / 16.0), floori((y - 1.0) / 16.0))
		elif vy < 0.0:
			if box_solid(x - HW, ny - HH, x + HW, ny - 0.01):
				ny = ceilf((ny - HH) / 16.0) * 16.0 + HH + 0.01
				vy = 0.0
		y = ny
		if hazard_hit(x - HW, y - HH, x + HW, y):
			return Vector2i(-1, -1)
		_touch(seen, x, y)
		if y > h * 16.0 + 32.0:
			return Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _touch(seen: Array[Vector2i], x: float, y: float) -> void:
	for yy: float in [y - HH + 1.0, y - 7.0, y - 1.0]:
		for xx: float in [x - HW + 0.5, x + HW - 0.5]:
			var c := Vector2i(floori(xx / 16.0), floori(yy / 16.0))
			if not seen.has(c):
				seen.append(c)


func is_stand(c: Vector2i) -> bool:
	return not solid(c.x, c.y) and (solid(c.x, c.y + 1) or oneway(c.x, c.y + 1)) and c.y + 1 < h


func _add_edge(a: Vector2i, b: Vector2i) -> void:
	if b.x < 0:
		return
	if not is_stand(b):
		# Landed on a ledge edge: snap to a neighbouring standable cell.
		for dx: int in [0, -1, 1]:
			var bb := Vector2i(b.x + dx, b.y)
			if is_stand(bb):
				b = bb
				break
		if not is_stand(b):
			return
	if not edges.has(a):
		edges[a] = []
	if not edges[a].has(b):
		edges[a].append(b)


## Breadth-first search over standing spots from the level start.
func explore() -> void:
	nodes.clear()
	edges.clear()
	touched.clear()
	var start: Vector2i = g.start_cell
	# Fall from the start marker to the ground.
	var land := simulate(start.x * 16.0 + 8.0, start.y * 16.0 + 15.0, 0.0, 0.0, 0.0, 0, 0)
	if land.x < 0:
		land = start
	var queue: Array[Vector2i] = [land]
	nodes[land] = true
	while queue.size() > 0:
		var n: Vector2i = queue.pop_front()
		for nb in _successors(n):
			if not nodes.has(nb):
				nodes[nb] = true
				queue.append(nb)
	for n in nodes:
		touched[n] = true


func _successors(n: Vector2i) -> Array[Vector2i]:
	var fx := n.x * 16.0 + 8.0
	var fy := (n.y + 1) * 16.0
	var before: Array = edges.get(n, []).duplicate()
	if _spring.has(n):
		for d: float in [-1.0, 0.0, 1.0]:
			for delay: int in [0, 15]:
				_add_edge(n, simulate(fx, fy, d * P.RUN_SPEED * 0.6 if delay == 0 else 0.0, -P.SPRING_VELOCITY, d, 200, delay))
	else:
		for d: int in [-1, 1]:
			var side := Vector2i(n.x + d, n.y)
			if not solid(side.x, side.y):
				if is_stand(side):
					_add_edge(n, side)
				else:
					_add_edge(n, simulate(fx, fy - 0.01, d * P.RUN_SPEED, 0.0, float(d), 0, 0))
					_add_edge(n, simulate(fx, fy - 0.01, d * P.RUN_SPEED * 0.3, 0.0, 0.0, 0, 0))
		if oneway(n.x, n.y + 1) and not solid(n.x, n.y + 1):
			_add_edge(n, simulate(fx, fy + 3.0, 0.0, 30.0, 0.0, 0, 0))
		var jv := -P.JUMP_VELOCITY
		_add_edge(n, simulate(fx, fy, 0.0, jv, 0.0, 200, 0))
		for d: float in [-1.0, 1.0]:
			for hold: int in [200, 9, 4]:
				for delay: int in [0, 14]:
					var vx0 := d * P.RUN_SPEED * 0.8 if delay == 0 else 0.0
					_add_edge(n, simulate(fx, fy, vx0, jv, d, hold, delay))
			_add_edge(n, simulate(fx, fy, d * P.RUN_SPEED * 0.8, jv, -d, 200, 10))
			if allow_pounce:
				for pa: int in [8, 18, 26]:
					_add_edge(n, simulate(fx, fy, d * P.RUN_SPEED * 0.8, jv, d, 200, 0, pa, Vector2(d, 0)))
					_add_edge(n, simulate(fx, fy, d * P.RUN_SPEED * 0.6, jv, d, 200, 0, pa,
						Vector2(d * 0.8, -0.6).normalized()))
				_add_edge(n, simulate(fx, fy - 1.0, 0.0, 0.0, d, 0, 0, 0, Vector2(d * 0.8, -0.6).normalized()))
	var out: Array[Vector2i] = []
	for b in edges.get(n, []):
		if not before.has(b):
			out.append(b)
	return out


## Runs the full analysis, opening lever gates once a lever is reachable.
func analyze(pounce: bool) -> void:
	allow_pounce = pounce
	gates_open = false
	_build_tables()
	explore()
	var levers: Array = g.entities_of("l")
	if levers.size() > 0:
		for lv in levers:
			if can_interact(lv["cell"]):
				gates_open = true
		if gates_open:
			_build_tables()
			explore()


func can_interact(c: Vector2i) -> bool:
	for dx: int in [-1, 0, 1]:
		if nodes.has(Vector2i(c.x + dx, c.y)):
			return true
	return false


func can_touch(c: Vector2i) -> bool:
	return touched.has(c) or nodes.has(c)


## Standing spots from which the goal set cannot be reached (soft locks).
func dead_ends(goals: Array[Vector2i]) -> Array[Vector2i]:
	var rev := {}
	for a in edges:
		for b in edges[a]:
			if not rev.has(b):
				rev[b] = []
			rev[b].append(a)
	var ok := {}
	var queue: Array[Vector2i] = []
	for gc in goals:
		ok[gc] = true
		queue.append(gc)
	while queue.size() > 0:
		var n: Vector2i = queue.pop_front()
		for p in rev.get(n, []):
			if not ok.has(p):
				ok[p] = true
				queue.append(p)
	var bad: Array[Vector2i] = []
	for n in nodes:
		if not ok.has(n):
			bad.append(n)
	return bad


func goal_nodes(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx: int in [-1, 0, 1]:
		var n := Vector2i(c.x + dx, c.y)
		if nodes.has(n):
			out.append(n)
	return out
