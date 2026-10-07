extends Control
## Title screen: Continue / New Game / Endless / Settings / Controls /
## Credits / Quit.

var _menu: VBoxContainer
var _settings: SettingsPanel
var _controls: ControlsPanel
var _confirm: ConfirmationDialog
var _continue_btn: Button
var _endless_btn: Button


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	UITheme.set_crosshair_cursor(false)
	add_child(NeonBackground.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	center.add_child(_menu)
	_menu.add_child(UITheme.make_title("KOCUR", 92, Palette.CYAN))
	_menu.add_child(UITheme.make_title("N E O N   H E I S T", 30, Palette.MAGENTA))
	_menu.add_child(UITheme.make_label("a cybernetic cat. a corporate megastructure. one job at a time.", 15, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	_menu.add_child(spacer)

	var loaded := GameState.has_save() and GameState.load_game()
	_continue_btn = UITheme.make_button("CONTINUE", _on_continue, 340)
	_continue_btn.disabled = not loaded
	if loaded:
		if GameState.is_endless():
			_continue_btn.text = "CONTINUE  (endless depth %d)" % GameState.endless_depth
		elif GameState.campaign_complete:
			_continue_btn.text = "CONTINUE  (campaign complete)"
		else:
			_continue_btn.text = "CONTINUE  (mission %d/%d)" % [GameState.mission_index, Campaign.MISSION_COUNT]
	_menu.add_child(_continue_btn)
	_menu.add_child(UITheme.make_button("NEW GAME", _on_new_game, 340))
	_endless_btn = UITheme.make_button("ENDLESS HEIST", _on_endless, 340)
	_endless_btn.disabled = not (loaded and GameState.campaign_complete)
	if _endless_btn.disabled:
		_endless_btn.text = "ENDLESS HEIST  (finish the campaign)"
		_endless_btn.add_theme_font_size_override("font_size", 16)
	_menu.add_child(_endless_btn)
	_menu.add_child(UITheme.make_button("SETTINGS", _on_settings, 340))
	_menu.add_child(UITheme.make_button("CONTROLS", _on_controls, 340))
	_menu.add_child(UITheme.make_button("CREDITS", func(): Transition.change_scene("res://scenes/ending.tscn"), 340))
	_menu.add_child(UITheme.make_button("QUIT", _on_quit, 340))
	for c in _menu.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_back_to_menu)
	center.add_child(_settings)
	_controls = ControlsPanel.new()
	_controls.visible = false
	_controls.closed.connect(_back_to_menu)
	center.add_child(_controls)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "New Game"
	_confirm.dialog_text = "Start a new campaign?\nYour current progress will be overwritten."
	_confirm.confirmed.connect(_start_new_game)
	add_child(_confirm)

	var version := UITheme.make_label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), 12, Palette.DIM)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 14
	version.offset_top = -30
	version.offset_right = 400
	version.offset_bottom = -8
	add_child(version)
	if GameState.last_load_error != "" and loaded:
		var warn := UITheme.make_label(GameState.last_load_error, 13, Palette.YELLOW)
		warn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		warn.offset_left = -520
		warn.offset_top = -30
		warn.offset_right = -14
		warn.offset_bottom = -8
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(warn)

	_menu.modulate.a = 0.0
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.8)
	(_continue_btn if loaded else _menu.get_child(5)).call_deferred("grab_focus")
	Sfx.play_music("music")
	Sfx.set_music_pitch(0.9)


func _back_to_menu() -> void:
	_settings.visible = false
	_controls.visible = false
	_menu.visible = true


func _on_continue() -> void:
	if GameState.load_game():
		Transition.change_scene("res://scenes/hideout.tscn")


func _on_new_game() -> void:
	if GameState.has_save():
		_confirm.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	Transition.change_scene("res://scenes/game.tscn")


func _on_endless() -> void:
	if GameState.load_game() and GameState.campaign_complete:
		GameState.start_endless()
		Transition.change_scene("res://scenes/hideout.tscn")


func _on_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _on_controls() -> void:
	_menu.visible = false
	_controls.visible = true


func _on_quit() -> void:
	get_tree().quit()
