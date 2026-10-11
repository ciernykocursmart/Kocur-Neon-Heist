extends CanvasLayer
## Pause menu: resume, restart, settings, controls and quit (with a warning
## when race or cup progress would be lost).

var race: Race
var root: Control
var _menu: VBoxContainer
var _confirm: Control
var _overlay: Control


func setup(r: Race) -> void:
	race = r
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.visible = false
	add_child(root)
	UI.dim_backdrop(root, 0.55)
	var p := UI.panel(Vector2(440, 0))
	UI.center(root, p)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	p.add_child(_menu)
	var t := UI.label("PAUSED", 52, UI.ACCENT, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(t)
	var info := UI.label(TrackCatalog.track_name(race.track.def["id"]), 22, UI.MUTED, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(info)
	_menu.add_child(UI.button("Resume", resume))
	_menu.add_child(UI.button("Restart Race", func(): _ask("Restart this race?", "Your current race progress will be lost.", race.restart)))
	_menu.add_child(UI.button("Settings", func(): _open(preload("res://scripts/ui/settings_panel.gd").new())))
	_menu.add_child(UI.button("Controls", func(): _open(preload("res://scripts/ui/controls_panel.gd").new())))
	var quit_text := "Quit Grand Prix" if race.mode == "grand_prix" else "Quit to Menu"
	_menu.add_child(UI.button(quit_text, func():
		var detail := "Points from this Grand Prix will be lost." if race.mode == "grand_prix" else "This race will not be recorded."
		_ask("Leave the race?", detail, func(): Game.to_menu())))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (root.visible and event.is_action_pressed("ui_cancel")):
		if _overlay != null:
			return
		get_viewport().set_input_as_handled()
		if _confirm != null:
			_confirm.queue_free()
			_confirm = null
			_menu.visible = true
			UI.focus_first(_menu)
			return
		if root.visible:
			resume()
		elif race.state != Race.State.RESULTS:
			pause()


func _notification(what: int) -> void:
	# Auto-pause when the window loses focus mid-race.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and race and race.state == Race.State.RACING and not root.visible:
		if DisplayServer.get_name() != "headless":
			pause()


func pause() -> void:
	root.visible = true
	get_tree().paused = true
	Audio.play("ui_pause")
	UI.focus_first(_menu)


func resume() -> void:
	root.visible = false
	get_tree().paused = false


func _open(panel: Control) -> void:
	_overlay = panel
	_menu.visible = false
	root.add_child(panel)
	panel.tree_exited.connect(func():
		_overlay = null
		if is_instance_valid(_menu):
			_menu.visible = true
			UI.focus_first(_menu))


func _ask(question: String, detail: String, yes: Callable) -> void:
	_menu.visible = false
	var p := UI.panel(Vector2(520, 0))
	_confirm = UI.center(root, p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var q := UI.label(question, 34, UI.TEXT, true, 6)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var d := UI.label(detail, 20, UI.MUTED)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var no := UI.button("No", func():
		_confirm.queue_free()
		_confirm = null
		_menu.visible = true
		UI.focus_first(_menu), 180)
	h.add_child(no)
	h.add_child(UI.button("Yes", func():
		get_tree().paused = false
		yes.call(), 180))
	no.grab_focus()
