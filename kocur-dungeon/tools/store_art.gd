extends SceneTree
## Renders Microsoft Store art (key art, wide tile, splash) from the game's own
## sprites and pixel font. Needs a display (xvfb-run) and a window as large as
## the image:
##   xvfb-run -s "-screen 0 3900x2200x24" godot --path . \
##     -s res://tools/store_art.gd -- <layout> <out.png> <width> <height> <pixel_scale> [region]
## layout: "key" (characters + title), "banner" (cat on the moon + title).
## The logical canvas is image size / pixel_scale, so the art stays crisp.

## Loaded at run time: the UI kit refers to autoloads, which do not exist yet
## when this script is compiled.
var UI: GDScript
var Sprites: GDScript

var _canvas: Control
var _w := 0.0
var _h := 0.0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	UI = load("res://scripts/ui/ui_kit.gd")
	Sprites = load("res://scripts/fx/sprites.gd")
	var a := OS.get_cmdline_user_args()
	var layout := a[0]
	var out := a[1]
	var win := Vector2i(int(a[2]), int(a[3]))
	var px := int(a[4])
	var region := int(a[5]) if a.size() > 5 else 5
	root.size = win
	for i in 5:
		await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(win.x / px, win.y / px)
	_w = win.x / px
	_h = win.y / px
	_canvas = Control.new()
	_canvas.theme = UI.theme()
	_canvas.size = Vector2(_w, _h)
	root.add_child(_canvas)
	_rect(Vector2.ZERO, Vector2(_w, _h), Color(0.05, 0.04, 0.08))
	if layout == "key":
		_key(region)
	else:
		_banner()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	if img.get_size() != win:
		push_error("window is %s, wanted %s - is the X screen large enough?" % [img.get_size(), win])
	quit()


func _rect(pos: Vector2, sz: Vector2, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = c
	_canvas.add_child(r)
	return r


func _layer(file: String, y: float, alpha: Color) -> void:
	var r := TextureRect.new()
	r.texture = Sprites.texture(file)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.position = Vector2(0, y)
	r.size = Vector2(ceilf(_w / 2.0) + 320, 180)
	r.scale = Vector2(2, 2)
	r.modulate = alpha
	_canvas.add_child(r)


func _sprite(sheet: String, anim: String, pos: Vector2, scl: float, flip := false, frame := 0) -> void:
	var s: AnimatedSprite2D = Sprites.make_sprite(sheet, anim)
	s.stop()
	s.frame = frame
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.flip_h = flip
	_canvas.add_child(s)


func _title(lines: Array, y: float, size: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.position = Vector2(0, y)
	box.size = Vector2(_w, 0)
	for t: String in lines:
		var l: Label = UI.label(t, size, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_constant_override("outline_size", size / 5)
		l.custom_minimum_size = Vector2(_w, 0)
		box.add_child(l)
	_canvas.add_child(box)


## Key art: the hero facing the Pale King and his clan in front of the citadel.
func _key(region: int) -> void:
	var ground := _h - 52.0
	_layer("bg_r%d_far.png" % region, ground - 340, Color(0.8, 0.78, 0.95))
	_layer("bg_r%d_mid.png" % region, ground - 330, Color.WHITE)
	_rect(Vector2.ZERO, Vector2(_w, _h), Color(0.03, 0.02, 0.06, 0.25))
	# Floor: a stone ledge across the whole image.
	_rect(Vector2(0, ground), Vector2(_w, _h - ground), Color(0.1, 0.08, 0.14))
	_rect(Vector2(0, ground), Vector2(_w, 3), Color(0.55, 0.48, 0.78))
	var narrow := _w < 300.0
	var cx := _w * 0.5
	if narrow:
		_title(["KOCUR", "DUNGEON"], 22, 40)
	else:
		_title(["KOCUR DUNGEON"], 34, 40)
	var sub: Label = UI.label("Rescue the ten stolen cats", 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 118 if narrow else 80)
	sub.size = Vector2(_w, 12)
	sub.add_theme_constant_override("outline_size", 3)
	_canvas.add_child(sub)
	var gap := minf(_w * 0.42, 150.0)
	# Hero (left) in the pounce pose, the Pale King (right) with guards.
	_sprite("hero", "attack", Vector2(cx - gap * 0.62, ground - 46), 3.0, false, 1)
	_sprite("boss_king", "cast", Vector2(cx + gap * 0.6, ground - 78), 2.0, true, 0)
	_sprite("guard", "idle", Vector2(cx + gap * 0.05, ground - 31), 2.0, true, 0)
	if _w > 500.0:
		_sprite("archer", "idle", Vector2(cx + gap * 1.15, ground - 31), 2.0, true, 1)
		_sprite("mage", "idle", Vector2(cx + gap * 1.55, ground - 31), 2.0, true, 2)
		_sprite("scout", "walk", Vector2(cx - gap * 1.25, ground - 31), 2.0, false, 2)
	# Coins and a gem floating over the ledge.
	for i in 5:
		var c: AnimatedSprite2D = Sprites.make_sprite("coin")
		c.stop()
		c.frame = 0
		c.position = Vector2(cx - gap * 0.3 + i * 14.0, ground - 100 - absf(i - 2) * 4.0)
		_canvas.add_child(c)
	var gem: AnimatedSprite2D = Sprites.make_sprite("gem")
	gem.stop()
	gem.position = Vector2(cx - gap * 0.62, ground - 130)
	gem.scale = Vector2(2, 2)
	_canvas.add_child(gem)


## Wide tile / splash: the cat on the moon next to the game title.
func _banner() -> void:
	var cat := TextureRect.new()
	cat.texture = Sprites.texture("title_cat.png")
	cat.scale = Vector2(1.5, 1.5)
	cat.position = Vector2(_w * 0.5 - 150, _h * 0.5 - 40)
	_canvas.add_child(cat)
	for i in 2:
		var l: Label = UI.label(["KOCUR", "DUNGEON"][i], 30, UI.C_GOLD)
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(_w * 0.5 - 2, _h * 0.5 - 30 + i * 34)
		_canvas.add_child(l)
