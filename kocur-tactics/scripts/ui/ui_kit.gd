extends RefCounted
## Shared UI look: palette, theme, and small builders for panels, labels and
## buttons. Every screen is built in code with these helpers.

const BG := Color("141020")
const PANEL := Color("221a33")
const PANEL_DARK := Color("181226")
const BORDER := Color("5a4a80")
const ACCENT := Color("f2c230")
const TEXT := Color("f0eaff")
const TEXT_DIM := Color("a89cc8")
const HERO := Color("5ab0ff")
const ENEMY := Color("ff5a6a")
const GOOD := Color("6ee08a")
const BAD := Color("ff6a6a")

static var _theme: Theme
static var _tex_cache := {}


static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := "res://assets/sprites/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t


## First frame of a unit sheet (16x16) as its own texture (portraits, icons).
static func unit_portrait(kind: String) -> Texture2D:
	var key := "portrait_" + kind
	if _tex_cache.has(key):
		return _tex_cache[key]
	var sheet := tex("unit_" + kind)
	if sheet == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(0, 0, 16, 16)
	_tex_cache[key] = at
	return at


static func box(bg: Color, border: Color, width := 2, radius := 4, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.65))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", box(Color("2e2445"), BORDER))
	t.set_stylebox("hover", "Button", box(Color("3e3160"), ACCENT))
	t.set_stylebox("pressed", "Button", box(Color("4a3a72"), ACCENT))
	t.set_stylebox("disabled", "Button", box(Color("1e182c"), Color("3a3050")))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 14)
	t.set_font_size("bold_font_size", "RichTextLabel", 14)
	t.set_stylebox("slider", "HSlider", box(Color("2e2445"), BORDER, 1, 3, 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, ACCENT, 1, 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color.WHITE, ACCENT, 1, 3, 2))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("normal", "OptionButton", box(Color("2e2445"), BORDER))
	t.set_stylebox("hover", "OptionButton", box(Color("3e3160"), ACCENT))
	t.set_stylebox("pressed", "OptionButton", box(Color("4a3a72"), ACCENT))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, BORDER))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_DARK, ACCENT, 1))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func label(text: String, size := 16, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func wrap_label(text: String, size := 15, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_w := 0, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func() -> void:
		Audio.play("ui_ok")
		cb.call())
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Audio.play("ui_move", -6.0))
	return b


static func panel(bg := PANEL, border := BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border))
	return p


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func icon_rect(t: Texture2D, size := 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


## Full-screen dimmer with a centred panel; returns [overlay, content vbox].
static func modal(parent: Node, width := 520) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := panel(PANEL, ACCENT)
	p.custom_minimum_size.x = width
	center.add_child(p)
	var v := vbox(10)
	p.add_child(v)
	return [dim, v]


## Yes/No confirmation dialog.
static func confirm(parent: Node, question: String, on_yes: Callable, yes_text := "Yes", no_text := "Cancel") -> Control:
	var m := modal(parent, 460)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	var q := wrap_label(question, 18)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var row := hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var yes := button(yes_text, func() -> void:
		dim.queue_free()
		on_yes.call(), 140)
	var no := button(no_text, func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 140)
	row.add_child(no)
	row.add_child(yes)
	no.call_deferred("grab_focus")
	return dim
