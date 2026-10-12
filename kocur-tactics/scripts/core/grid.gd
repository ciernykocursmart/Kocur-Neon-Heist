extends RefCounted
## Battlefield grid: terrain, bounds, line of sight and pathfinding.
## Pure logic - no nodes - so it can be tested and used by the AI directly.

const INF := 1 << 20
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Terrain table. cost: movement points to enter (0 = impassable).
const TERRAIN := {
	"grass": {"name": "Grass", "cost": 1, "def": 0, "los": true, "desc": "Open ground."},
	"road": {"name": "Road", "cost": 1, "def": 0, "los": true, "desc": "Open ground."},
	"forest": {"name": "Forest", "cost": 2, "def": 1, "los": true, "desc": "Cover: +1 DEF. Costs 2 movement."},
	"wall": {"name": "Wall", "cost": 0, "def": 0, "los": false, "desc": "Impassable. Blocks line of sight."},
	"pillar": {"name": "Pillar", "cost": 0, "def": 0, "los": false, "desc": "Impassable. Blocks line of sight."},
	"water": {"name": "Water", "cost": 0, "def": 0, "los": true, "desc": "Impassable, but you can shoot (and pounce) across it."},
	"bridge": {"name": "Bridge", "cost": 1, "def": 0, "los": true, "desc": "Open ground over water."},
	"hill": {"name": "Hill", "cost": 2, "def": 0, "los": true, "range": 1, "desc": "High ground: ranged attacks from here get +1 range. Costs 2 movement."},
	"mud": {"name": "Mud", "cost": 2, "def": 0, "los": true, "desc": "Difficult ground. Costs 2 movement."},
	"hazard": {"name": "Thorns", "cost": 1, "def": 0, "los": true, "hazard": 3,
		"desc": "Danger! A unit standing here when its side's turn starts takes 3 damage."},
	"cage": {"name": "Cage", "cost": 0, "def": 0, "los": true, "desc": "A captive cat! Stand next to it and use Free."},
}

const CHAR_TERRAIN := {
	".": "grass", ",": "road", "T": "forest", "#": "wall", "H": "pillar", "~": "water", "=": "bridge",
	"^": "hill", "%": "mud", "x": "hazard", "C": "cage",
}

var w := 0
var h := 0
var cells: Array[String] = []  ## terrain id per cell, row-major


func setup(width: int, height: int) -> void:
	w = width
	h = height
	cells.resize(w * h)
	cells.fill("grass")


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func terrain(c: Vector2i) -> String:
	if not in_bounds(c):
		return "wall"
	return cells[idx(c)]


func set_terrain(c: Vector2i, t: String) -> void:
	if in_bounds(c):
		cells[idx(c)] = t


func info(c: Vector2i) -> Dictionary:
	return TERRAIN[terrain(c)]


func move_cost(c: Vector2i) -> int:
	return int(info(c)["cost"])


func walkable(c: Vector2i) -> bool:
	return in_bounds(c) and move_cost(c) > 0


func defense(c: Vector2i) -> int:
	return int(info(c)["def"])


func blocks_los(c: Vector2i) -> bool:
	return not bool(info(c)["los"])


func range_bonus(c: Vector2i) -> int:
	return int(info(c).get("range", 0))


func hazard_damage(c: Vector2i) -> int:
	return int(info(c).get("hazard", 0))


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Cells strictly between a and b that a sight line passes through.
## Uses a supercover walk between cell centres; when the line passes exactly
## through a corner, BOTH side cells are included, and the view is blocked
## only if both of them block (you can peek past a single corner).
func los_cells(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var dx := b.x - a.x
	var dy := b.y - a.y
	var nx := absi(dx)
	var ny := absi(dy)
	var sx := 1 if dx > 0 else -1
	var sy := 1 if dy > 0 else -1
	var p := a
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var lhs := (1 + 2 * ix) * ny
		var rhs := (1 + 2 * iy) * nx
		if lhs == rhs:
			# exact corner: record both neighbours as a pair
			out.append([Vector2i(p.x + sx, p.y), Vector2i(p.x, p.y + sy)])
			p = Vector2i(p.x + sx, p.y + sy)
			ix += 1
			iy += 1
		elif lhs < rhs:
			p = Vector2i(p.x + sx, p.y)
			ix += 1
		else:
			p = Vector2i(p.x, p.y + sy)
			iy += 1
		if p != b:
			out.append(p)
	return out


func has_los(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	for entry: Variant in los_cells(a, b):
		if entry is Array:
			if blocks_los(entry[0]) and blocks_los(entry[1]):
				return false
		elif blocks_los(entry):
			return false
	return true


## Dijkstra flood from start. passable(cell) -> bool decides if a cell can be
## entered at all (terrain + enemy units); cost(cell) -> int is the price.
## Returns {"cost": {cell: int}, "prev": {cell: cell}}.
func flood(start: Vector2i, max_cost: int, passable: Callable, cost_fn: Callable) -> Dictionary:
	var best := {start: 0}
	var prev := {}
	var frontier: Array = [[0, start]]
	while not frontier.is_empty():
		# pop lowest cost (small grids: linear scan is fine and deterministic)
		var bi := 0
		for i in range(1, frontier.size()):
			var fa: Array = frontier[i]
			var fb: Array = frontier[bi]
			if fa[0] < fb[0] or (fa[0] == fb[0] and _cell_less(fa[1], fb[1])):
				bi = i
		var cur: Array = frontier[bi]
		frontier.remove_at(bi)
		var cc: int = cur[0]
		var cell: Vector2i = cur[1]
		if cc > int(best.get(cell, INF)):
			continue
		for d: Vector2i in DIRS:
			var n := cell + d
			if not in_bounds(n) or not passable.call(n):
				continue
			var nc: int = cc + int(cost_fn.call(n))
			if nc > max_cost:
				continue
			if nc < int(best.get(n, INF)):
				best[n] = nc
				prev[n] = cell
				frontier.append([nc, n])
	return {"cost": best, "prev": prev}


static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func path_from(prev: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if goal == start:
		return [start]
	if not prev.has(goal):
		return out
	var c := goal
	out.append(c)
	while c != start:
		c = prev[c]
		out.push_front(c)
	return out


## A* shortest path (by movement cost) ignoring any move budget.
func astar(start: Vector2i, goal: Vector2i, passable: Callable, cost_fn: Callable) -> Array[Vector2i]:
	var g := {start: 0}
	var prev := {}
	var open: Array = [[dist(start, goal), 0, start]]
	var closed := {}
	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			var oa: Array = open[i]
			var ob: Array = open[bi]
			if oa[0] < ob[0] or (oa[0] == ob[0] and oa[1] > ob[1]):
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var cell: Vector2i = cur[2]
		if cell == goal:
			return path_from(prev, start, goal)
		if closed.has(cell):
			continue
		closed[cell] = true
		for d: Vector2i in DIRS:
			var n := cell + d
			if not in_bounds(n) or closed.has(n):
				continue
			if n != goal and not passable.call(n):
				continue
			if n == goal and not passable.call(n):
				continue
			var ng: int = int(g[cell]) + int(cost_fn.call(n))
			if ng < int(g.get(n, INF)):
				g[n] = ng
				prev[n] = cell
				open.append([ng + dist(n, goal), ng, n])
	var empty: Array[Vector2i] = []
	return empty
