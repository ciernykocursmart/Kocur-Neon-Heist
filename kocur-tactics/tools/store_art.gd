extends SceneTree
## Renders Microsoft Store art (key art, wide tile, splash) from the game's own
## sprites. Needs a display (xvfb-run) and a screen at least as large as the image:
##   xvfb-run -s "-screen 0 3900x2200x24" godot --path . \
##     -s res://tools/store_art.gd -- <layout> <out.png> <width> <height> <pixel_scale>
## layout: "key" (battlefield with both armies + title), "banner" (title + three heroes).
## The logical canvas is image size / pixel_scale, so the pixel art stays crisp.

var UI: GDScript
var _canvas: Control
var _w := 0.0
var _h := 0.0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	UI = load("res://scripts/ui/ui_kit.gd")
	var a := OS.get_cmdline_user_args()
	var layout := a[0]
	var out := a[1]
	var win := Vector2i(int(a[2]), int(a[3]))
	var px := int(a[4])
	root.size = win
	for i in 5:
		await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(win.x / px, win.y / px)
	_w = win.x / px
	_h = win.y / px
	_canvas = Control.new()
	_canvas.size = Vector2(_w, _h)
	root.add_child(_canvas)
	_rect(Vector2.ZERO, Vector2(_w, _h), Color("141020"))
	if layout == "key":
		_key()
	else:
		_banner()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	if img.get_size() != win:
		push_error("window is %s, wanted %s - is the X screen large enough?" % [img.get_size(), win])
	quit()


func _rect(pos: Vector2, sz: Vector2, c: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = c
	_canvas.add_child(r)


func _tex(name: String, pos: Vector2, scl: float, frame := 0, flip := false) -> void:
	var t: Texture2D = UI.tex(name)
	if t == null:
		push_error("missing sprite " + name)
		return
	var tr := TextureRect.new()
	if t.get_width() > t.get_height():
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(frame * 16, 0, 16, 16)
		tr.texture = at
	else:
		tr.texture = t
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(16, 16) * scl
	tr.position = (pos - tr.size / 2.0).round()
	tr.flip_h = flip
	_canvas.add_child(tr)


func _label(text: String, pos: Vector2, width: float, size: int, color: Color, outline: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(width, size * 1.4)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("2a1840"))
	l.add_theme_constant_override("outline_size", outline)
	_canvas.add_child(l)


## Tiled battlefield: grass with a road, forest and pillars, in the given region style.
func _field(region: String, tile: float) -> void:
	var cols := int(ceil(_w / tile)) + 1
	var rows := int(ceil(_h / tile)) + 1
	for y in rows:
		for x in cols:
			var name := "grass2" if (x * 7 + y * 13) % 5 == 0 else "grass"
			if y == int(rows * 0.62):
				name = "road"
			_tex("tile_%s_%s" % [region, name], Vector2(x + 0.5, y + 0.5) * tile, tile / 16.0)
	for p: Vector2 in [Vector2(0.06, 0.3), Vector2(0.12, 0.85), Vector2(0.9, 0.82), Vector2(0.95, 0.35), Vector2(0.5, 0.92)]:
		var c := Vector2(floor(p.x * cols), floor(p.y * rows))
		_tex("tile_%s_forest" % region, (c + Vector2(0.5, 0.5)) * tile, tile / 16.0)
	# darken toward the top so the title reads well
	for i in 8:
		_rect(Vector2(0, 0), Vector2(_w, _h * (0.55 - i * 0.05)), Color(0.05, 0.03, 0.08, 0.13))


func _key() -> void:
	var tile := 32.0
	_field("crown", tile)
	var narrow := _w / _h < 1.2
	var title_size := int(minf(_w * 0.11, 64.0))
	if narrow:
		_label("KOCUR", Vector2(0, _h * 0.05), _w, title_size, UI.ACCENT, title_size / 5)
		_label("TACTICS", Vector2(0, _h * 0.05 + title_size * 1.1), _w, title_size, UI.ACCENT, title_size / 5)
		_label("Lead the black cats.", Vector2(0, _h * 0.05 + title_size * 2.4), _w, 12, UI.TEXT, 3)
		_label("Outsmart the White Crown.", Vector2(0, _h * 0.05 + title_size * 2.4 + 16), _w, 12, UI.TEXT, 3)
	else:
		_label("KOCUR TACTICS", Vector2(0, _h * 0.06), _w, title_size, UI.ACCENT, title_size / 5)
		_label("Lead the black cats. Outsmart the White Crown.", Vector2(0, _h * 0.06 + title_size * 1.35), _w, 14, UI.TEXT, 3)
	var ground := _h * (0.72 if narrow else 0.70)
	var cx := _w * 0.5
	var gap := _w * 0.26 if narrow else minf(_w * 0.24, 150.0)
	var k := 0.8 if narrow else 1.0
	# heroes (left), facing right
	_tex("unit_guardian", Vector2(cx - gap * 0.55, ground + 4), 4.0 * k)
	_tex("unit_shadowblade", Vector2(cx - gap * 0.85, ground - 56 * k), 4.0 * k, 1)
	_tex("unit_ranger", Vector2(cx - gap * 1.45, ground + 6), 4.0 * k)
	_tex("unit_mender", Vector2(cx - gap * 1.05, ground + 70 * k), 3.5 * k)
	# the Pale King and his legion (right), facing left
	_tex("unit_king", Vector2(cx + gap * 1.0, ground - 30 * k), 6.0 * k, 0, true)
	_tex("unit_guard", Vector2(cx + gap * 0.45, ground + 40 * k), 4.0 * k, 0, true)
	_tex("unit_pylon", Vector2(cx + gap * 1.6, ground - 80 * k), 3.0 * k)
	if not narrow:
		_tex("unit_archer", Vector2(cx + gap * 1.5, ground + 34), 4.0, 1, true)
		_tex("unit_mage", Vector2(cx + gap * 1.85, ground - 16), 4.0, 0, true)
		_tex("unit_stalker", Vector2(cx + gap * 0.3, ground + 86), 3.5, 1, true)
	# a telegraphed lance line between the armies
	for i in 5:
		_rect(Vector2(cx - 14 * k, ground - 80 * k + i * 34 * k), Vector2(28, 28) * k, Color(1.0, 0.55, 0.15, 0.35))


func _banner() -> void:
	_field("wood", 16.0)
	_rect(Vector2.ZERO, Vector2(_w, _h), Color(0.05, 0.03, 0.08, 0.55))
	var size := int(_h * 0.2)
	_label("KOCUR", Vector2(_w * 0.36, _h * 0.22), _w * 0.62, size, UI.ACCENT, maxi(2, size / 6))
	_label("TACTICS", Vector2(_w * 0.36, _h * 0.22 + size * 1.15), _w * 0.62, size, UI.ACCENT, maxi(2, size / 6))
	var s := _h / 40.0
	_tex("unit_shadowblade", Vector2(_w * 0.09, _h * 0.42), s * 0.75, 1)
	_tex("unit_ranger", Vector2(_w * 0.31, _h * 0.42), s * 0.75)
	_tex("unit_guardian", Vector2(_w * 0.2, _h * 0.62), s * 0.9)
