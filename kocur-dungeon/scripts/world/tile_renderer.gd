extends Node2D
## Draws the static terrain of a level from its LevelGrid using the region's
## generated tile atlas. Drawing happens once (cached by the canvas item).

const T := 16

var grid: RefCounted
var atlas: Texture2D
var region := 1
var _hash_seed := 0


func setup(g: RefCounted, region_index: int) -> void:
	grid = g
	region = region_index
	atlas = load("res://assets/sprites/tiles_r%d.png" % region_index)
	_hash_seed = region_index * 7919
	queue_redraw()


func _h(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ _hash_seed) % 1000


func _solidish(x: int, y: int) -> bool:
	var c: String = grid.ch(x, y)
	return c == "#" or c == "%" or c == "D" or c == "]"


func _iceish(x: int, y: int) -> bool:
	var c: String = grid.ch(x, y)
	return c == "I" or c == "#" or c == "%"


func _cell(col: int, row: int) -> Rect2:
	return Rect2(col * T, row * T, T, T)


func _draw() -> void:
	if grid == null or atlas == null:
		return
	var w: int = grid.width
	var h: int = grid.height
	# Background wall near terrain, fading out into open caverns.
	for y in h:
		for x in w:
			var c: String = grid.ch(x, y)
			if c == "#" or c == "I" or c == "%":
				continue
			var near := 9
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if _solidish(x + dx, y + dy) or grid.ch(x + dx, y + dy) == "I":
						near = mini(near, maxi(absi(dx), absi(dy)))
			if near > 2 and region != 5:
				continue
			var a := 1.0 if near <= 1 else 0.6
			if near > 2:
				a = 0.35
			var v := _h(x, y) % 10
			var col := 0 if v < 6 else (1 if v < 8 else (2 if v == 8 else 3))
			draw_texture_rect_region(atlas, Rect2(x * T, y * T, T, T), _cell(col, 2), Color(1, 1, 1, a))
	# Terrain
	for y in h:
		for x in w:
			var c: String = grid.ch(x, y)
			var dst := Rect2(x * T, y * T, T, T)
			match c:
				"#", "%":
					var mask := 0
					if not _solidish(x, y - 1) and grid.ch(x, y - 1) != "I":
						mask |= 1
					if not _solidish(x + 1, y) and grid.ch(x + 1, y) != "I":
						mask |= 2
					if not _solidish(x, y + 1) and grid.ch(x, y + 1) != "I":
						mask |= 4
					if not _solidish(x - 1, y) and grid.ch(x - 1, y) != "I":
						mask |= 8
					var row := 0 if _h(x, y) % 3 else 1
					draw_texture_rect_region(atlas, dst, _cell(mask, row))
				"I":
					var m2 := 0
					if not _iceish(x, y - 1):
						m2 |= 1
					if not _iceish(x + 1, y):
						m2 |= 2
					if not _iceish(x, y + 1):
						m2 |= 4
					if not _iceish(x - 1, y):
						m2 |= 8
					draw_texture_rect_region(atlas, dst, _cell(m2, 3))
				"=":
					var l: bool = grid.ch(x - 1, y) != "="
					var r: bool = grid.ch(x + 1, y) != "="
					var col := 7
					if l and not r:
						col = 6
					elif r and not l:
						col = 8
					draw_texture_rect_region(atlas, dst, _cell(col, 2))
				"^":
					draw_texture_rect_region(atlas, dst, _cell(11, 2))
				"v":
					draw_texture_rect_region(atlas, dst, _cell(12, 2))
				"L":
					var top: bool = grid.ch(x, y - 1) != "L"
					draw_texture_rect_region(atlas, dst, _cell(13 if top else 14, 2))
	# Decorations
	for e in grid.entities_of("d"):
		var cell: Vector2i = e["cell"]
		var choice := 0
		var hv := _h(cell.x, cell.y)
		if grid.is_solid(cell.x, cell.y - 1):
			choice = [0, 1, 3][hv % 3]
		elif grid.is_solid(cell.x, cell.y + 1) or grid.is_oneway(cell.x, cell.y + 1):
			choice = [2, 4, 5, 6][hv % 4]
		else:
			choice = [7, 3][hv % 2]
		draw_texture_rect_region(atlas, Rect2(cell.x * T, cell.y * T, T, T), _cell(choice, 4))
