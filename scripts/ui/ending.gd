extends Control
## Campaign epilogue + credits roll. Also reachable from the main menu
## (credits only, when the campaign is not finished yet).

var _box: VBoxContainer
var _credits: VBoxContainer
var _skip_hint: Label
var _done := false


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	UITheme.set_crosshair_cursor(false)
	var bg := NeonBackground.new()
	bg.modulate = Color(0.5, 0.5, 0.65)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	_box.custom_minimum_size = Vector2(760, 0)
	center.add_child(_box)

	_skip_hint = UITheme.make_label("[ESC] skip", 13, Palette.DIM)
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -160
	_skip_hint.offset_top = -30
	_skip_hint.offset_right = -14
	_skip_hint.offset_bottom = -8
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_skip_hint)

	Sfx.play_music("ending")
	Sfx.set_music_pitch(1.0)
	if GameState.campaign_complete:
		_run_epilogue()
	else:
		_run_credits()


func _run_epilogue() -> void:
	var title := UITheme.make_title("EPILOGUE", 40, Palette.MAGENTA)
	_box.add_child(title)
	for paragraph in Campaign.ENDING:
		var l := UITheme.make_label(paragraph, 19, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(760, 0)
		l.modulate.a = 0.0
		_box.add_child(l)
	var i := 0
	for c in _box.get_children():
		if c is Label and c != title:
			var tw := create_tween()
			tw.tween_interval(0.8 + i * 3.2)
			tw.tween_property(c, "modulate:a", 1.0, 1.2)
			i += 1
	await get_tree().create_timer(0.8 + i * 3.2 + 3.0).timeout
	if not _done:
		_run_credits()


func _run_credits() -> void:
	if _credits != null:
		return
	for c in _box.get_children():
		c.queue_free()
	_credits = VBoxContainer.new()
	_credits.add_theme_constant_override("separation", 18)
	_box.add_child(_credits)
	_credits.add_child(UITheme.make_title("KOCUR", 72, Palette.CYAN))
	_credits.add_child(UITheme.make_title("N E O N   H E I S T", 26, Palette.MAGENTA))
	for row in Campaign.CREDITS.slice(1):
		if row[0] != "":
			_credits.add_child(UITheme.make_label(String(row[0]).to_upper(), 14, Palette.MAGENTA, HORIZONTAL_ALIGNMENT_CENTER))
		_credits.add_child(UITheme.make_label(row[1], 18, Palette.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	if GameState.campaign_complete:
		var s := GameState.stats
		_credits.add_child(UITheme.make_label("Missions %d  |  Kills %d  |  Takedowns %d  |  Ghost runs %d  |  Deaths %d" % [int(s.get("missions_completed", 0)), int(s.get("kills", 0)), int(s.get("takedowns", 0)), int(s.get("ghost_runs", 0)), int(s.get("deaths", 0))], 14, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		_credits.add_child(UITheme.make_label("ENDLESS HEIST UNLOCKED", 22, Palette.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	var btn := UITheme.make_button("MAIN MENU", _finish, 260)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_credits.add_child(btn)
	btn.call_deferred("grab_focus")
	_credits.modulate.a = 0.0
	create_tween().tween_property(_credits, "modulate:a", 1.0, 1.0)
	_skip_hint.visible = false


func _finish() -> void:
	_done = true
	Transition.change_scene("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _credits == null:
			_done = true
			_run_credits()
		else:
			_finish()
