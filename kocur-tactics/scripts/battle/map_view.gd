extends Node2D
## Draws the battlefield: terrain tiles, objective markers, and every tactical
## overlay (movement, targets, path, threat, telegraphed attacks). Each overlay
## uses a distinct pattern as well as a colour, so it reads without colour.

const UI = preload("res://scripts/ui/ui_kit.gd")
const TILE := 48

var battle: RefCounted
var region := "wood"
var move_cells: Array[Vector2i] = []
var target_cells: Array[Vector2i] = []
var range_cells: Array[Vector2i] = []
var area_cells: Array[Vector2i] = []
var path: Array[Vector2i] = []
var threat := {}
var inspect_threat := {}
var pending := Vector2i(-1, -1)
var landing := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * TILE, c.y * TILE, TILE, TILE)


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2, c.y * TILE + TILE / 2)


func tile_tex(c: Vector2i) -> Texture2D:
	var t: String = battle.grid.terrain(c)
	var name := t
	if t == "grass":
		name = "grass2" if (c.x * 7 + c.y * 13) % 5 == 0 else "grass"
	return UI.tex("tile_%s_%s" % [region, name])


func _draw() -> void:
	if battle == null:
		return
	var g: RefCounted = battle.grid
	# terrain
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			var tx := tile_tex(c)
			if tx:
				draw_texture_rect(tx, cell_rect(c), false)
	# subtle grid lines
	for x in g.w + 1:
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, g.h * TILE), Color(0, 0, 0, 0.18), 1.0)
	for y in g.h + 1:
		draw_line(Vector2(0, y * TILE), Vector2(g.w * TILE, y * TILE), Color(0, 0, 0, 0.18), 1.0)
	# objective markers
	for c: Vector2i in battle.exits:
		_tex_at("mark_exit", c, 0.85)
	for c: Vector2i in battle.defend_cells:
		_tex_at("mark_defend", c, 0.9)
	for c: Vector2i in battle.relics:
		_tex_at("mark_relic_taken" if battle.claimed.has(c) else "mark_relic", c, 1.0)
	if battle.treasure_cell.x >= 0 and not battle.treasure_taken:
		_tex_at("mark_treasure", c_or(battle.treasure_cell), 1.0)
	if battle.is_player_turn():
		for c: Vector2i in battle.incoming_cells():
			_tex_at("mark_incoming", c, 0.6 + 0.4 * sin(_t * 5.0))
	# threat overlay: red diagonal hatch
	for c: Vector2i in threat:
		_hatch(c, Color(1.0, 0.25, 0.3, 0.45), 8)
	for c: Vector2i in inspect_threat:
		draw_rect(cell_rect(c).grow(-3), Color(1.0, 0.35, 0.4, 0.75), false, 2.0)
		_hatch(c, Color(1.0, 0.3, 0.35, 0.3), 12)
	# ability range (faint)
	for c: Vector2i in range_cells:
		draw_rect(cell_rect(c).grow(-1), Color(1.0, 0.75, 0.3, 0.12))
	# movement: blue fill + corner dots
	for c: Vector2i in move_cells:
		var r := cell_rect(c)
		draw_rect(r.grow(-1), Color(0.3, 0.6, 1.0, 0.33))
		draw_rect(r.grow(-2), Color(0.55, 0.8, 1.0, 0.6), false, 1.0)
		draw_circle(r.get_center(), 3.0, Color(0.8, 0.92, 1.0, 0.8))
	# path
	if path.size() > 1:
		for i in range(1, path.size()):
			draw_line(cell_center(path[i - 1]), cell_center(path[i]), Color(1, 1, 1, 0.85), 4.0)
		draw_circle(cell_center(path[path.size() - 1]), 7.0, Color(1, 1, 1, 0.9))
	# attack targets: red fill + crosshair corners
	for c: Vector2i in target_cells:
		var r := cell_rect(c)
		draw_rect(r.grow(-1), Color(1.0, 0.25, 0.3, 0.3))
		_corners(r.grow(-3), Color(1.0, 0.4, 0.4, 1.0), 10.0)
	for c: Vector2i in area_cells:
		draw_rect(cell_rect(c).grow(-2), Color(1.0, 0.8, 0.2, 0.35))
		_corners(cell_rect(c).grow(-4), Color(1.0, 0.85, 0.3, 0.9), 7.0)
	# telegraphed boss attacks: orange hatch + warning icon
	for tg: Dictionary in battle.telegraphs:
		var col := Color(1.0, 0.55, 0.1, 0.55) if tg["kind"] != "summon" else Color(0.75, 0.5, 1.0, 0.55)
		for c: Vector2i in tg["cells"]:
			draw_rect(cell_rect(c).grow(-1), Color(col.r, col.g, col.b, 0.22 + 0.12 * sin(_t * 6.0)))
			_hatch(c, col, 6)
			draw_rect(cell_rect(c).grow(-1), col, false, 2.0)
			var wi := UI.tex("icon_warn")
			if wi:
				draw_texture_rect(wi, Rect2(c.x * TILE + 2, c.y * TILE + 2, 16, 16), false)
	if landing.x >= 0:
		draw_rect(cell_rect(landing).grow(-4), Color(0.75, 0.5, 1.0, 0.9), false, 3.0)
	if pending.x >= 0:
		var a := 0.6 + 0.4 * sin(_t * 8.0)
		draw_rect(cell_rect(pending).grow(-1), Color(1.0, 0.85, 0.2, a), false, 4.0)
	if hover.x >= 0 and g.in_bounds(hover):
		draw_rect(cell_rect(hover).grow(-1), Color(1, 1, 1, 0.55), false, 2.0)


func c_or(c: Vector2i) -> Vector2i:
	return c


func _tex_at(name: String, c: Vector2i, alpha: float) -> void:
	var t := UI.tex(name)
	if t:
		draw_texture_rect(t, cell_rect(c), false, Color(1, 1, 1, alpha))


func _corners(r: Rect2, col: Color, l: float) -> void:
	var p := r.position
	var e := r.end
	draw_line(p, p + Vector2(l, 0), col, 3.0)
	draw_line(p, p + Vector2(0, l), col, 3.0)
	draw_line(Vector2(e.x, p.y), Vector2(e.x - l, p.y), col, 3.0)
	draw_line(Vector2(e.x, p.y), Vector2(e.x, p.y + l), col, 3.0)
	draw_line(Vector2(p.x, e.y), Vector2(p.x + l, e.y), col, 3.0)
	draw_line(Vector2(p.x, e.y), Vector2(p.x, e.y - l), col, 3.0)
	draw_line(e, e - Vector2(l, 0), col, 3.0)
	draw_line(e, e - Vector2(0, l), col, 3.0)


func _hatch(c: Vector2i, col: Color, step: int) -> void:
	var o := Vector2(c.x * TILE, c.y * TILE)
	var i := 0
	while i < TILE * 2:
		var a := Vector2(i, 0)
		var b := Vector2(0, i)
		# clip the diagonal to the tile square
		if a.x > TILE:
			a = Vector2(TILE, a.x - TILE)
		if b.y > TILE:
			b = Vector2(b.y - TILE, TILE)
		draw_line(o + a, o + b, col, 1.5)
		i += step
