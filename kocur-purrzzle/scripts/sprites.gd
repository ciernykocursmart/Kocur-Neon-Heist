class_name Sprites
extends RefCounted
## All pixel art is generated in code (16x16 tiles, drawn scaled with nearest filtering).

const THEMES := [
	{"floor": [Color("78c957"), Color("6dbd4e")], "wall": [Color("2f7a3e"), Color("246230"), Color("4aa05a")], "bg": Color("b8e6a0"), "spark": Color("fff6a8")},
	{"floor": [Color("8d94ad"), Color("828aa3")], "wall": [Color("464a66"), Color("353852"), Color("6a6f92")], "bg": Color("1c1f38"), "spark": Color("ffe9a0")},
	{"floor": [Color("d4ecf7"), Color("c6e3f2")], "wall": [Color("6fa8cf"), Color("5589b3"), Color("a9d6f0")], "bg": Color("9cc9e6"), "spark": Color("ffffff")},
	{"floor": [Color("5d4c8c"), Color("54447f")], "wall": [Color("2b2152"), Color("211840"), Color("5a3f9a")], "bg": Color("130d29"), "spark": Color("ff8ae8")},
	{"floor": [Color("e2c47c"), Color("d6b66c")], "wall": [Color("8f5c3b"), Color("6f4630"), Color("b57d52")], "bg": Color("2b1a12"), "spark": Color("ffd45e")},
]

static var _cache := {}

static func tex(name: String, region := 0) -> Texture2D:
	var key := "%s:%d" % [name, region]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(name, region))
	return _cache[key]

static func _img() -> Image:
	var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	return im

static func _r(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			if x + i >= 0 and y + j >= 0 and x + i < 16 and y + j < 16:
				im.set_pixel(x + i, y + j, c)

static func _circle(im: Image, cx: float, cy: float, rad: float, c: Color) -> void:
	for j in 16:
		for i in 16:
			if Vector2(i + 0.5, j + 0.5).distance_to(Vector2(cx, cy)) <= rad:
				im.set_pixel(i, j, c)

static func _str(im: Image, rows: Array, pal: Dictionary) -> void:
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if pal.has(ch):
				im.set_pixel(x, y, pal[ch])

const CAT_ROWS := [
	"................",
	"..kk........kk..",
	"..kpk......kpk..",
	"..kkkkkkkkkkkk..",
	".kkkkkkkkkkkkkk.",
	".kkEEkkkkkkEEkk.",
	".kkEEkkkkkkEEkk.",
	".kkkkkkppkkkkkk.",
	"..kkkkkkkkkkkk..",
	"..kkkkkkkkkkkk..",
	".kkkgkkkkkkgkkk.",
	".kkkkkkkkkkkkkkk",
	".kkkkkkkkkkkkkkk",
	"..kkkkkkkkkkkk.k",
	"..kk..kk..kk..kk",
	"................",
]

static func _build(name: String, region: int) -> Image:
	var im := _img()
	var th: Dictionary = THEMES[region]
	var dark := Color("1c1a24")
	match name:
		"cat_open", "cat_blink", "cat_happy":
			var pal := {"k": dark, "p": Color("ff8fa3"), "g": Color("3b3850"), "E": Color("ffd84a")}
			_str(im, CAT_ROWS, pal)
			if name == "cat_open":
				im.set_pixel(3, 5, Color.WHITE)
				im.set_pixel(11, 5, Color.WHITE)
				_r(im, 3, 6, 2, 1, Color("e5a500"))
				_r(im, 11, 6, 2, 1, Color("e5a500"))
			elif name == "cat_blink":
				_r(im, 3, 5, 2, 2, dark)
				_r(im, 11, 5, 2, 2, dark)
				_r(im, 3, 6, 2, 1, Color("ffd84a"))
				_r(im, 11, 6, 2, 1, Color("ffd84a"))
			else:
				_r(im, 3, 5, 2, 2, dark)
				_r(im, 11, 5, 2, 2, dark)
				im.set_pixel(3, 6, Color("ffd84a")); im.set_pixel(4, 5, Color("ffd84a")); im.set_pixel(5, 6, Color("ffd84a"))
				im.set_pixel(10, 6, Color("ffd84a")); im.set_pixel(11, 5, Color("ffd84a")); im.set_pixel(12, 6, Color("ffd84a"))
				_r(im, 7, 8, 2, 1, Color("ff8fa3"))
		"crate", "crate_done":
			var b := Color("c98a4b")
			var d := Color("7a4a24")
			_r(im, 1, 1, 14, 14, d)
			_r(im, 2, 2, 12, 12, b if name == "crate" else Color("e8b45a"))
			_r(im, 2, 7, 12, 2, d)
			_r(im, 7, 2, 2, 12, d)
			for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
				im.set_pixel(p.x, p.y, Color("f6d9a0"))
			if name == "crate_done":
				_r(im, 1, 1, 14, 1, Color("fff2a0")); _r(im, 1, 14, 14, 1, Color("fff2a0"))
		"fish":
			var pal := {"b": Color("ff9f43"), "B": Color("ffd08a"), "t": Color("ff7a2f"), "e": dark}
			_str(im, ["................", "................", "................", "......bbbb......", "....bbbbbbbb..t.", "..bbbbbbbbbbbtt.", ".bbebbbbbbbbbttt", ".bbbbbbbbbbbbttt", "..bBBBBBBBBbtt..", "....BBBBBBBt....", "................"], pal)
		"key":
			var g := Color("ffd23f")
			var gd := Color("c59a10")
			_circle(im, 5, 5, 3.4, g)
			_circle(im, 5, 5, 1.4, Color(0, 0, 0, 0))
			_r(im, 7, 7, 7, 2, g)
			_r(im, 11, 9, 2, 3, gd)
			_r(im, 14, 9, 1, 2, gd)
		"target":
			var c := Color(1, 1, 1, 0.55)
			_circle(im, 8, 10, 3.2, c)
			for p in [Vector2(3.5, 6.5), Vector2(6.3, 3.8), Vector2(9.7, 3.8), Vector2(12.5, 6.5)]:
				_circle(im, p.x, p.y, 1.6, c)
		"exit_closed", "exit_open":
			var open := name == "exit_open"
			_r(im, 1, 1, 14, 14, Color("3a3150"))
			_r(im, 2, 2, 12, 12, Color("1d1730"))
			if open:
				_circle(im, 8, 8, 5.5, Color("ff9f1c"))
				_circle(im, 8, 8, 3.8, Color("ffd45e"))
				_circle(im, 8, 8, 2, Color("fffbe0"))
			else:
				_r(im, 5, 7, 6, 5, Color("8a8fa3"))
				_r(im, 6, 4, 4, 4, Color("8a8fa3"))
				_r(im, 7, 5, 2, 3, Color("1d1730"))
				_r(im, 7, 9, 2, 2, Color("1d1730"))
		"switch", "switch_on":
			var on := name == "switch_on"
			_r(im, 2, 2, 12, 12, Color("5a5f75"))
			_r(im, 3, 3, 10, 10, Color("7d839c") if not on else Color("6b7089"))
			_r(im, 5, 5, 6, 6, Color("57e389") if on else Color("e0555a"))
			if on:
				_r(im, 5, 5, 6, 1, Color("a6ffc6"))
		"door", "door_open":
			if name == "door":
				_r(im, 0, 0, 16, 16, Color("2a2a38"))
				for x in [1, 5, 9, 13]:
					_r(im, x, 0, 2, 16, Color("9aa0b5"))
				_r(im, 0, 3, 16, 2, Color("6d7388")); _r(im, 0, 11, 16, 2, Color("6d7388"))
			else:
				_r(im, 0, 0, 2, 16, Color("9aa0b5")); _r(im, 14, 0, 2, 16, Color("9aa0b5"))
				_r(im, 0, 0, 16, 2, Color("6d7388"))
		"locked":
			_r(im, 0, 0, 16, 16, Color("6f4630"))
			_r(im, 1, 1, 14, 14, Color("8f5c3b"))
			_r(im, 1, 7, 14, 2, Color("6f4630"))
			_r(im, 5, 5, 6, 6, Color("ffd23f"))
			_r(im, 7, 7, 2, 3, dark)
		"ice":
			_r(im, 0, 0, 16, 16, Color("bfeaff"))
			_r(im, 0, 0, 16, 1, Color("e9fbff")); _r(im, 0, 0, 1, 16, Color("e9fbff"))
			for i in 6:
				im.set_pixel(3 + i, 11 - i, Color.WHITE)
			for i in 4:
				im.set_pixel(9 + i, 14 - i, Color("e9fbff"))
			im.set_pixel(12, 3, Color.WHITE); im.set_pixel(2, 3, Color.WHITE)
		"pad_a", "pad_b", "pad_c":
			var col: Color = {"pad_a": Color("3ee0ff"), "pad_b": Color("ff5fd2"), "pad_c": Color("9dff4a")}[name]
			_circle(im, 8, 8, 7, col)
			_circle(im, 8, 8, 5, Color("1b1233"))
			_circle(im, 8, 8, 3.2, col.darkened(0.2))
			_circle(im, 8, 8, 1.4, Color("1b1233"))
		"gate_x", "gate_y", "gate_x_open", "gate_y_open":
			var col := Color("46a7ff") if name.begins_with("gate_x") else Color("ff6fb5")
			if name.ends_with("open"):
				_r(im, 1, 1, 14, 1, col); _r(im, 1, 14, 14, 1, col); _r(im, 1, 1, 1, 14, col); _r(im, 14, 1, 1, 14, col)
				im.set_pixel(8, 8, col)
			else:
				_r(im, 1, 1, 14, 14, col.darkened(0.35))
				_r(im, 2, 2, 12, 12, col)
				_r(im, 3, 3, 4, 2, col.lightened(0.5))
				_r(im, 3, 3, 2, 5, col.lightened(0.5))
		"floor0", "floor1":
			var cols: Array = th.floor
			var c: Color = cols[int(name.right(1))]
			im.fill(c)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + region * 31 + int(name.right(1))
			for i in 7:
				im.set_pixel(rng.randi() % 16, rng.randi() % 16, c.darkened(0.12))
			for i in 3:
				im.set_pixel(rng.randi() % 16, rng.randi() % 16, c.lightened(0.15))
			if region == 1:
				_r(im, 0, 0, 16, 1, c.darkened(0.15)); _r(im, 0, 0, 1, 16, c.darkened(0.15))
		"wall":
			var w: Array = th.wall
			im.fill(w[0])
			var rng := RandomNumberGenerator.new()
			rng.seed = 99 + region
			if region == 0:
				for i in 40:
					im.set_pixel(rng.randi() % 16, rng.randi() % 16, w[2] if i % 3 == 0 else w[1])
			else:
				_r(im, 0, 0, 16, 2, w[2])
				_r(im, 0, 7, 16, 1, w[1]); _r(im, 0, 15, 16, 1, w[1])
				_r(im, 7, 0, 1, 7, w[1]); _r(im, 3, 8, 1, 7, w[1]); _r(im, 11, 8, 1, 7, w[1])
				if region == 3:
					_r(im, 9, 4, 2, 3, Color("ff8ae8")); _r(im, 4, 10, 2, 3, Color("7af0ff"))
				if region == 4:
					_r(im, 6, 4, 4, 2, Color("ffd45e"))
	return im
