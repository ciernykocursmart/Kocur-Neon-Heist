extends Node2D
## Draws the six stage environments: sky, two parallax layers, the back wall
## of the street (world space) and the floor. Everything is generated from
## the theme name with deterministic variation, with a few animated details
## (neon flicker, steam, bunting, torches). Decoration stays behind the
## fighting plane so it never reads as a character or hides an attack.

const FLOOR_TOP := 440.0
const WALL_TOP := 205.0

var theme := "alley"
var length := 4000.0
var cam_x := 640.0
var t := 0.0
var font: Font
var exit_open := false
var exit_x := 0.0

const PAL := {
	"alley": {"sky0": Color("2a1840"), "sky1": Color("e8784a"), "far": Color("3a2450"), "mid": Color("4a2a4a"),
		"wall": Color("7a3a32"), "wall2": Color("6a3028"), "trim": Color("3a1e24"), "floor": Color("4a4048"),
		"floor2": Color("554a52"), "walk": Color("6a5e64"), "light": Color("ffb45a")},
	"market": {"sky0": Color("5ab0ff"), "sky1": Color("bfe6ff"), "far": Color("8ab8d8"), "mid": Color("d89a6a"),
		"wall": Color("e8c890"), "wall2": Color("d8b47a"), "trim": Color("8a5a3a"), "floor": Color("c8a878"),
		"floor2": Color("b8986a"), "walk": Color("d8c0a0"), "light": Color("fff4c0")},
	"neon": {"sky0": Color("0a0820"), "sky1": Color("2a1450"), "far": Color("1a1438"), "mid": Color("221a44"),
		"wall": Color("2a2448"), "wall2": Color("221e3c"), "trim": Color("120e24"), "floor": Color("1e1c30"),
		"floor2": Color("262440"), "walk": Color("34304e"), "light": Color("ff4fd8")},
	"industrial": {"sky0": Color("3a3440"), "sky1": Color("c8784a"), "far": Color("4a4450"), "mid": Color("5a5258"),
		"wall": Color("6a7078"), "wall2": Color("5a6068"), "trim": Color("3a3e44"), "floor": Color("5a5858"),
		"floor2": Color("666262"), "walk": Color("7a7672"), "light": Color("ffc23a")},
	"hq": {"sky0": Color("10101c"), "sky1": Color("3a2238"), "far": Color("1e1a2a"), "mid": Color("2a2236"),
		"wall": Color("d8d4cc"), "wall2": Color("bcb6ac"), "trim": Color("6a1e2a"), "floor": Color("3a3444"),
		"floor2": Color("e8e2d8"), "walk": Color("8a1e2e"), "light": Color("ffd23a")},
	"pantry": {"sky0": Color("3a1e10"), "sky1": Color("8a4a1a"), "far": Color("5a3418"), "mid": Color("7a4a20"),
		"wall": Color("8a2a2a"), "wall2": Color("7a2222"), "trim": Color("e8b030"), "floor": Color("5a2a1a"),
		"floor2": Color("b02a2a"), "walk": Color("e8b030"), "light": Color("ffe08a")},
}


func setup(th: String, len_px: float) -> void:
	theme = th
	length = len_px
	z_index = -10
	font = ThemeDB.fallback_font


static func h(i: int, salt := 0) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var pal: Dictionary = PAL.get(theme, PAL["alley"])
	var left := cam_x - 640.0
	# Sky gradient (screen-locked).
	var sky := PackedVector2Array([Vector2(left, 0), Vector2(left + 1280, 0), Vector2(left + 1280, FLOOR_TOP), Vector2(left, FLOOR_TOP)])
	draw_polygon(sky, PackedColorArray([pal["sky0"], pal["sky0"], pal["sky1"], pal["sky1"]]))
	_sky_details(pal, left)
	_layer(pal["far"], 0.15, 160.0, 90.0, 220.0, 1, left)
	_layer(pal["mid"], 0.45, 120.0, 140.0, 300.0, 2, left)
	_back_wall(pal, left)
	_floor(pal, left)
	if exit_open:
		_exit_sign()


func _sky_details(pal: Dictionary, left: float) -> void:
	match theme:
		"neon", "hq":
			for i in 40:
				var x := left + fposmod(h(i, 3) * 2600.0 - cam_x * 0.05, 1300.0) - 10.0
				var y := h(i, 4) * 220.0
				var a := 0.4 + 0.4 * sin(t * 2.0 + i)
				draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, a))
			draw_circle(Vector2(left + 1040 - fposmod(cam_x * 0.02, 50.0), 80), 34, Color("f4f0d8"))
			draw_circle(Vector2(left + 1052 - fposmod(cam_x * 0.02, 50.0), 72), 30, pal["sky0"])
		"alley", "industrial":
			draw_circle(Vector2(left + 900 - cam_x * 0.03, 250), 70, Color(1.0, 0.75, 0.4, 0.55))
		"market":
			draw_circle(Vector2(left + 1080, 70), 40, Color("fff4a0"))
			for i in 4:
				var cx := left + fposmod(h(i, 5) * 1600.0 - cam_x * 0.08 + t * 6.0, 1500.0) - 100.0
				var cy := 50.0 + h(i, 6) * 80.0
				for j in 3:
					draw_circle(Vector2(cx + j * 26, cy - (10 if j == 1 else 0)), 24, Color(1, 1, 1, 0.85))
		"pantry":
			for i in 7:
				var x2 := left + fposmod(i * 220.0 - cam_x * 0.1, 1540.0) - 130.0
				draw_line(Vector2(x2, 0), Vector2(x2, 60), Color("e8b030"), 2.0)
				draw_circle(Vector2(x2, 70), 16, Color(1, 0.85, 0.4, 0.35 + 0.1 * sin(t * 3.0 + i)))
				draw_circle(Vector2(x2, 70), 8, Color("ffe08a"))


## Parallax silhouette layer of buildings.
func _layer(col: Color, f: float, min_w: float, min_h: float, max_h: float, salt: int, left: float) -> void:
	var off := cam_x * f
	var start_i := int(floor((left - (cam_x - off) - 400.0) / 140.0))
	for i in range(start_i, start_i + 14):
		var bw := min_w + h(i, salt) * 120.0
		var x := i * 140.0 + (cam_x - off)
		var bh := min_h + h(i, salt + 10) * (max_h - min_h)
		var top := FLOOR_TOP - 40.0 - bh
		if theme == "pantry":
			# piles of stolen food in the distance
			draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_TOP), Vector2(x + bw * 0.5, top + 40), Vector2(x + bw, FLOOR_TOP)]), col)
			continue
		draw_rect(Rect2(x, top, bw, FLOOR_TOP - top), col)
		if salt == 2:
			var lit := col.lightened(0.35) if theme != "neon" else Color(1.0, 0.85, 0.4, 0.8)
			for wy in range(int(top) + 14, int(FLOOR_TOP) - 60, 28):
				for wx in range(int(x) + 10, int(x + bw) - 14, 24):
					if h(wx * 7 + wy, salt) > 0.55:
						draw_rect(Rect2(wx, wy, 10, 12), lit if theme in ["neon", "hq"] else col.darkened(0.2))
		if theme == "industrial" and salt == 1 and i % 3 == 0:
			draw_rect(Rect2(x + bw * 0.4, top - 80, 18, 80), col)
			var puff := fposmod(t * 20.0 + i * 13.0, 60.0)
			draw_circle(Vector2(x + bw * 0.4 + 9, top - 90 - puff), 10.0 + puff * 0.3, Color(0.8, 0.8, 0.85, 0.35 * (1.0 - puff / 60.0)))


func _back_wall(pal: Dictionary, left: float) -> void:
	var seg := 320.0
	var i0 := int(floor(left / seg)) - 1
	for i in range(i0, i0 + 6):
		var x := i * seg
		if x > length + 200 or x + seg < -200:
			continue
		var wall: Color = pal["wall"] if i % 2 == 0 else pal["wall2"]
		var top := WALL_TOP + h(i, 21) * 70.0
		if theme == "market":
			top = FLOOR_TOP - 150.0
		draw_rect(Rect2(x, top, seg, FLOOR_TOP - top), wall)
		draw_rect(Rect2(x, top, seg, 10), pal["trim"])
		match theme:
			"alley": _alley_seg(i, x, top, seg, pal)
			"market": _market_seg(i, x, top, seg, pal)
			"neon": _neon_seg(i, x, top, seg, pal)
			"industrial": _industrial_seg(i, x, top, seg, pal)
			"hq": _hq_seg(i, x, top, seg, pal)
			"pantry": _pantry_seg(i, x, top, seg, pal)


func _alley_seg(i: int, x: float, top: float, seg: float, pal: Dictionary) -> void:
	# Bricks.
	for by in range(int(top) + 16, int(FLOOR_TOP), 16):
		var odd := (by / 16) % 2
		for bx in range(int(x) + (odd * 16), int(x + seg), 32):
			draw_line(Vector2(bx, by), Vector2(bx, by + 16), (pal["wall"] as Color).darkened(0.25), 1.0)
		draw_line(Vector2(x, by), Vector2(x + seg, by), (pal["wall"] as Color).darkened(0.25), 1.0)
	# Windows with warm light, fire escape.
	for k in 2:
		var wx := x + 50 + k * 150
		draw_rect(Rect2(wx, top + 50, 60, 70), Color("2a1830"))
		if h(i * 3 + k, 22) > 0.4:
			draw_rect(Rect2(wx + 4, top + 54, 52, 62), Color(1.0, 0.75, 0.4, 0.8))
		draw_line(Vector2(wx + 30, top + 50), Vector2(wx + 30, top + 120), Color("2a1830"), 3.0)
	draw_rect(Rect2(x + 30, top + 140, 240, 6), Color("2a2230"))
	for k in 9:
		draw_line(Vector2(x + 30 + k * 30, top + 140), Vector2(x + 30 + k * 30, top + 168), Color("2a2230"), 2.0)
	# Laundry line, swaying.
	if i % 2 == 1:
		var y0 := top + 30.0
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(Vector2(x + k * 40, y0 + sin(k / 8.0 * PI) * 22.0))
		draw_polyline(pts, Color("e8e0d0"), 1.5)
		for k in 4:
			var p := pts[k * 2 + 1]
			var sway := sin(t * 2.0 + k) * 3.0
			draw_rect(Rect2(p.x - 10 + sway, p.y, 20, 26), [Color("e8413c"), Color("5ab0ff"), Color("ffd23a"), Color("8adf3a")][k])
	# Graffiti tag.
	if i % 3 == 0:
		draw_string_outline(font, Vector2(x + 110, FLOOR_TOP - 70), "KOCUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color("1a1020"))
		draw_string(font, Vector2(x + 110, FLOOR_TOP - 70), "KOCUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("5ad8ff"))
	# Door and dumpster.
	if i % 2 == 0:
		draw_rect(Rect2(x + 220, FLOOR_TOP - 100, 56, 100), Color("3a2028"))
		draw_circle(Vector2(x + 268, FLOOR_TOP - 50), 3, Color("ffd23a"))
		draw_circle(Vector2(x + 248, FLOOR_TOP - 112), 6, pal["light"])
	else:
		draw_rect(Rect2(x + 180, FLOOR_TOP - 56, 110, 56), Color("2a6a4a"))
		draw_rect(Rect2(x + 176, FLOOR_TOP - 62, 118, 8), Color("1e4a34"))


func _market_seg(i: int, x: float, top: float, seg: float, _pal: Dictionary) -> void:
	# Shop front with sign and awning; bunting across the top.
	var cols := [Color("e8413c"), Color("2f9a5a"), Color("4a6fd8"), Color("ff8a2a"), Color("c23a9a")]
	var c: Color = cols[i % cols.size()] if i >= 0 else cols[0]
	draw_rect(Rect2(x + 20, top + 40, seg - 40, FLOOR_TOP - top - 40), Color("5a3a28"))
	draw_rect(Rect2(x + 30, top + 60, seg - 60, 50), Color("f4e6c0"))
	for k in 6:
		draw_circle(Vector2(x + 50 + k * 40, top + 85), 12, [Color("ff7a2a"), Color("8adf3a"), Color("ff3a5a"), Color("ffd23a")][(k + i) % 4])
	for k in 8:
		var ax := x + 20 + k * (seg - 40) / 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(ax, top + 20), Vector2(ax + (seg - 40) / 8.0, top + 20), Vector2(ax + (seg - 40) / 8.0, top + 44), Vector2(ax + (seg - 40) / 16.0, top + 52), Vector2(ax, top + 44)]), c if k % 2 == 0 else Color("f4f0e6"))
	var signs := ["FISH", "MILK", "TUNA", "CHEESE", "SNACKS", "YARN"]
	var s: String = signs[posmod(i, signs.size())]
	draw_rect(Rect2(x + seg * 0.5 - 60, top - 16, 120, 30), Color("2a2235"))
	draw_string(font, Vector2(x + seg * 0.5 - 56, top + 7), s, HORIZONTAL_ALIGNMENT_CENTER, 112, 20, Color("ffd23a"))
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(Vector2(x + k * 40, top - 40 + sin(k / 8.0 * PI) * 16.0))
	draw_polyline(pts, Color("5a3a28"), 1.5)
	for k in 8:
		var p := pts[k]
		var w := sin(t * 3.0 + k + i) * 3.0
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(20, 0), p + Vector2(10 + w, 18)]), cols[(k + i + 10) % cols.size()])


func _neon_seg(i: int, x: float, top: float, seg: float, _pal: Dictionary) -> void:
	for k in 3:
		for r in 3:
			var wx := x + 30 + k * 95
			var wy := top + 40 + r * 70
			draw_rect(Rect2(wx, wy, 60, 46), Color("15122a"))
			if h(i * 9 + k * 3 + r, 30) > 0.5:
				draw_rect(Rect2(wx + 3, wy + 3, 54, 40), Color(0.35, 0.3, 0.7, 0.6))
	var signs := [["MEOW", Color("ff4fd8")], ["24/7", Color("5ad8ff")], ["NEKO BAR", Color("ffd23a")], ["SUSHI", Color("8aff7a")], ["CLAW CLUB", Color("ff5a5a")]]
	var sg: Array = signs[posmod(i, signs.size())]
	var flick := 1.0 if fmod(t * (1.3 + h(i, 31)), 3.0) > 0.12 else 0.25
	var col: Color = sg[1]
	var sx := x + 40.0
	var sy := FLOOR_TOP - 130.0
	var w := font.get_string_size(String(sg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_rect(Rect2(sx - 10, sy - 34, w + 20, 46), Color("0e0c1c"))
	draw_rect(Rect2(sx - 10, sy - 34, w + 20, 46), Color(col.r, col.g, col.b, 0.8 * flick), false, 3.0)
	draw_string_outline(font, Vector2(sx, sy), String(sg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 10, Color(col.r, col.g, col.b, 0.25 * flick))
	draw_string(font, Vector2(sx, sy), String(sg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(col.r, col.g, col.b, flick).lightened(0.3))
	# Shop window glow on the pavement.
	draw_rect(Rect2(x + 200, FLOOR_TOP - 80, 90, 80), Color(col.r, col.g, col.b, 0.25))
	draw_rect(Rect2(x + 200, FLOOR_TOP - 80, 90, 80), Color(col.r, col.g, col.b, 0.7), false, 2.0)
	# Street lamp.
	if i % 2 == 0:
		draw_line(Vector2(x + 300, FLOOR_TOP), Vector2(x + 300, FLOOR_TOP - 200), Color("3a3650"), 5.0)
		draw_line(Vector2(x + 300, FLOOR_TOP - 200), Vector2(x + 270, FLOOR_TOP - 200), Color("3a3650"), 5.0)
		draw_circle(Vector2(x + 268, FLOOR_TOP - 194), 8, Color("fff0b0"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 262, FLOOR_TOP - 190), Vector2(x + 274, FLOOR_TOP - 190), Vector2(x + 320, FLOOR_TOP + 10), Vector2(x + 216, FLOOR_TOP + 10)]), Color(1, 0.95, 0.7, 0.06))


func _industrial_seg(i: int, x: float, top: float, seg: float, pal: Dictionary) -> void:
	# Corrugated metal, pipes, hazard stripes, a big door.
	for k in range(0, int(seg), 12):
		draw_line(Vector2(x + k, top + 10), Vector2(x + k, FLOOR_TOP), (pal["wall"] as Color).darkened(0.15), 2.0)
	draw_rect(Rect2(x, top + 70, seg, 12), Color("8a5a3a"))
	draw_rect(Rect2(x, top + 100, seg, 8), Color("5a6a7a"))
	for k in 3:
		draw_circle(Vector2(x + 40 + k * 110, top + 76), 9, Color("6a4a30"))
	if i % 2 == 0:
		draw_rect(Rect2(x + 60, FLOOR_TOP - 170, 200, 170), Color("3a3e44"))
		for k in 10:
			draw_line(Vector2(x + 60, FLOOR_TOP - 170 + k * 17), Vector2(x + 260, FLOOR_TOP - 170 + k * 17), Color("2a2e34"), 2.0)
		for k in 10:
			var sx := x + 60 + k * 20
			draw_colored_polygon(PackedVector2Array([Vector2(sx, FLOOR_TOP - 186), Vector2(sx + 10, FLOOR_TOP - 186), Vector2(sx + 20, FLOOR_TOP - 172), Vector2(sx + 10, FLOOR_TOP - 172)]), Color("2a2235"))
		draw_rect(Rect2(x + 60, FLOOR_TOP - 186, 200, 14), Color(1.0, 0.8, 0.2, 0.0))
		draw_rect(Rect2(x + 60, FLOOR_TOP - 186, 200, 14), Color("ffc21a"), false, 2.0)
	else:
		draw_string(font, Vector2(x + 40, top + 160), "YARD " + str(posmod(i, 9) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("ffc21a"))
		var blink := 1.0 if fmod(t + i, 1.2) < 0.6 else 0.3
		draw_circle(Vector2(x + 260, top + 140), 9, Color(1, 0.4, 0.2, blink))
	var puff := fposmod(t * 30.0 + i * 20.0, 70.0)
	draw_circle(Vector2(x + 300, FLOOR_TOP - 60 - puff), 8.0 + puff * 0.35, Color(0.9, 0.9, 0.95, 0.3 * (1.0 - puff / 70.0)))


func _hq_seg(i: int, x: float, top: float, seg: float, pal: Dictionary) -> void:
	# Stone blocks, columns, White Crown banners, torches.
	for by in range(int(top) + 30, int(FLOOR_TOP), 30):
		draw_line(Vector2(x, by), Vector2(x + seg, by), (pal["wall"] as Color).darkened(0.12), 2.0)
	draw_rect(Rect2(x, top, 30, FLOOR_TOP - top), (pal["wall"] as Color).darkened(0.2))
	var bx := x + 110.0
	draw_rect(Rect2(bx, top + 30, 100, 190), Color("8a1e2e"))
	draw_colored_polygon(PackedVector2Array([Vector2(bx, top + 220), Vector2(bx + 50, top + 250), Vector2(bx + 100, top + 220)]), Color("8a1e2e"))
	CatPainter._crown(self, Vector2(bx + 50, top + 130), 60.0, Color("f4f0e6"), Color("2a2235"))
	for k in [0, 1]:
		var tx: float = x + 60 + k * 200
		draw_rect(Rect2(tx - 3, top + 120, 6, 30), Color("4a3a30"))
		var fl := 1.0 + 0.2 * sin(t * 12.0 + k + i)
		draw_circle(Vector2(tx, top + 112), 9.0 * fl, Color(1.0, 0.5, 0.1, 0.8))
		draw_circle(Vector2(tx, top + 114), 5.0 * fl, Color(1.0, 0.9, 0.3))
		draw_circle(Vector2(tx, top + 112), 30.0 * fl, Color(1.0, 0.7, 0.3, 0.08))
	if i % 3 == 1:
		draw_rect(Rect2(x + 230, FLOOR_TOP - 120, 70, 120), Color("2a1a20"))
		draw_arc(Vector2(x + 265, FLOOR_TOP - 120), 35, PI, TAU, 12, Color("2a1a20"), 4.0)


func _pantry_seg(i: int, x: float, top: float, seg: float, _pal: Dictionary) -> void:
	# Velvet wall, golden frames, shelves stuffed with stolen food.
	draw_rect(Rect2(x, top + 20, seg, 6), Color("e8b030"))
	for k in 3:
		var sy := top + 90 + k * 85
		draw_rect(Rect2(x + 20, sy, seg - 40, 10), Color("6a3a18"))
		for n in 6:
			var ix := x + 40 + n * 46
			var kinds := ["can", "fish", "chicken", "can", "yarn", "fish"]
			PickupArt.draw_item(self, kinds[(n + k + i) % kinds.size()], Vector2(ix, sy), 0.9, t)
	if i % 3 == 0:
		# Portrait of the boss.
		draw_rect(Rect2(x + 110, top + 30, 110, 50).grow(4), Color("e8b030"))
		draw_rect(Rect2(x + 110, top + 30, 110, 50), Color("2a1a20"))
		draw_string(font, Vector2(x + 114, top + 62), "LARDPAW", HORIZONTAL_ALIGNMENT_CENTER, 102, 18, Color("f4f0e6"))


func _floor(pal: Dictionary, left: float) -> void:
	var fl: Color = pal["floor"]
	draw_rect(Rect2(left, FLOOR_TOP, 1280, 720 - FLOOR_TOP), fl)
	# Sidewalk strip along the wall and a curb.
	draw_rect(Rect2(left, FLOOR_TOP, 1280, 22), pal["walk"])
	draw_rect(Rect2(left, FLOOR_TOP + 22, 1280, 4), (pal["walk"] as Color).darkened(0.3))
	match theme:
		"alley":
			for y in range(int(FLOOR_TOP) + 40, 720, 22):
				var off := (y / 22 % 2) * 20.0
				for x in range(int(floor(left / 40.0) * 40.0 - 40), int(left + 1320), 40):
					draw_line(Vector2(x + off, y), Vector2(x + off, y + 22), pal["floor2"], 2.0)
				draw_line(Vector2(left, y), Vector2(left + 1280, y), pal["floor2"], 2.0)
		"market":
			for x in range(int(floor(left / 64.0) * 64.0 - 64), int(left + 1344), 64):
				for y in range(int(FLOOR_TOP) + 26, 720, 32):
					if (x / 64 + y / 32) % 2 == 0:
						draw_rect(Rect2(x, y, 64, 32), pal["floor2"])
		"neon":
			for x in range(int(floor(left / 160.0) * 160.0 - 160), int(left + 1440), 160):
				draw_rect(Rect2(x, 566, 80, 8), Color("e8e0a0"))
			for x in range(int(floor(left / 320.0) * 320.0 - 320), int(left + 1600), 320):
				var c := Color(1.0, 0.3, 0.85, 0.08) if (x / 320) % 2 == 0 else Color(0.3, 0.85, 1.0, 0.08)
				draw_rect(Rect2(x + 40, FLOOR_TOP + 30, 90, 240), c)
		"industrial":
			for x in range(int(floor(left / 200.0) * 200.0 - 200), int(left + 1400), 200):
				draw_line(Vector2(x, FLOOR_TOP + 26), Vector2(x - 60, 720), pal["floor2"], 3.0)
			draw_rect(Rect2(left, 690, 1280, 10), Color("ffc21a"))
			for x in range(int(floor(left / 40.0) * 40.0 - 40), int(left + 1320), 40):
				draw_colored_polygon(PackedVector2Array([Vector2(x, 690), Vector2(x + 20, 690), Vector2(x + 10, 700), Vector2(x - 10, 700)]), Color("2a2235"))
		"hq":
			for x in range(int(floor(left / 60.0) * 60.0 - 60), int(left + 1340), 60):
				for y in range(int(FLOOR_TOP) + 26, 720, 40):
					if (x / 60 + y / 40) % 2 == 0:
						draw_rect(Rect2(x, y, 60, 40), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(left, 530, 1280, 80), Color(0.55, 0.1, 0.15, 0.55))
		"pantry":
			draw_rect(Rect2(left, 500, 1280, 150), pal["floor2"])
			draw_rect(Rect2(left, 500, 1280, 6), pal["walk"])
			draw_rect(Rect2(left, 644, 1280, 6), pal["walk"])
	# Front curb.
	draw_rect(Rect2(left, 702, 1280, 18), (pal["walk"] as Color).darkened(0.2))


func _exit_sign() -> void:
	var x := exit_x
	var bob := sin(t * 6.0) * 8.0
	draw_colored_polygon(PackedVector2Array([Vector2(x - 40 + bob, 300), Vector2(x + 10 + bob, 300), Vector2(x + 10 + bob, 280), Vector2(x + 50 + bob, 320), Vector2(x + 10 + bob, 360), Vector2(x + 10 + bob, 340), Vector2(x - 40 + bob, 340)]), Color("ffd23a"))
	draw_string_outline(font, Vector2(x - 60, 260), "NEXT STREET", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color("2a2235"))
	draw_string(font, Vector2(x - 60, 260), "NEXT STREET", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffd23a"))
