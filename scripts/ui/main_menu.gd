extends Control
## Title screen: Continue / New Game / Settings / Quit.

var _menu: VBoxContainer
var _settings: SettingsPanel
var _confirm: ConfirmationDialog
var _continue_btn: Button


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
	_menu.add_theme_constant_override("separation", 12)
	center.add_child(_menu)
	var title := UITheme.make_title("KOCUR", 92, Palette.CYAN)
	_menu.add_child(title)
	var sub := UITheme.make_title("N E O N   H E I S T", 30, Palette.MAGENTA)
	_menu.add_child(sub)
	var tag := UITheme.make_label("a cybernetic cat. a corporate megastructure. one job at a time.", 15, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_menu.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	_menu.add_child(spacer)

	var has_save := GameState.has_save()
	_continue_btn = UITheme.make_button("CONTINUE", _on_continue, 300)
	_continue_btn.disabled = not has_save
	_menu.add_child(_continue_btn)
	if has_save and GameState.load_game():
		_continue_btn.text = "CONTINUE  (mission %d, %d CR)" % [GameState.mission_index, GameState.credits]
	for b in [UITheme.make_button("NEW GAME", _on_new_game, 300), UITheme.make_button("SETTINGS", _on_settings, 300), UITheme.make_button("QUIT", _on_quit, 300)]:
		_menu.add_child(b)
	for c in _menu.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_settings.visible = false
		_menu.visible = true)
	center.add_child(_settings)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "New Game"
	_confirm.dialog_text = "Start a new campaign?\nYour current progress will be overwritten."
	_confirm.confirmed.connect(_start_new_game)
	add_child(_confirm)

	var version := UITheme.make_label("v%s  |  made with Godot  |  all art & audio procedurally generated" % ProjectSettings.get_setting("application/config/version", "0.1"), 12, Palette.DIM)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 14
	version.offset_top = -30
	version.offset_right = 900
	version.offset_bottom = -8
	add_child(version)

	# Intro animation.
	_menu.modulate.a = 0.0
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.8)
	(_continue_btn if has_save else _menu.get_child(5)).call_deferred("grab_focus")
	Sfx.play_music("music")
	Sfx.set_music_pitch(0.9)


func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/hideout.tscn")


func _on_new_game() -> void:
	if GameState.has_save():
		_confirm.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _on_quit() -> void:
	get_tree().quit()
