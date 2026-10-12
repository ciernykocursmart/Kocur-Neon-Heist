extends CanvasLayer
## Pause menu: resume, restart, settings, return to camp / main menu.

const UI := preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var level: Node
var root: Control
var is_open := false
var _center: CenterContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = UI.root_control()
	root.visible = false
	add_child(root)
	root.add_child(UI.dim_rect(0.55))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open:
			close()
		elif can_open():
			open()
		get_viewport().set_input_as_handled()


func can_open() -> bool:
	return level != null and not level.finished and not level.player.is_dead() and not level.overlays.is_busy()


func open() -> void:
	is_open = true
	get_tree().paused = true
	root.visible = true
	Audio.play("ui_ok", -6.0)
	_show_main()


func close() -> void:
	is_open = false
	get_tree().paused = false
	root.visible = false
	if _center:
		_center.queue_free()
		_center = null


func _clear() -> void:
	if _center:
		_center.queue_free()
	_center = null


func _show_main() -> void:
	_clear()
	var panel := UI.panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UI.label("PAUSED", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label(level.meta.get("name", ""), 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UI.button("Resume", close, 180)
	box.add_child(resume)
	box.add_child(UI.button("Restart from Checkpoint", func() -> void:
		close()
		level.retry_from_checkpoint(), 180))
	box.add_child(UI.button("Restart Level", func() -> void:
		_confirm("Restart this level? Items found this run will be lost.", func() -> void:
			close()
			level.restart_level()), 180))
	box.add_child(UI.button("Settings", _show_settings, 180))
	box.add_child(UI.button("Return to Camp", func() -> void:
		_confirm("Return to camp? Progress in this level and your blessings will be lost.", func() -> void:
			close()
			Transition.go_camp()), 180))
	box.add_child(UI.button("Main Menu", func() -> void:
		_confirm("Quit to the main menu? Progress in this level will be lost.", func() -> void:
			close()
			Transition.go_menu()), 180))
	_center = UI.center(root, panel)
	await get_tree().process_frame
	resume.grab_focus()


func _show_settings() -> void:
	_clear()
	var sp := SettingsPanel.new()
	sp.closed.connect(_show_main)
	_center = UI.center(root, sp)


func _confirm(text: String, yes: Callable) -> void:
	_clear()
	var panel := UI.panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := UI.label(text, 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(260, 0)
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UI.button("No", _show_main, 80)
	row.add_child(no)
	row.add_child(UI.button("Yes", yes, 80))
	box.add_child(row)
	_center = UI.center(root, panel)
	await get_tree().process_frame
	no.grab_focus()
