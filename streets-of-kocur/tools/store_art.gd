extends SceneTree
## Renders Microsoft Store art (key art, wide tile, splash) with the game's own
## cat and item painters. Needs a display (xvfb-run) at least as large as the image:
##   xvfb-run -s "-screen 0 3900x2200x24" godot --path . \
##     -s res://tools/store_art.gd -- <layout> <out.png> <width> <height>
## layout: "key" (night street, Kocur vs. Lord Lardpaw and the gang + title),
##         "banner" (title + Kocur on a dark street).
## Everything is vector-drawn on a logical canvas 1080 units high, scaled to
## the output, so it stays sharp at any size.

const LK = preload("res://scripts/data/looks.gd")

var _w := 0.0
var _layout := ""


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var a := OS.get_cmdline_user_args()
	_layout = a[0]
	var out := a[1]
	var win := Vector2i(int(a[2]), int(a[3]))
	root.size = win
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for i in 5:
		await process_frame
	var art := Art.new()
	art.layout = _layout
	art.px = Vector2(win)
	root.add_child(art)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	if img.get_size() != win:
		push_error("window is %s, wanted %s - is the X screen large enough?" % [img.get_size(), win])
	quit()


class Art extends Node2D:
	const LK = preload("res://scripts/data/looks.gd")
	var layout := "key"
	var px := Vector2(1920, 1080)
	var k := 1.0  ## pixels per logical unit
	var w := 1920.0  ## logical width
	var font: Font

	func _ready() -> void:
		font = ThemeDB.fallback_font
		k = px.y / 1080.0
		w = px.x / k
		queue_redraw()

	func _t(pos: Vector2, scl := 1.0, flip := false) -> void:
		draw_set_transform(pos * k, 0.0, Vector2(-scl if flip else scl, scl) * k)

	func _text(text: String, center_x: float, y: float, size: float, fill: Color, outline: Color, ow: float) -> void:
		# Drawn at real pixel size (no scaling) so the letters stay crisp.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var fs := int(size * k)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(center_x * k - width * 0.5, y * k)
		draw_string_outline(font, p + Vector2(0, fs * 0.08), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ow * k * 1.6), Color("e8413c"))
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ow * k), outline)
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)

	func _plain(text: String, center_x: float, y: float, size: float, fill: Color) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var fs := int(size * k)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(center_x * k - width * 0.5, y * k)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(6 * k), Color("1a0a20"))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)

	func _street(floor_y: float, signs_on := true) -> void:
		_t(Vector2.ZERO)
		# night sky
		var top := Color("120a24")
		var bot := Color("3a1a4a")
		for i in 24:
			var y0 := floor_y * i / 24.0
			draw_rect(Rect2(0, y0, w, floor_y / 24.0 + 1), top.lerp(bot, float(i) / 23.0))
		draw_circle(Vector2(w * 0.9, 380), 60, Color("fff1c8", 0.9))
		draw_circle(Vector2(w * 0.9 + 24, 368), 54, top.lerp(bot, 0.4))
		# skyline
		var x := -40.0
		var n := 0
		while x < w + 40.0:
			var bw := 140.0 + fmod(n * 73.0, 120.0)
			var bh := 260.0 + fmod(n * 131.0, 330.0)
			var r := Rect2(x, floor_y - bh, bw, bh)
			draw_rect(r, Color("1d1430") if n % 2 == 0 else Color("241a3a"))
			for wy in int(bh / 46.0) - 1:
				for wx in int(bw / 38.0):
					if (n * 7 + wx * 3 + wy * 5) % 4 != 0:
						var lit := (n + wx + wy) % 3 == 0
						draw_rect(Rect2(x + 14 + wx * 38, floor_y - bh + 24 + wy * 46, 18, 24), Color("ffcf6a", 0.85) if lit else Color("3a2c58"))
			x += bw + 12.0
			n += 1
		# neon signs
		var signs := [] if not signs_on else [["SUSHI", Color("4af0c8"), 0.12], ["CLAW CLUB", Color("ff4a9a"), 0.47], ["NEKO BAR", Color("ffd23a"), 0.78]]
		for s: Array in signs:
			var sx: float = w * float(s[2])
			var sw := 60.0 + String(s[0]).length() * 26.0
			var rr := Rect2(sx, floor_y - 300, sw, 70)
			draw_rect(rr.grow(10), Color(s[1], 0.15))
			draw_rect(rr, Color("140c20"))
			draw_rect(rr, s[1], false, 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var fs := int(40 * k)
			var tw := font.get_string_size(String(s[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((sx + sw * 0.5) * k - tw * 0.5, (floor_y - 250) * k), String(s[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, s[1])
			_t(Vector2.ZERO)
		# sidewalk + street
		draw_rect(Rect2(0, floor_y, w, 40), Color("4a3a5e"))
		draw_rect(Rect2(0, floor_y + 40, w, 1080 - floor_y - 40), Color("2a2238"))
		for i in int(w / 220.0) + 1:
			draw_rect(Rect2(i * 220.0 + 40, floor_y + 190, 120, 12), Color("ffd23a", 0.55))
		draw_rect(Rect2(0, floor_y + 40, w, 6), Color("ff4a9a", 0.35))

	func _cat(kind: String, pos: Vector2, scl: float, pose: Dictionary, flip := false) -> void:
		_t(pos)
		draw_colored_polygon(CatPainter._ellipse(Vector2.ZERO, 26.0 * scl * float(LK.LOOKS[kind].get("bw", 1.0)), 7.0 * scl), Color(0, 0, 0, 0.35))
		_t(pos, scl, flip)
		CatPainter.draw_cat(self, LK.LOOKS[kind], pose)

	func _item(kind: String, pos: Vector2, s: float) -> void:
		_t(Vector2.ZERO)
		PickupArt.draw_item(self, kind, pos, s, 0.6)

	func _draw() -> void:
		if layout == "banner":
			_banner()
		else:
			_key()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _key() -> void:
		var narrow := w < 1500.0
		var floor_y := 700.0 if not narrow else 640.0
		_street(floor_y, not narrow)
		var cx := w * 0.5
		var ground := floor_y + 300.0 if not narrow else floor_y + 340.0
		var hero := {"tail": 0.6, "arm_f": Vector2(30, -8), "arm_b": Vector2(10, 4), "eyes": "angry", "mouth": "grin", "lean": 0.12, "leg_f": 0.45, "leg_b": -0.35}
		var boss := {"arm_f": Vector2(34, -2), "arm_b": Vector2(-24, -10), "eyes": "angry", "mouth": "teeth", "belly": 0.06, "lean": -0.05}
		var gang := {"arm_f": Vector2(-6, 2), "eyes": "angry", "mouth": "teeth", "lean": -0.08}
		if narrow:
			_cat("lardpaw", Vector2(cx + w * 0.16, ground - 120), 3.1, boss, true)
			_cat("punk", Vector2(cx + w * 0.40, ground - 30), 2.2, gang, true)
			_cat("brawler", Vector2(cx - w * 0.36, ground - 60), 2.3, gang)
			_cat("hero", Vector2(cx - w * 0.17, ground + 20), 3.0, hero)
			_item("golden", Vector2(cx - w * 0.38, ground + 30), 2.4)
			_item("chicken", Vector2(cx + w * 0.40, ground + 40), 2.2)
			var ts := minf(w * 0.12, 115.0)
			_text("STREETS", cx, 90 + ts * 0.8, ts, Color("ffd23a"), Color("1a0a20"), 16)
			_text("OF KOCUR", cx, 90 + ts * 1.9, ts, Color("ffd23a"), Color("1a0a20"), 16)
			_plain("A KOCUR STUDIOS BEAT 'EM UP", cx, 90 + ts * 2.55, 36, Color("b9a8e8"))
		else:
			_cat("lardpaw", Vector2(cx + 430, ground - 40), 3.2, boss, true)
			_cat("punk", Vector2(cx + 120, ground + 20), 2.4, gang, true)
			_cat("runner", Vector2(cx + 820, ground - 120), 2.1, gang, true)
			_cat("thrower", Vector2(cx - 760, ground - 140), 2.0, gang)
			_cat("hero", Vector2(cx - 300, ground + 30), 3.3, hero)
			_item("golden", Vector2(cx - 620, ground + 40), 2.6)
			_item("can", Vector2(cx - 40, ground + 50), 2.2)
			_item("chicken", Vector2(cx + 760, ground + 40), 2.4)
			_text("STREETS OF KOCUR", cx, 210, 150, Color("ffd23a"), Color("1a0a20"), 18)
			_plain("A KOCUR STUDIOS BEAT 'EM UP", cx, 290, 44, Color("b9a8e8"))

	func _banner() -> void:
		_street(560.0, false)
		_t(Vector2.ZERO)
		draw_rect(Rect2(0, 0, w, 1080), Color(0.05, 0.02, 0.08, 0.45))
		var hero := {"tail": 0.6, "arm_f": Vector2(30, -8), "arm_b": Vector2(10, 4), "eyes": "angry", "mouth": "grin", "lean": 0.12, "leg_f": 0.45, "leg_b": -0.35}
		_cat("hero", Vector2(w * 0.17, 1000), 6.0, hero)
		_text("STREETS", w * 0.62, 470, 230, Color("ffd23a"), Color("1a0a20"), 26)
		_text("OF KOCUR", w * 0.62, 760, 230, Color("ffd23a"), Color("1a0a20"), 26)
