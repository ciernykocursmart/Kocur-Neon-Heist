extends RefCounted
## Parses an ASCII level map into a tile grid + entity list and answers
## spatial queries. Pure data: used by the Level scene and the headless
## reachability validator (tests/level_reach.gd).
##
## Terrain:  # stone   I ice   % fake wall (secret, passable)   = one-way platform
##           ~ crumbling block   ^ spikes   v ceiling spikes   L lava/acid pool
##           D lever gate   ] boss gate (closes during the fight)
## Entities: P start  X exit door  K checkpoint  o coin  f fish  g gem  T chest
##           R caged cat  $ secret zone  s scout  G guard  A archer  W mage  B beast
##           H horizontal platform / V vertical platform (travel to the next ':')
##           l lever  F flame jet  O saw  Y icicle  J spring  t torch  ? sign
##           d decoration  1-5 boss  ! boss arena trigger  r rising hazard

const TILE := 16
const SOLID := "#I"
const ONEWAY := "="
const SPIKES := "^v"
const LAVA := "L"
const TERRAIN := "#I%=~^vLD]:"

var width := 0
var height := 0
var rows: Array[String] = []        ## Terrain only (entities replaced by spaces).
var entities: Array[Dictionary] = []  ## {"ch": String, "cell": Vector2i}
var gates_open := false
var boss_gates_closed := false
var start_cell := Vector2i(1, 1)


func parse(map_text: String) -> void:
	var lines := map_text.split("\n")
	# Drop a leading/trailing empty line caused by the multi-line string literal.
	while lines.size() > 0 and lines[0].strip_edges() == "":
		lines.remove_at(0)
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	height = lines.size()
	width = 0
	for l in lines:
		width = maxi(width, l.length())
	rows.clear()
	entities.clear()
	for y in height:
		var src: String = lines[y]
		var row := ""
		for x in width:
			var c := src[x] if x < src.length() else " "
			if c == "." or c == "\t":
				c = " "
			if TERRAIN.contains(c) or c == " ":
				row += c
			else:
				row += " "
				entities.append({"ch": c, "cell": Vector2i(x, y)})
				if c == "P":
					start_cell = Vector2i(x, y)
		rows.append(row)


func ch(x: int, y: int) -> String:
	if x < 0 or x >= width or y < 0:
		return "#"  # Sides and ceiling are closed.
	if y >= height:
		return " "  # Below the map is a pit.
	return rows[y][x]


func chv(c: Vector2i) -> String:
	return ch(c.x, c.y)


## Solid for physics purposes (crumble blocks count while intact).
func is_solid(x: int, y: int) -> bool:
	var c := ch(x, y)
	if SOLID.contains(c) or c == "~":
		return true
	if c == "D":
		return not gates_open
	if c == "]":
		return boss_gates_closed
	return false


func is_static_solid(x: int, y: int) -> bool:
	return SOLID.contains(ch(x, y))


func is_oneway(x: int, y: int) -> bool:
	return ch(x, y) == ONEWAY


func is_hazard(x: int, y: int) -> bool:
	var c := ch(x, y)
	return SPIKES.contains(c) or c == LAVA


func is_ice(x: int, y: int) -> bool:
	return ch(x, y) == "I"


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


## Position of the floor beneath an entity cell (bottom edge of that cell).
func cell_floor(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, (c.y + 1) * TILE)


func entities_of(chars: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entities:
		if chars.contains(e["ch"]):
			out.append(e)
	return out


## Greedy-merges cells matching `pred` into rectangles (in cells).
func merged_rects(pred: Callable) -> Array[Rect2i]:
	var used := {}
	var rects: Array[Rect2i] = []
	for y in height:
		var x := 0
		while x < width:
			if used.has(Vector2i(x, y)) or not pred.call(x, y):
				x += 1
				continue
			var x2 := x
			while x2 + 1 < width and pred.call(x2 + 1, y) and not used.has(Vector2i(x2 + 1, y)):
				x2 += 1
			var y2 := y
			var can_grow := true
			while can_grow and y2 + 1 < height:
				for xx in range(x, x2 + 1):
					if not pred.call(xx, y2 + 1) or used.has(Vector2i(xx, y2 + 1)):
						can_grow = false
						break
				if can_grow:
					y2 += 1
			for yy in range(y, y2 + 1):
				for xx in range(x, x2 + 1):
					used[Vector2i(xx, yy)] = true
			rects.append(Rect2i(x, y, x2 - x + 1, y2 - y + 1))
			x = x2 + 1
	return rects


## Connected components (4-neighbour) of cells whose character is in `chars`,
## looking at entities (for '$') or terrain.
func components(chars: String, from_entities := false) -> Array:
	var cells := {}
	if from_entities:
		for e in entities:
			if chars.contains(e["ch"]):
				cells[e["cell"]] = true
	else:
		for y in height:
			for x in width:
				if chars.contains(rows[y][x]):
					cells[Vector2i(x, y)] = true
	var seen := {}
	var out := []
	for c in cells:
		if seen.has(c):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		seen[c] = true
		while stack.size() > 0:
			var cur: Vector2i = stack.pop_back()
			comp.append(cur)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = cur + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		out.append(comp)
	return out


## Scan from `c` in direction `dir` for a ':' path marker; returns the number of
## cells travelled, or `fallback` if none found within 30 cells.
func path_length(c: Vector2i, dir: Vector2i, fallback := 4) -> int:
	for i in range(1, 31):
		var p := c + dir * i
		if p.x < 0 or p.x >= width or p.y < 0 or p.y >= height:
			break
		if rows[p.y][p.x] == ":":
			return i
	return fallback


func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)
