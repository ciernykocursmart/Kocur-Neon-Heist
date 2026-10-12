extends RefCounted
## UI kit: the original Kocur pixel font (built from assets/fonts/kocur_font.png),
## the shared theme, and small factory helpers for menus.

const Sprites := preload("res://scripts/fx/sprites.gd")

const C_BG := Color(0.07, 0.05, 0.11, 0.94)
const C_PANEL := Color(0.12, 0.09, 0.18, 0.96)
const C_BORDER := Color(0.55, 0.48, 0.78)
const C_GOLD := Color(1.0, 0.82, 0.35)
const C_TEXT := Color(0.93, 0.9, 1.0)
const C_DIM := Color(0.62, 0.58, 0.72)
const C_GOOD := Color(0.55, 1.0, 0.6)
const C_BAD := Color(1.0, 0.45, 0.45)

const ICONS := {"heart": 0, "half": 1, "empty": 2, "coin": 3, "gem": 4, "cat": 5, "chest": 6, "skull": 7,
	"shield": 8, "clock": 9, "star": 10, "lock": 11, "check": 12, "relic": 13, "paw": 14, "sword": 15, "speed": 16}

static var _font: FontFile
static var _theme: Theme


static func font() -> FontFile:
	if _font:
		return _font
	var tex: Texture2D = load("res://assets/fonts/kocur_font.png")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var f := FontFile.new()
	f.fixed_size = 10
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var sz := Vector2i(10, 0)
	f.set_texture_image(0, sz, 0, img)
	f.set_cache_ascent(0, 10, 8.0)
	f.set_cache_descent(0, 10, 2.0)
	for i in range(32, 127):
		var idx := i - 32
		f.set_glyph_advance(0, 10, i, Vector2(6, 0))
		f.set_glyph_offset(0, sz, i, Vector2(0, -8))
		f.set_glyph_size(0, sz, i, Vector2(6, 10))
		f.set_glyph_uv_rect(0, sz, i, Rect2(idx * 6, 0, 6, 10))
		f.set_glyph_texture_idx(0, sz, i, 0)
	_font = f
	return f


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 10
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.02, 0.05))
	t.set_constant("outline_size", "Label", 2)
	t.set_constant("line_spacing", "Label", 1)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_PANEL
		sb.border_color = C_BORDER
		sb.set_border_width_all(1)
		sb.set_content_margin_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		match state:
			"hover":
				sb.bg_color = Color(0.2, 0.15, 0.3)
			"pressed":
				sb.bg_color = Color(0.3, 0.22, 0.42)
			"focus":
				sb.bg_color = Color(0.22, 0.16, 0.32)
				sb.border_color = C_GOLD
				sb.set_border_width_all(2)
			"disabled":
				sb.bg_color = Color(0.1, 0.08, 0.14)
				sb.border_color = Color(0.3, 0.27, 0.4)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", C_GOLD)
	t.set_color("font_pressed_color", "Button", C_GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.55))
	var panel := StyleBoxFlat.new()
	panel.bg_color = C_BG
	panel.border_color = C_BORDER
	panel.set_border_width_all(2)
	panel.set_content_margin_all(10)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 4
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# Sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.17, 0.28)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOLD
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _grabber_texture()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_icon("grabber_disabled", "HSlider", grab)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = C_GOLD
	focus.set_border_width_all(1)
	t.set_stylebox("focus", "HSlider", focus)
	t.set_stylebox("focus", "CheckButton", focus)
	t.set_stylebox("focus", "OptionButton", t.get_stylebox("focus", "Button"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", C_TEXT)
	t.set_color("font_focus_color", "CheckButton", C_GOLD)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_focus_color", "OptionButton", C_GOLD)
	var popup := StyleBoxFlat.new()
	popup.bg_color = C_PANEL
	popup.border_color = C_BORDER
	popup.set_border_width_all(1)
	popup.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_GOLD)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.25, 0.18, 0.36)
	t.set_stylebox("hover", "PopupMenu", hov)
	var sep := StyleBoxLine.new()
	sep.color = Color(0.4, 0.35, 0.55)
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 6)
	# Scroll
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0.15, 0.12, 0.22)
	t.set_stylebox("scroll", "VScrollBar", sc)
	var gr := StyleBoxFlat.new()
	gr.bg_color = C_BORDER
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	_theme = t
	return t


static func _grabber_texture() -> Texture2D:
	var img := Image.create(6, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.9, 1.0))
	for y in 10:
		img.set_pixel(0, y, Color(0.3, 0.25, 0.45))
		img.set_pixel(5, y, Color(0.3, 0.25, 0.45))
	return ImageTexture.create_from_image(img)


static func icon_tex(name: String) -> Texture2D:
	if name == "fish":
		return Sprites.region("fish.png", Rect2(0, 0, 16, 16))
	return Sprites.icon(int(ICONS.get(name, 10)))


static func label(text: String, size := 10, color := C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func button(text: String, cb: Callable, min_w := 140) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 18)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.play("ui_ok", -4.0)
		cb.call())
	b.focus_entered.connect(func() -> void: Audio.play("ui_move", -8.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


static func icon_rect(name: String, scale := 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_tex(name)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(16, 16) * scale
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return r


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func center(parent: Control, child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	c.add_child(child)
	return c


static func dim_rect(alpha := 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.01, 0.04, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


static func root_control() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = theme()
	return c


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
