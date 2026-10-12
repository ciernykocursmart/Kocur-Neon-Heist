extends PanelContainer
## Settings panel used by the main menu and the pause menu.
## Every option here is wired to a working setting and saved immediately.

signal closed
signal reset_requested

const UI := preload("res://scripts/ui/ui_kit.gd")

var allow_reset := false
var first_focus: Control
var _box: VBoxContainer
var _confirm_reset := false


func _ready() -> void:
	custom_minimum_size = Vector2(320, 0)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	add_child(_box)
	_box.add_child(UI.label("SETTINGS", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	first_focus = _slider_row("Master volume", Settings.master_volume, func(v: float) -> void: Settings.set_volume("master", v))
	_slider_row("Music volume", Settings.music_volume, func(v: float) -> void: Settings.set_volume("music", v))
	_slider_row("Effects volume", Settings.sfx_volume, func(v: float) -> void:
		Settings.set_volume("sfx", v)
		Audio.play("coin", -4.0))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply_display()
		Settings.save_settings())
	_box.add_child(fs)
	var res_row := HBoxContainer.new()
	res_row.add_child(_fixed_label("Window size"))
	var res := OptionButton.new()
	for r: Vector2i in Settings.RESOLUTIONS:
		res.add_item("%d x %d" % [r.x, r.y])
	res.selected = Settings.resolution_index
	res.custom_minimum_size = Vector2(150, 18)
	res.item_selected.connect(func(i: int) -> void:
		Settings.resolution_index = i
		Settings.apply_display()
		Settings.save_settings())
	res_row.add_child(res)
	_box.add_child(res_row)
	var diff_row := HBoxContainer.new()
	diff_row.add_child(_fixed_label("Difficulty"))
	var diff := OptionButton.new()
	for d: String in Settings.DIFFICULTIES:
		diff.add_item(Settings.DIFFICULTY_NAMES[d])
	diff.selected = Settings.DIFFICULTIES.find(Settings.difficulty)
	diff.custom_minimum_size = Vector2(150, 18)
	diff.item_selected.connect(func(i: int) -> void: Settings.set_difficulty(Settings.DIFFICULTIES[i]))
	diff_row.add_child(diff)
	_box.add_child(diff_row)
	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = Settings.screen_shake
	shake.toggled.connect(func(on: bool) -> void:
		Settings.screen_shake = on
		Settings.save_settings())
	_box.add_child(shake)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(UI.button("Controls", _show_controls, 90))
	if allow_reset:
		btns.add_child(UI.button("Reset Progress", _ask_reset, 110))
	btns.add_child(UI.button("Back", func() -> void: closed.emit(), 70))
	_box.add_child(btns)
	await get_tree().process_frame
	if is_instance_valid(first_focus):
		first_focus.grab_focus()


func _fixed_label(text: String) -> Label:
	var l := UI.label(text)
	l.custom_minimum_size = Vector2(120, 0)
	return l


func _slider_row(text: String, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_child(_fixed_label(text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(150, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var pct := UI.label("%d%%" % int(value * 100), 10, UI.C_DIM)
	pct.custom_minimum_size = Vector2(30, 0)
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100))
		cb.call(v))
	row.add_child(s)
	row.add_child(pct)
	_box.add_child(row)
	return s


func _show_controls() -> void:
	for c in get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UI.label("CONTROLS", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line in controls_lines():
		box.add_child(UI.label(line))
	var back := UI.button("Back", _build, 80)
	box.add_child(back)
	await get_tree().process_frame
	back.grab_focus()


static func controls_lines() -> Array[String]:
	return [
		"Move ............ A / D  or  Left / Right",
		"Jump ............ Space (hold for a higher jump)",
		"Claw attack ..... J  or  Left Mouse  (X)",
		"Pounce .......... K  or  Right Mouse  (C / Shift)",
		"Upward pounce ... hold W / Up while pouncing",
		"Interact ........ E  (doors, cages, levers, chests)",
		"Pause ........... Esc  or  P",
		"Gamepad ......... stick/d-pad, A jump, X claw, B pounce,",
		"                  Y interact, Start pause",
	]


func _ask_reset() -> void:
	for c in get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UI.label("RESET ALL PROGRESS?", 20, UI.C_BAD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Coins, upgrades, rescued cats and unlocked levels\nwill be erased. Settings are kept. This cannot be undone.", 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UI.button("No, keep it", _build, 110)
	row.add_child(no)
	row.add_child(UI.button("Yes, reset", func() -> void:
		Progress.reset_progress()
		reset_requested.emit()
		_build(), 110))
	box.add_child(row)
	await get_tree().process_frame
	no.grab_focus()
