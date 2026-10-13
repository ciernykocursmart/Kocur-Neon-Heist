extends Control
## Main menu: New Game (difficulty), Continue, Level Select, Settings,
## Controls, Credits, Reset progress, Quit. Animated neon street backdrop.

const UI = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const Levels = preload("res://scripts/data/levels.gd")
const B = preload("res://scripts/data/balance.gd")

var buttons := {}
var backdrop: Node2D
var t := 0.0


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.bot_input = null
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	var title := TitleArt.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var col := UI.vbox(8)
	col.position = Vector2(80, 300)
	col.custom_minimum_size = Vector2(320, 0)
	add_child(col)
	_add(col, "NewGame", "New Game", _new_game)
	_add(col, "Continue", "Continue", _continue)
	_add(col, "LevelSelect", "Level Select", _level_select)
	_add(col, "Settings", "Settings", func() -> void: SettingsPanel.open(self))
	_add(col, "Controls", "Controls", func() -> void: SettingsPanel.open_controls(self))
	_add(col, "Credits", "Credits", _credits)
	_add(col, "Reset", "Reset Progress", _reset)
	_add(col, "Quit", "Quit", func() -> void: get_tree().quit())
	var info := UI.label("", 15, UI.TEXT_DIM)
	info.name = "Info"
	info.position = Vector2(80, 680)
	add_child(info)
	_refresh()
	Game.progress_changed.connect(_refresh)
	Audio.play_music("menu")
	UI.focus((buttons["Continue"] as Button if not buttons["Continue"].disabled else buttons["NewGame"] as Button))


func _add(col: VBoxContainer, id: String, text: String, cb: Callable) -> void:
	var b := UI.button(text, cb, 320, 22)
	b.name = id
	col.add_child(b)
	buttons[id] = b


func _refresh() -> void:
	if not is_inside_tree():
		return
	buttons["Continue"].disabled = not Game.has_progress()
	buttons["LevelSelect"].disabled = int(Game.data["unlocked"]) <= 1 and not Game.is_completed(0)
	buttons["Reset"].disabled = not Game.has_progress() and not bool(Game.data["campaign_complete"])
	var info: Label = get_node("Info")
	var parts: Array = []
	if Game.has_progress():
		parts.append("Continue: Street %d - %s" % [Game.continue_level() + 1, Levels.get_level(Game.continue_level())["name"]])
	if bool(Game.data["campaign_complete"]):
		parts.append("Campaign complete x%d  -  best %d" % [int(Game.data["completions"]), int(Game.data["best_campaign_score"])])
	info.text = "     ".join(parts)


func _process(delta: float) -> void:
	t += delta


func _new_game() -> void:
	var m := UI.modal(self, 560)
	var dim: Control = m[0]
	dim.name = "DifficultyWindow"
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("CHOOSE DIFFICULTY", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var first: Button = null
	for d: String in B.DIFFICULTIES:
		var info: Dictionary = B.DIFFICULTY_INFO[d]
		var b := UI.button(String(info["name"]), func() -> void:
			dim.queue_free()
			_start_new(d), 0, 22)
		b.name = "Diff_" + d
		v.add_child(b)
		v.add_child(UI.wrap_label(String(info["desc"]), 14, UI.TEXT_DIM))
		if d == Game.difficulty:
			first = b
	var c := UI.button("Back", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 0, 18)
	v.add_child(c)
	if Game.has_progress():
		v.add_child(UI.wrap_label("Starting a new game keeps your unlocked streets, best scores and medals.", 13, UI.TEXT_DIM))
	UI.focus(first)


func _start_new(d: String) -> void:
	Game.new_campaign(d)
	Transition.go_level()


func _continue() -> void:
	Game.continue_campaign()
	Transition.go_level()


func _level_select() -> void:
	var m := UI.modal(self, 820)
	var dim: Control = m[0]
	dim.name = "LevelSelectWindow"
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("LEVEL SELECT", 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Difficulty: %s   (change it in Settings)" % B.DIFFICULTY_INFO[Game.difficulty]["name"], 14, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var first: Button = null
	for i in Levels.count():
		var lv := Levels.get_level(i)
		var row := UI.hbox(12)
		v.add_child(row)
		var unlocked := Game.is_unlocked(i)
		var b := UI.button("%d. %s" % [i + 1, lv["name"]] if unlocked else "%d. ????? (locked)" % (i + 1), func() -> void:
			dim.queue_free()
			Game.play_level(i)
			Transition.go_level(), 330, 18)
		b.name = "Level%d" % (i + 1)
		b.disabled = not unlocked
		row.add_child(b)
		var details := ""
		if unlocked:
			details = "Best %d" % Game.best_score(i)
			if Game.best_rank(i) != "":
				details += "   Rank %s" % Game.best_rank(i)
			details += "   %s" % ("Golden fish: yes" if Game.has_golden(i) else "Golden fish: -")
			details += "   %s" % ("Challenge: DONE" if Game.has_challenge(i) else "Challenge: " + String(lv["challenge"]["text"]))
		var l := UI.label(details, 14, UI.TEXT if Game.is_completed(i) else UI.TEXT_DIM)
		l.custom_minimum_size.x = 440
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		if unlocked and first == null:
			first = b
	var c := UI.button("Back", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 160, 18)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)
	UI.focus(first)


func _credits() -> void:
	var m := UI.modal(self, 640)
	var dim: Control = m[0]
	dim.name = "CreditsWindow"
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("CREDITS", 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	for line in [
		"STREETS OF KOCUR  v1.0.0",
		"A Kocur Studios game",
		"",
		"Design, code, art, sound and music: Kocur Studios (built with Claude Code)",
		"All characters, sprites, stages, sound effects and music are original",
		"and generated for this game. No third-party assets.",
		"",
		"Made with the Godot Engine 4.3 (MIT licence, see LICENSE_GODOT.txt)",
		"",
		"Thanks for playing! Feed your local black cat.",
	]:
		v.add_child(UI.label(line, 16, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var c := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 160, 18)
	c.name = "Close"
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)
	UI.focus(c)


func _reset() -> void:
	UI.confirm(self, "Reset ALL progress? Unlocked streets, best scores, medals and the saved run will be erased. Settings are kept.", func() -> void:
		Game.reset_progress()
		_refresh()
		buttons["NewGame"].grab_focus(), "Reset everything")


## Animated neon street behind the menu, with Kocur facing two gang punks.
class MenuBackdrop extends Node2D:
	const SP = preload("res://scripts/gfx/stage_painter.gd")
	const LK = preload("res://scripts/data/looks.gd")
	var painter: Node2D
	var t := 0.0

	func _ready() -> void:
		painter = SP.new()
		painter.setup("neon", 99999.0)
		add_child(painter)

	func _process(delta: float) -> void:
		t += delta
		painter.cam_x = 640.0 + t * 30.0
		painter.position.x = -(painter.cam_x - 640.0)


class TitleArt extends Control:
	const LK = preload("res://scripts/data/looks.gd")
	var t := 0.0
	var font: Font

	func _ready() -> void:
		font = ThemeDB.fallback_font

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.02, 0.08, 0.35))
		# Title logo.
		var title := "STREETS OF KOCUR"
		var y := 150.0 + sin(t * 2.0) * 3.0
		draw_string_outline(font, Vector2(0, y + 6), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 84, 22, Color("e8413c"))
		draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 84, 14, Color("1a0a20"))
		draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 84, Color("ffd23a"))
		draw_string_outline(font, Vector2(0, y + 50), "A KOCUR STUDIOS BEAT 'EM UP", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, 6, Color("1a0a20"))
		draw_string(font, Vector2(0, y + 50), "A KOCUR STUDIOS BEAT 'EM UP", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("b9a8e8"))
		# Hero vs. two gang punks on the street.
		var floor_y := 640.0
		draw_colored_polygon(CatPainter._ellipse(Vector2(820, floor_y), 60, 14), Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2(820, floor_y), 0.0, Vector2(2.3, 2.3))
		var s := sin(t * 3.2)
		CatPainter.draw_cat(self, LK.LOOKS["hero"], {"tail": t * 3.0, "arm_f": Vector2(24, -4 + s), "arm_b": Vector2(10, 6), "eyes": "angry", "mouth": "grin", "lean": 0.08, "leg_f": 0.3, "leg_b": -0.25})
		for i in 2:
			var x := 1060.0 + i * 120.0
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_colored_polygon(CatPainter._ellipse(Vector2(x, floor_y - 20 + i * 30), 40, 10), Color(0, 0, 0, 0.35))
			draw_set_transform(Vector2(x, floor_y - 20 + i * 30), 0.0, Vector2(-1.6, 1.6))
			var k := "punk" if i == 0 else "brawler"
			CatPainter.draw_cat(self, LK.LOOKS[k], {"tail": t * 3.0 + i, "arm_f": Vector2(-10, 6 + sin(t * 4.0 + i) * 3.0), "eyes": "angry", "mouth": "teeth", "lean": -0.1})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
