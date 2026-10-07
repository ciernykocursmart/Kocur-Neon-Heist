class_name SettingsPanel
extends PanelContainer
## Reusable settings form (volume sliders, fullscreen, screen shake).
## Changes apply and persist immediately.

signal closed


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(UITheme.make_title("SETTINGS", 34, Palette.CYAN))
	_add_slider(box, "Master volume", "master_volume")
	_add_slider(box, "Music volume", "music_volume")
	_add_slider(box, "Effects volume", "sfx_volume")
	_add_toggle(box, "Fullscreen", "fullscreen")
	_add_toggle(box, "Screen shake", "screen_shake")
	_add_toggle(box, "Tutorial tips", "tutorial_tips")
	var back := UITheme.make_button("BACK", func(): closed.emit(), 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	back.call_deferred("grab_focus")


func _add_slider(parent: Control, label: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UITheme.make_label(label, 18)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(GameState.settings.get(key, 0.8))
	s.custom_minimum_size = Vector2(220, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UITheme.make_label("%d%%" % int(s.value * 100), 16, Palette.DIM)
	pct.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		GameState.set_setting(key, v)
		Sfx.play("ui_hover", -4.0))
	row.add_child(s)
	row.add_child(pct)
	parent.add_child(row)


func _add_toggle(parent: Control, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = bool(GameState.settings.get(key, false))
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(on: bool):
		GameState.set_setting(key, on)
		Sfx.play("ui_click"))
	parent.add_child(c)
