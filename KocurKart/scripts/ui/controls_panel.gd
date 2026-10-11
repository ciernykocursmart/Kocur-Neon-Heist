extends Control
## Controls screen: shows every action with keyboard and gamepad bindings and
## lets the player rebind the primary keyboard key of driving actions.

var _list: VBoxContainer
var _waiting := ""
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.dim_backdrop(self, 0.85)
	var p := UI.panel(Vector2(900, 0))
	UI.center(self, p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var title := UI.label("CONTROLS", 44, UI.ACCENT, true, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(_list)
	_hint = UI.label("Select an action to rebind its main key. Gamepads work automatically.", 18, UI.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	var tips := UI.label("Drift: hold while steering, release when sparks glow for a boost.  Purr Boost: spend a full segment.", 18, UI.ACCENT2)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tips)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(UI.button("Reset to defaults", _reset, 260))
	h.add_child(UI.button("Back", queue_free, 200))
	_refresh()
	UI.focus_first(self)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for action in Controls.ORDER:
		var row := HBoxContainer.new()
		var name := UI.label(Controls.ACTIONS[action]["label"], 22, UI.TEXT, true)
		name.custom_minimum_size = Vector2(250, 0)
		row.add_child(name)
		var b := Button.new()
		b.text = Controls.binding_text(action)
		b.custom_minimum_size = Vector2(560, 42)
		b.add_theme_font_size_override("font_size", 19)
		b.focus_mode = Control.FOCUS_ALL
		if action in Controls.REBINDABLE:
			b.pressed.connect(func(): _start_rebind(action, b))
		else:
			b.disabled = true
		row.add_child(b)
		_list.add_child(row)


func _start_rebind(action: String, b: Button) -> void:
	_waiting = action
	b.text = "Press a key...  (Esc cancels)"
	_hint.text = "Press the new key for %s" % Controls.ACTIONS[action]["label"]


func _input(event: InputEvent) -> void:
	if _waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		if _waiting == "" and (event.is_action_pressed("ui_cancel")):
			get_viewport().set_input_as_handled()
			queue_free()
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode
	if code == KEY_ESCAPE:
		_waiting = ""
		_refresh()
		return
	var keys: Dictionary = Settings.get_value("keys", {}).duplicate()
	# Swap if another action already uses this key as its primary.
	for other in Controls.REBINDABLE:
		if other != _waiting and Controls.primary_key_name(other) == OS.get_keycode_string(code):
			keys[other] = _primary_code(_waiting)
	keys[_waiting] = code
	Settings.set_value("keys", keys)
	_waiting = ""
	_hint.text = "Saved."
	_refresh()


func _primary_code(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func _reset() -> void:
	Settings.set_value("keys", {})
	_refresh()
