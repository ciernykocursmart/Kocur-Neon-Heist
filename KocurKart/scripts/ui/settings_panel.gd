extends Control
## Settings screen, used from the main menu and the pause menu. Every option
## here is applied immediately and saved.

signal closed

var _rows: VBoxContainer
var _controls_panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.dim_backdrop(self, 0.75)
	var p := UI.panel(Vector2(760, 0))
	UI.center(self, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var title := UI.label("SETTINGS", 44, UI.ACCENT, true, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	v.add_child(_rows)
	_slider("Master volume", "master_volume", 0.0, 1.0, 0.05)
	_slider("Music volume", "music_volume", 0.0, 1.0, 0.05)
	_slider("Effects volume", "sfx_volume", 0.0, 1.0, 0.05)
	_toggle("Fullscreen", "fullscreen")
	_choice("Window size", "resolution", Settings.RESOLUTIONS, Settings.RESOLUTIONS)
	_toggle("VSync", "vsync")
	_choice("Frame rate cap", "max_fps", Settings.FPS_CAPS, ["Unlimited", "30", "60", "120", "144"])
	_slider("Camera follow speed", "camera_sensitivity", 0.5, 1.5, 0.05)
	_slider("Camera distance", "camera_distance", 0.8, 1.3, 0.05)
	_toggle("Show minimap", "show_minimap")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	buttons.add_child(UI.button("Controls", _open_controls, 220))
	buttons.add_child(UI.button("Back", _close, 220))
	UI.focus_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if _controls_panel == null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(text, 22, UI.TEXT, true)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	_rows.add_child(h)
	return h


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(300, 32)
	s.focus_mode = Control.FOCUS_ALL
	var val := UI.label("%d%%" % int(s.value * 100), 20, UI.MUTED)
	val.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(x):
		Settings.set_value(key, x)
		val.text = "%d%%" % int(x * 100)
		if key == "sfx_volume":
			Audio.play("ui_move"))
	h.add_child(s)
	h.add_child(val)


func _toggle(text: String, key: String) -> void:
	var h := _row(text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.text = "On" if c.button_pressed else "Off"
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on):
		Settings.set_value(key, on)
		c.text = "On" if on else "Off"
		Audio.play("ui_select"))
	h.add_child(c)


func _choice(text: String, key: String, values: Array, labels: Array) -> void:
	var h := _row(text)
	var o := OptionButton.new()
	for i in labels.size():
		o.add_item(labels[i], i)
	var cur = Settings.get_value(key)
	o.selected = maxi(values.find(cur), 0)
	o.custom_minimum_size = Vector2(300, 44)
	o.item_selected.connect(func(i):
		Settings.set_value(key, values[i])
		Audio.play("ui_select"))
	h.add_child(o)


func _open_controls() -> void:
	_controls_panel = preload("res://scripts/ui/controls_panel.gd").new()
	add_child(_controls_panel)
	_controls_panel.tree_exited.connect(func():
		_controls_panel = null
		UI.focus_first(self))
