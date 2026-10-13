extends CanvasLayer
## Menus shown on top of a level: pause, game over (continue / restart /
## menu) and the end-of-street results. Runs while the tree is paused.

const UI = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const Levels = preload("res://scripts/data/levels.gd")

var level: Node
var root: Control
var pause_menu: Control = null
var current: Control = null
var opened_frame := -1


func setup(lvl: Node) -> void:
	level = lvl
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)


func _process(_delta: float) -> void:
	if pause_menu and is_instance_valid(pause_menu) and Engine.get_process_frames() > opened_frame and Input.is_action_just_pressed("pause"):
		# Esc closes an open sub-window first, then resumes.
		if root.get_child_count() > 1:
			root.get_child(root.get_child_count() - 1).queue_free()
		else:
			resume()


func is_open() -> bool:
	return current != null and is_instance_valid(current)


# ------------------------------------------------------------------ pause
func open_pause() -> void:
	if is_open():
		return
	get_tree().paused = true
	opened_frame = Engine.get_process_frames()
	Audio.play("ui_ok")
	var m := UI.modal(root, 420)
	pause_menu = m[0]
	current = pause_menu
	pause_menu.name = "PauseMenu"
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("PAUSED", 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Street %d - %s" % [int(level.data["num"]), level.data["name"]], 16, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var resume_b := UI.button("Resume", resume, 300, 20)
	resume_b.name = "Resume"
	v.add_child(resume_b)
	var cp := UI.button("Restart from checkpoint (-1 life)", func() -> void:
		Game.lives -= 1
		_reload(), 300, 18)
	cp.name = "RestartCheckpoint"
	cp.disabled = Game.lives <= 1 or level.flow != "play"
	v.add_child(cp)
	var rl := UI.button("Restart street", func() -> void:
		UI.confirm(root, "Restart this street from the beginning? Score from this street is lost.", func() -> void:
			Game.restart_level()
			_reload(), "Restart"), 300, 18)
	rl.name = "RestartLevel"
	v.add_child(rl)
	var st := UI.button("Settings", func() -> void: SettingsPanel.open(root, true), 300, 18)
	st.name = "Settings"
	v.add_child(st)
	var ct := UI.button("Controls", func() -> void: SettingsPanel.open_controls(root), 300, 18)
	ct.name = "Controls"
	v.add_child(ct)
	var mm := UI.button("Main menu", func() -> void:
		UI.confirm(root, "Quit to the main menu? Your progress is saved at the start of this street.", func() -> void:
			Transition.go_menu(), "Quit"), 300, 18)
	mm.name = "MainMenu"
	v.add_child(mm)
	UI.focus(resume_b)


func resume() -> void:
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	for c in root.get_children():
		c.queue_free()
	pause_menu = null
	current = null
	get_tree().paused = false
	Audio.play("ui_back")


func _reload() -> void:
	Transition.go_level()


# ------------------------------------------------------------------ game over
func open_game_over() -> void:
	var m := UI.modal(root, 520)
	current = m[0]
	current.name = "GameOver"
	current.modulate.a = 0.0
	create_tween().tween_property(current, "modulate:a", 1.0, 0.8).set_delay(0.8)
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("GAME OVER", 40, UI.ENEMY, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("The White Crown gang laughs... for now.", 16, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Score %d" % Game.score, 20, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var can := Game.can_continue()
	var left := "unlimited" if Game.continues_left < 0 else str(Game.continues_left)
	var c := UI.button("Continue from checkpoint (%s left)" % left, func() -> void:
		if Game.use_continue():
			_reload(), 400, 20)
	c.name = "Continue"
	c.disabled = not can
	v.add_child(c)
	var r := UI.button("Restart street", func() -> void:
		Game.restart_level()
		_reload(), 400, 18)
	r.name = "RestartLevel"
	v.add_child(r)
	var q := UI.button("Main menu", func() -> void: Transition.go_menu(), 400, 18)
	q.name = "MainMenu"
	v.add_child(q)
	UI.focus((c if can else r))


# ------------------------------------------------------------------ results
func open_results(res: Dictionary) -> void:
	var m := UI.modal(root, 640)
	current = m[0]
	current.name = "Results"
	current.color = Color(0, 0, 0, 0.45)
	var v: VBoxContainer = m[1]
	var last := Game.level_index >= Levels.count() - 1
	v.add_child(UI.label("STREET %d CLEAR!" % int(level.data["num"]), 34, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(String(level.data["name"]), 18, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var t: float = res["time"]
	var rows := [
		["Enemies defeated", str(res["enemies"])],
		["Damage taken", str(res["damage"])],
		["Food collected", "%d / %d" % [res["food"], res["food_total"]]],
		["Golden fish", "FOUND!" if res["golden"] else "not found"],
		["Best combo", "%d hits" % res["best_combo"]],
		["Time", "%d:%02d" % [int(t) / 60, int(t) % 60]],
		["Lives lost / continues", "%d / %d" % [res["deaths"], res["continues"]]],
		["Time bonus", "+%d" % res["time_bonus"]],
		["Health bonus", "+%d" % res["hp_bonus"]],
	]
	if int(res["nodmg_bonus"]) > 0:
		rows.append(["No damage bonus", "+%d" % res["nodmg_bonus"]])
	rows.append(["Challenge: " + String(res["challenge_text"]), "DONE!" if res["challenge"] else "-"])
	for row in rows:
		grid.add_child(UI.label(String(row[0]), 17))
		grid.add_child(UI.label(String(row[1]), 17, UI.ACCENT if String(row[1]) in ["FOUND!", "DONE!"] else UI.TEXT))
	var rec: Dictionary = res.get("record", {})
	v.add_child(UI.label("Street score  %d   %s" % [res["level_score"], "NEW BEST!" if rec.get("new_best", false) else ""], 22, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Total score  %d" % res["total_score"], 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("RANK  %s" % res["rank"], 40, Color("ff8ab8"), HORIZONTAL_ALIGNMENT_CENTER))
	if rec.get("unlocked_next", false):
		v.add_child(UI.label("Street %d unlocked in Level Select!" % (Game.level_index + 2), 16, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	var row2 := UI.hbox(14)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row2)
	var cont := UI.button("See the ending" if last else "Next street", func() -> void:
		if last:
			Transition.go_ending()
		else:
			Game.begin_level(Game.level_index + 1)
			Game.save_run_position()
			Transition.go_level(), 190, 18)
	cont.name = "Continue"
	row2.add_child(cont)
	var rp := UI.button("Replay street", func() -> void:
		Game.restart_level()
		Transition.go_level(), 170, 18)
	rp.name = "Replay"
	row2.add_child(rp)
	var mm := UI.button("Main menu", func() -> void: Transition.go_menu(), 150, 18)
	mm.name = "MainMenu"
	row2.add_child(mm)
	UI.focus(cont)
