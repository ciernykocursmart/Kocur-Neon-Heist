class_name UI
extends RefCounted
## Shared interface style: palette, fonts, theme and widget helpers, so every
## screen looks like part of the same game.

const BG := Color(0.08, 0.055, 0.14)
const PANEL := Color(0.15, 0.1, 0.25, 0.94)
const PANEL_LIGHT := Color(0.23, 0.16, 0.36, 0.96)
const ACCENT := Color(1.0, 0.52, 0.2)
const ACCENT2 := Color(0.32, 0.85, 1.0)
const TEXT := Color(1.0, 0.96, 0.9)
const MUTED := Color(0.72, 0.66, 0.82)
const GOLD := Color(1.0, 0.8, 0.25)
const SILVER := Color(0.8, 0.84, 0.9)
const BRONZE := Color(0.85, 0.52, 0.3)
const GOOD := Color(0.45, 0.95, 0.5)
const BAD := Color(1.0, 0.4, 0.4)
const LOCKED := Color(0.45, 0.42, 0.52)

static var _theme: Theme
static var _bold: Font
static var _regular: Font


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Fredoka-Bold.ttf")
	return _bold


static func regular() -> Font:
	if _regular == null:
		_regular = load("res://assets/fonts/Fredoka.ttf")
	return _regular


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = regular()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", LOCKED)
	t.set_font("font", "Button", bold())
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, 14, Color(1, 1, 1, 0.08)))
	t.set_stylebox("hover", "Button", box(ACCENT.darkened(0.15), 14, Color(1, 0.85, 0.6, 0.6)))
	t.set_stylebox("focus", "Button", box(ACCENT, 14, Color(1, 0.95, 0.8, 0.95), 3))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.3), 14))
	t.set_stylebox("disabled", "Button", box(Color(0.14, 0.11, 0.2, 0.9), 14))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, Color(1, 1, 1, 0.07)))
	t.set_stylebox("panel", "Panel", box(PANEL, 18))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font("font", "CheckButton", bold())
	t.set_stylebox("normal", "CheckButton", box(Color(0, 0, 0, 0), 10))
	t.set_stylebox("hover", "CheckButton", box(Color(1, 1, 1, 0.06), 10))
	t.set_stylebox("focus", "CheckButton", box(Color(1, 0.6, 0.3, 0.18), 10, ACCENT, 2))
	t.set_stylebox("slider", "HSlider", box(Color(0.08, 0.06, 0.12), 6))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 6))
	t.set_stylebox("focus", "HSlider", box(Color(0, 0, 0, 0), 6, ACCENT, 2))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("normal", "OptionButton", box(PANEL_LIGHT, 12))
	t.set_stylebox("hover", "OptionButton", box(ACCENT.darkened(0.15), 12))
	t.set_stylebox("focus", "OptionButton", box(ACCENT, 12, Color.WHITE, 2))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 10))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.2), 6))
	t.set_stylebox("grabber", "VScrollBar", box(ACCENT.darkened(0.2), 6))
	_theme = t
	return t


static func box(col: Color, radius := 14, border := Color(0, 0, 0, 0), border_w := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border.a > 0.0:
		s.set_border_width_all(border_w)
		s.border_color = border
	return s


static func label(text: String, size := 22, col := TEXT, is_bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if is_bold:
		l.add_theme_font_override("font", bold())
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.1, 0.95))
	return l


static func button(text: String, callback: Callable, min_w := 300) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 54)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("ui_select")
		callback.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -6.0))
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	return b


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func center(parent: Control, child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	c.add_child(child)
	return c


static func time_text(t: float, show_ms := true) -> String:
	if t <= 0.0 or t == INF or is_nan(t):
		return "--:--.---" if show_ms else "--:--"
	var m := int(t / 60.0)
	var s := t - m * 60
	if show_ms:
		return "%d:%06.3f" % [m, s]
	return "%d:%02d" % [m, int(s)]


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


static func trophy_color(t: int) -> Color:
	match t:
		3: return GOLD
		2: return SILVER
		1: return BRONZE
	return LOCKED


static func dim_backdrop(parent: Node, alpha := 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.04, 0.02, 0.08, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)
	return r


## Focus the first enabled button inside `root` (keyboard/gamepad navigation).
static func focus_first(root: Node) -> void:
	for c in root.find_children("*", "BaseButton", true, false):
		var b: BaseButton = c
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
