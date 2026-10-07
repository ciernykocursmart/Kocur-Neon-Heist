class_name Facility
extends Node2D
## Runtime representation of a generated facility: tile grid, collision,
## A* navigation, line-of-sight queries, security-zone state and all static
## rendering (floor, neon walls, crates, zone hatching, ambient light pools).

const TILE := 32
const T := FacilityGenerator.Tile
const WORLD_MASK := 1

var layout: Dictionary
var width := 0
var height := 0
var tiles := PackedByteArray()
var rooms: Array = []
var astar := AStarGrid2D.new()
var zones_active := true
var accents: Array = Palette.ROOM_ACCENTS
var floor_color := Palette.FLOOR
var shadow_cells: Array[Vector2i] = []
var zone_cells: Array[Vector2i] = []

var _room_of_cell := PackedInt32Array()
var _time := 0.0
var _zone_fx: Node2D


func build(data: Dictionary) -> void:
	layout = data
	width = data["width"]
	height = data["height"]
	tiles = data["tiles"]
	rooms = data["rooms"]
	z_index = -10
	var theme: Dictionary = Campaign.THEMES[clampi(int(data.get("theme", 0)), 0, Campaign.THEMES.size() - 1)]
	accents = theme["accents"]
	floor_color = theme["floor"]

	_room_of_cell.resize(width * height)
	_room_of_cell.fill(-1)
	for i in rooms.size():
		var r: Rect2i = rooms[i]["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_room_of_cell[y * width + x] = i
	for y in height:
		for x in width:
			if tiles[y * width + x] == T.ZONE:
				zone_cells.append(Vector2i(x, y))
			elif tiles[y * width + x] == T.SHADOW:
				shadow_cells.append(Vector2i(x, y))

	_build_navigation()
	_build_collision()
	_build_lights()
	_zone_fx = Node2D.new()
	_zone_fx.z_index = 1
	add_child(_zone_fx)
	_zone_fx.draw.connect(_draw_zone_fx)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not zone_cells.is_empty():
		_zone_fx.queue_redraw()


# --------------------------------------------------------------------------
# Grid helpers
# --------------------------------------------------------------------------

func get_tile(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return T.WALL
	return tiles[c.y * width + c.x]


func is_solid_tile(c: Vector2i) -> bool:
	var t := get_tile(c)
	return t == T.WALL or t == T.CRATE


func is_walkable(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


func room_at(p: Vector2) -> int:
	var c := cell_of(p)
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return -1
	return _room_of_cell[c.y * width + c.x]


func room_center(index: int) -> Vector2:
	var r: Rect2i = rooms[index]["rect"]
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * TILE


func room_markers(index: int, ch: String) -> Array:
	return rooms[index]["markers"].get(ch, [])


func is_in_zone(p: Vector2) -> bool:
	return get_tile(cell_of(p)) == T.ZONE


func is_shadow(p: Vector2) -> bool:
	return get_tile(cell_of(p)) == T.SHADOW


func world_size() -> Vector2:
	return Vector2(width, height) * TILE


## Random walkable cell inside a room, optionally at least `min_dist` px from `avoid`.
func random_floor_cell(room_index: int, rng: RandomNumberGenerator, avoid := Vector2.INF, min_dist := 0.0) -> Vector2i:
	var r: Rect2i = rooms[room_index]["rect"]
	for attempt in 60:
		var c := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), rng.randi_range(r.position.y + 1, r.end.y - 2))
		if not is_walkable(c):
			continue
		if avoid != Vector2.INF and cell_center(c).distance_to(avoid) < min_dist:
			continue
		return c
	return cell_of(room_center(room_index))


func nearest_walkable(c: Vector2i) -> Vector2i:
	if is_walkable(c):
		return c
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n := c + Vector2i(dx, dy)
				if is_walkable(n):
					return n
	return c


# --------------------------------------------------------------------------
# Navigation / perception
# --------------------------------------------------------------------------

func _build_navigation() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE, TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in height:
		for x in width:
			if is_solid_tile(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)


func set_cells_blocked(cells: Array, blocked: bool) -> void:
	for c in cells:
		astar.set_point_solid(c, blocked)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_walkable(cell_of(from))
	var b := nearest_walkable(cell_of(to))
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return PackedVector2Array()
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b, true)


func has_path(from: Vector2, to: Vector2) -> bool:
	var a := nearest_walkable(cell_of(from))
	var b := nearest_walkable(cell_of(to))
	if not is_walkable(a) or not is_walkable(b):
		return false
	var path := astar.get_id_path(a, b)
	return not path.is_empty()


func has_los(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, WORLD_MASK)
	return space.intersect_ray(q).is_empty()


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = WORLD_MASK
	body.collision_mask = 0
	add_child(body)
	for y in height:
		var x := 0
		while x < width:
			if is_solid_tile(Vector2i(x, y)):
				var start := x
				var kind := get_tile(Vector2i(x, y))
				while x < width and get_tile(Vector2i(x, y)) == kind:
					x += 1
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - start) * TILE, TILE)
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2((start + (x - start) * 0.5) * TILE, (y + 0.5) * TILE)
				body.add_child(cs)
			else:
				x += 1


func _build_lights() -> void:
	for i in rooms.size():
		var accent: Color = accents[rooms[i]["accent"]]
		var light := FX.make_light(accent, 300.0, 0.16)
		light.position = room_center(i)
		light.z_index = 2
		add_child(light)


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, world_size())
	draw_rect(full.grow(TILE * 8), Palette.BG)

	# Floors, tinted per room.
	for i in rooms.size():
		var r: Rect2i = rooms[i]["rect"]
		var accent: Color = accents[rooms[i]["accent"]]
		var floor_col := floor_color.lerp(accent, 0.035)
		draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), floor_col)
	# Doorway floors.
	for d in layout["doors"]:
		for c in d["cells"]:
			draw_rect(Rect2(Vector2(c) * TILE, Vector2(TILE, TILE)), floor_color)

	# Grid lines.
	for x in range(0, width + 1):
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, height * TILE), Palette.GRID, 1.0)
	for y in range(0, height + 1):
		draw_line(Vector2(0, y * TILE), Vector2(width * TILE, y * TILE), Palette.GRID, 1.0)

	# Floor decals: subtle hex markings at room centres.
	for i in rooms.size():
		var accent: Color = accents[rooms[i]["accent"]]
		var c := room_center(i)
		draw_arc(c, 54.0, 0.0, TAU, 6, Palette.with_alpha(accent, 0.12), 2.0, true)
		draw_arc(c, 70.0, 0.0, TAU, 6, Palette.with_alpha(accent, 0.06), 1.0, true)

	# Shadows: dark pools with a faint violet rim.
	for c in shadow_cells:
		var sp := Vector2(c) * TILE
		draw_rect(Rect2(sp, Vector2(TILE, TILE)), Color(0.0, 0.0, 0.02, 0.62))
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if get_tile(c + d) != T.SHADOW and not is_solid_tile(c + d):
				var mid := sp + Vector2(TILE, TILE) * 0.5 + Vector2(d) * TILE * 0.5
				var along := Vector2(d).orthogonal() * TILE * 0.5
				draw_line(mid - along, mid + along, Color(0.5, 0.3, 1.0, 0.18), 1.0)

	# Security zones: red hatching.
	for c in zone_cells:
		var p := Vector2(c) * TILE
		draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.5, 0.05, 0.12, 0.22))
		draw_line(p + Vector2(0, TILE), p + Vector2(TILE, 0), Color(1, 0.2, 0.3, 0.18), 2.0)

	# Walls & crates.
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var t := get_tile(c)
			if t == T.WALL:
				_draw_wall(c)
			elif t == T.CRATE:
				_draw_crate(c)


func _draw_wall(c: Vector2i) -> void:
	var p := Vector2(c) * TILE
	var rect := Rect2(p, Vector2(TILE, TILE))
	draw_rect(rect, Palette.WALL)
	var room := _neighbour_room(c)
	var accent: Color = Palette.CYAN if room < 0 else accents[rooms[room]["accent"]]
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var exposed := false
	for d in dirs:
		var n: Vector2i = c + d
		if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
			continue
		if is_solid_tile(n):
			continue
		exposed = true
		var a: Vector2
		var b: Vector2
		match d:
			Vector2i.LEFT:
				a = p
				b = p + Vector2(0, TILE)
			Vector2i.RIGHT:
				a = p + Vector2(TILE, 0)
				b = p + Vector2(TILE, TILE)
			Vector2i.UP:
				a = p
				b = p + Vector2(TILE, 0)
			_:
				a = p + Vector2(0, TILE)
				b = p + Vector2(TILE, TILE)
		draw_line(a, b, Palette.with_alpha(accent, 0.18), 7.0)
		draw_line(a, b, Palette.with_alpha(accent, 0.9), 2.0)
	if exposed:
		draw_rect(rect.grow(-6), Palette.WALL_TOP)


func _draw_crate(c: Vector2i) -> void:
	var p := Vector2(c) * TILE
	var rect := Rect2(p + Vector2(2, 2), Vector2(TILE - 4, TILE - 4))
	draw_rect(rect, Palette.CRATE)
	draw_rect(rect, Palette.with_alpha(Palette.ORANGE, 0.75), false, 1.5)
	draw_line(rect.position + Vector2(4, 4), rect.end - Vector2(4, 4), Palette.with_alpha(Palette.ORANGE, 0.3), 1.0)
	draw_line(Vector2(rect.end.x - 4, rect.position.y + 4), Vector2(rect.position.x + 4, rect.end.y - 4), Palette.with_alpha(Palette.ORANGE, 0.3), 1.0)


func _neighbour_room(c: Vector2i) -> int:
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height:
			var r := _room_of_cell[n.y * width + n.x]
			if r >= 0:
				return r
	return -1


func _draw_zone_fx() -> void:
	if zone_cells.is_empty():
		return
	if not zones_active:
		for c in zone_cells:
			_zone_fx.draw_rect(Rect2(Vector2(c) * TILE + Vector2(12, 12), Vector2(8, 8)), Color(0.3, 1.0, 0.6, 0.12))
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	for c in zone_cells:
		var p := Vector2(c) * TILE
		var phase := fmod(_time * 0.8 + (c.x + c.y) * 0.07, 1.0)
		var y := p.y + phase * TILE
		_zone_fx.draw_line(Vector2(p.x, y), Vector2(p.x + TILE, y), Color(1, 0.2, 0.35, 0.35 + 0.25 * pulse), 1.5)
		_zone_fx.draw_circle(p + Vector2(TILE, TILE) * 0.5, 1.5, Color(1, 0.3, 0.4, 0.4 * pulse))


func build_minimap_image() -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var t := get_tile(Vector2i(x, y))
			var col := Color(0, 0, 0, 0)
			match t:
				T.WALL:
					col = Color(0.35, 0.5, 0.9, 0.85) if _touches_floor(Vector2i(x, y)) else Color(0, 0, 0, 0)
				T.CRATE:
					col = Color(0.5, 0.35, 0.2, 0.7)
				T.ZONE:
					col = Color(0.6, 0.1, 0.2, 0.6)
				T.SHADOW:
					col = Color(0.04, 0.03, 0.09, 0.8)
				_:
					col = Color(0.08, 0.09, 0.18, 0.75)
			img.set_pixel(x, y, col)
	return img


func _touches_floor(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height and not is_solid_tile(n):
				return true
	return false
