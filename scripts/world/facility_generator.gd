class_name FacilityGenerator
extends RefCounted
## Procedurally assembles a facility layout from RoomTemplates.
##
## Rooms sit on a cols x rows slot grid and share 1-tile walls. A randomised
## depth-first spanning tree guarantees every room is reachable; a few extra
## connections add loops for flanking/escape routes. Some doorways become
## hackable security doors (the data vault is always sealed).
##
## The result is a plain Dictionary consumed by Facility.build().

const STRIDE_X := RoomTemplates.W + 1
const STRIDE_Y := RoomTemplates.H + 1

enum Tile { FLOOR, WALL, CRATE, ZONE, SHADOW }

const MARKER_CHARS := "SEDKTAP"


static func generate(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = def.get("cols", 3)
	var rows: int = def.get("rows", 2)
	var width := cols * STRIDE_X + 1
	var height := rows * STRIDE_Y + 1
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	tiles.fill(Tile.WALL)

	# --- Room graph -------------------------------------------------------
	var spawn_slot := Vector2i(0, rng.randi_range(0, rows - 1))
	var edges := _spanning_tree(cols, rows, spawn_slot, rng)
	var extra := maxi(1, int(cols * rows / 4.0))
	for i in extra:
		var a := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		var b := a + ([Vector2i.RIGHT, Vector2i.DOWN][rng.randi() % 2] as Vector2i)
		if b.x < cols and b.y < rows and not _has_edge(edges, a, b):
			edges.append([a, b])

	var dist_from_spawn := _bfs(cols, rows, edges, spawn_slot)
	var data_slot := _farthest(dist_from_spawn, [spawn_slot])
	var dist_from_data := _bfs(cols, rows, edges, data_slot)
	# Final mission: the vault is two rooms merged into one big arena.
	var arena_partner := Vector2i(-1, -1)
	if bool(def.get("final", false)):
		for dx in [1, -1]:
			var n := data_slot + Vector2i(dx, 0)
			if n.x >= 0 and n.x < cols and n != spawn_slot:
				arena_partner = n
				break
	var extract_slot := _farthest(dist_from_data, [spawn_slot, data_slot, arena_partner])
	if extract_slot == Vector2i(-1, -1):
		extract_slot = spawn_slot

	# --- Rooms ------------------------------------------------------------
	var rooms := []
	var generic := RoomTemplates.generic()
	var data_templates := RoomTemplates.by_tag("data")
	var spawn_template: Dictionary = RoomTemplates.by_tag("spawn")[0]
	var arena_template: Dictionary = RoomTemplates.by_tag("arena")[0]
	var last_name := ""
	for y in rows:
		for x in cols:
			var slot := Vector2i(x, y)
			var template: Dictionary
			if slot == spawn_slot:
				template = spawn_template
			elif arena_partner != Vector2i(-1, -1) and (slot == data_slot or slot == arena_partner):
				template = arena_template
			elif slot == data_slot:
				template = data_templates[rng.randi() % data_templates.size()]
			else:
				template = generic[rng.randi() % generic.size()]
				if template["name"] == last_name:
					template = generic[rng.randi() % generic.size()]
			last_name = template["name"]
			var origin := Vector2i(x * STRIDE_X + 1, y * STRIDE_Y + 1)
			var room := {
				"slot": slot,
				"origin": origin,
				"rect": Rect2i(origin, Vector2i(RoomTemplates.W, RoomTemplates.H)),
				"name": template["name"],
				"accent": (x + y * 2) % 4,
				"markers": {},
			}
			_stamp(tiles, width, template["rows"], origin, room["markers"])
			rooms.append(room)

	# Knock down the shared wall between the two arena rooms.
	var arena_rooms := []
	if arena_partner != Vector2i(-1, -1):
		arena_rooms = [_room_index(data_slot, cols), _room_index(arena_partner, cols)]
		var wall_x := maxi(data_slot.x, arena_partner.x) * STRIDE_X
		for ty in RoomTemplates.H:
			tiles[(data_slot.y * STRIDE_Y + 1 + ty) * width + wall_x] = Tile.FLOOR
		var merged := [data_slot, arena_partner]
		var kept := []
		for e in edges:
			if e[0] in merged and e[1] in merged:
				continue
			kept.append(e)
		edges = kept

	# --- Doors ------------------------------------------------------------
	var doors := []
	var locked_ratio: float = def.get("locked_ratio", 0.25)
	for e in edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var cells: Array[Vector2i] = []
		var horizontal := a.x == b.x  # vertical neighbours => door lies along a horizontal wall
		var lo := a if (a.x < b.x or a.y < b.y) else b
		if horizontal:
			var wall_y := (lo.y + 1) * STRIDE_Y
			for i in 3:
				cells.append(Vector2i(lo.x * STRIDE_X + 1 + 6 + i, wall_y))
			# keep 2 tiles on both sides clear
			for i in 3:
				for d in [-2, -1, 1, 2]:
					_clear(tiles, width, Vector2i(lo.x * STRIDE_X + 7 + i, wall_y + d))
		else:
			var wall_x := (lo.x + 1) * STRIDE_X
			for i in 3:
				cells.append(Vector2i(wall_x, lo.y * STRIDE_Y + 1 + 4 + i))
			for i in 3:
				for d in [-2, -1, 1, 2]:
					_clear(tiles, width, Vector2i(wall_x + d, lo.y * STRIDE_Y + 5 + i))
		for c in cells:
			tiles[c.y * width + c.x] = Tile.FLOOR
		var touches_data := a == data_slot or b == data_slot or a == arena_partner or b == arena_partner
		var touches_spawn := a == spawn_slot or b == spawn_slot
		var locked := touches_data or (not touches_spawn and rng.randf() < locked_ratio)
		doors.append({
			"cells": cells,
			"horizontal": horizontal,
			"locked": locked,
			"rooms": [_room_index(a, cols), _room_index(b, cols)],
		})

	return {
		"width": width,
		"height": height,
		"cols": cols,
		"rows": rows,
		"tiles": tiles,
		"rooms": rooms,
		"doors": doors,
		"spawn_room": _room_index(spawn_slot, cols),
		"data_room": _room_index(data_slot, cols),
		"extract_room": _room_index(extract_slot, cols),
		"arena_rooms": arena_rooms,
		"theme": int(def.get("theme", 0)),
	}


static func _room_index(slot: Vector2i, cols: int) -> int:
	return slot.y * cols + slot.x


static func _stamp(tiles: PackedByteArray, width: int, rows: Array, origin: Vector2i, markers: Dictionary) -> void:
	for ty in RoomTemplates.H:
		var line: String = rows[ty]
		for tx in RoomTemplates.W:
			var ch := line[tx]
			var cell := origin + Vector2i(tx, ty)
			var t := Tile.FLOOR
			match ch:
				"#":
					t = Tile.WALL
				"c":
					t = Tile.CRATE
				"Z":
					t = Tile.ZONE
				"h":
					t = Tile.SHADOW
			if MARKER_CHARS.contains(ch):
				if not markers.has(ch):
					markers[ch] = []
				markers[ch].append(cell)
			tiles[cell.y * width + cell.x] = t


static func _clear(tiles: PackedByteArray, width: int, c: Vector2i) -> void:
	var i := c.y * width + c.x
	if i < 0 or i >= tiles.size():
		return
	if tiles[i] == Tile.WALL or tiles[i] == Tile.CRATE:
		# Only clear inside rooms, never the outer/shared walls themselves.
		if c.x % STRIDE_X != 0 and c.y % STRIDE_Y != 0:
			tiles[i] = Tile.FLOOR


static func _spanning_tree(cols: int, rows: int, start: Vector2i, rng: RandomNumberGenerator) -> Array:
	var edges := []
	var visited := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt := options[rng.randi() % options.size()]
		visited[nxt] = true
		edges.append([cur, nxt])
		stack.append(nxt)
	return edges


static func _has_edge(edges: Array, a: Vector2i, b: Vector2i) -> bool:
	for e in edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false


static func _bfs(cols: int, rows: int, edges: Array, start: Vector2i) -> Dictionary:
	var adj := {}
	for e in edges:
		if not adj.has(e[0]):
			adj[e[0]] = []
		if not adj.has(e[1]):
			adj[e[1]] = []
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for n in adj.get(cur, []):
			if not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist


static func _farthest(dist: Dictionary, exclude: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	for slot in dist.keys():
		if slot in exclude:
			continue
		if int(dist[slot]) > best_d:
			best_d = int(dist[slot])
			best = slot
	return best
