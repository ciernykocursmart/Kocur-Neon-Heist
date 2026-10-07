class_name UITheme
extends RefCounted
## Builds the neon UI Theme in code and provides small widget helpers so every
## screen shares one look (and button sounds) without editor-made resources.

static var _theme: Theme
static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono", "Courier New", "monospace"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18

	var normal := _box(Color(0.05, 0.05, 0.11, 0.92), Palette.with_alpha(Palette.CYAN, 0.55), 2)
	var hover := _box(Color(0.08, 0.12, 0.2, 0.95), Palette.CYAN, 2)
	hover.shadow_color = Palette.with_alpha(Palette.CYAN, 0.35)
	hover.shadow_size = 8
	var pressed := _box(Color(0.2, 0.06, 0.18, 0.95), Palette.MAGENTA, 2)
	var disabled := _box(Color(0.04, 0.04, 0.07, 0.8), Color(0.25, 0.25, 0.35, 0.6), 1)
	var focus := _box(Color(0, 0, 0, 0), Palette.MAGENTA, 2)
	focus.draw_center = false

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Palette.WHITE)
	t.set_color("font_hover_color", "Button", Palette.CYAN)
	t.set_color("font_pressed_color", "Button", Palette.MAGENTA)
	t.set_color("font_focus_color", "Button", Palette.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.55))
	t.set_font_size("font_size", "Button", 20)

	t.set_stylebox("panel", "Panel", _box(Color(0.03, 0.03, 0.08, 0.94), Palette.with_alpha(Palette.PURPLE, 0.7), 2))
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.03, 0.03, 0.08, 0.94), Palette.with_alpha(Palette.PURPLE, 0.7), 2, 18))

	t.set_color("font_color", "Label", Palette.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))

	t.set_color("font_color", "CheckButton", Palette.WHITE)
	t.set_color("font_hover_color", "CheckButton", Palette.CYAN)
	t.set_color("font_pressed_color", "CheckButton", Palette.WHITE)
	t.set_color("font_hover_pressed_color", "CheckButton", Palette.CYAN)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", focus)

	var slider_bg := _box(Color(0.1, 0.1, 0.2), Palette.with_alpha(Palette.CYAN, 0.4), 1)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	var slider_fill := _box(Palette.with_alpha(Palette.CYAN, 0.7), Palette.CYAN, 1)
	slider_fill.content_margin_top = 3
	slider_fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	var dialog_panel := _box(Color(0.03, 0.03, 0.08, 0.98), Palette.MAGENTA, 2, 14)
	t.set_stylebox("panel", "AcceptDialog", dialog_panel)
	t.set_stylebox("panel", "ConfirmationDialog", dialog_panel)
	_theme = t
	return t


static func _box(bg: Color, border: Color, border_w: int, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin + 6
	s.content_margin_right = margin + 6
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	return s


static func make_button(text: String, callback: Callable, min_width := 260.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44)
	b.focus_mode = Control.FOCUS_ALL
	wire_button(b)
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


static func wire_button(b: BaseButton) -> void:
	b.mouse_entered.connect(func():
		if not b.disabled:
			Sfx.play("ui_hover", -6.0))
	b.pressed.connect(func(): Sfx.play("ui_click"))


static func make_label(text: String, size := 18, color := Palette.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


## Neon title label with a coloured outline glow.
static func make_title(text: String, size := 48, color := Palette.CYAN) -> Label:
	var l := make_label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Palette.with_alpha(color, 0.35))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Palette.with_alpha(Palette.MAGENTA, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func set_crosshair_cursor(enabled: bool) -> void:
	if not enabled:
		Input.set_custom_mouse_cursor(null)
		return
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(15.5, 15.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			var on_ring := absf(d - 9.0) < 1.1
			var on_cross := (absi(x - 15) <= 0 or absi(x - 16) <= 0) and (y < 9 or y > 22) and (y > 3 and y < 28)
			var on_cross_h := (absi(y - 15) <= 0 or absi(y - 16) <= 0) and (x < 9 or x > 22) and (x > 3 and x < 28)
			var on_dot := d < 1.6
			if on_ring and not (absi(x - 15) < 4 or absi(y - 15) < 4):
				img.set_pixel(x, y, Palette.CYAN)
			elif on_cross or on_cross_h:
				img.set_pixel(x, y, Palette.MAGENTA)
			elif on_dot:
				img.set_pixel(x, y, Palette.WHITE)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(16, 16))
