class_name PauseMenu
extends CanvasLayer
## Pause overlay: resume, restart, settings, abort to hideout, main menu.

var game: Game
var _root: Control
var _menu: VBoxContainer
var _settings: SettingsPanel


func setup(g: Game) -> void:
	game = g
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	center.add_child(_menu)
	_menu.add_child(UITheme.make_title("PAUSED", 48, Palette.MAGENTA))
	_menu.add_child(UITheme.make_label(String(game.def["name"]), 16, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_menu.add_child(UITheme.make_button("RESUME", close))
	_menu.add_child(UITheme.make_button("RESTART MISSION", func(): game.restart_mission()))
	_menu.add_child(UITheme.make_button("SETTINGS", _open_settings))
	_menu.add_child(UITheme.make_button("ABORT TO HIDEOUT", func(): game.go_to_hideout()))
	_menu.add_child(UITheme.make_button("MAIN MENU", func(): game.go_to_menu()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	center.add_child(_settings)
	_root.visible = false


func open() -> void:
	if _root.visible:
		return
	_root.visible = true
	_menu.visible = true
	_settings.visible = false
	get_tree().paused = true
	UITheme.set_crosshair_cursor(false)
	(_menu.get_child(2) as Button).grab_focus()


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	UITheme.set_crosshair_cursor(true)


func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings.visible:
			_close_settings()
		else:
			close()
