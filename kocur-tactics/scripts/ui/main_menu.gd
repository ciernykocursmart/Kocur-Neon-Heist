extends Control
## Main menu: continue / new campaign, mission select, roster, upgrades,
## challenges, settings, credits, reset progress and quit.

const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var buttons := {}
var modal_layer: Control
var _t := 0.0
var _parade: Array[Sprite2D] = []


func _ready() -> void:
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_backdrop()
	var title := UI.label("KOCUR TACTICS", 64, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Color("3a2050"))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 80)
	add_child(title)
	var sub := UI.label("Defend Shadowwood Valley from the White Crown Legion", 18, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 122)
	sub.size = Vector2(1280, 28)
	add_child(sub)
	var col := UI.vbox(8)
	col.position = Vector2(490, 190)
	col.size = Vector2(300, 460)
	add_child(col)
	var has := Campaign.has_progress()
	_add(col, "continue", "Continue Campaign", func() -> void: Transition.go_campaign(), has)
	_add(col, "new", "New Campaign", _on_new, true)
	_add(col, "missions", "Mission Select", func() -> void: Transition.go_campaign("missions"), has)
	_add(col, "roster", "Roster", func() -> void: Transition.go_campaign("roster"), has)
	_add(col, "upgrades", "Upgrades", func() -> void: Transition.go_campaign("upgrades"), has)
	_add(col, "challenges", "Tactical Challenges", func() -> void: Transition.go_campaign("challenges"), has)
	_add(col, "settings", "Settings", func() -> void: SettingsPanel.open(modal_layer), true)
	_add(col, "credits", "Credits", _on_credits, true)
	_add(col, "reset", "Reset Progress", _on_reset, has)
	_add(col, "quit", "Quit", func() -> void: get_tree().quit(), true)
	var ver := UI.label("v%s  -  Kocur Studios" % ProjectSettings.get_setting("application/config/version"), 13, UI.TEXT_DIM)
	ver.position = Vector2(12, 694)
	add_child(ver)
	if has:
		var info := UI.label("Progress: %d/12 missions  |  %s" % [Campaign.completed_count(),
			UD.DIFFICULTY_INFO[Campaign.difficulty()]["name"]], 14, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		info.position = Vector2(780, 694)
		info.size = Vector2(488, 20)
		add_child(info)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	Audio.play_music("menu")
	(buttons["continue"] if has else buttons["new"]).call_deferred("grab_focus")


func _add(parent: Control, key: String, text: String, cb: Callable, enabled: bool) -> void:
	var bt := UI.button(text, cb, 300, 18)
	bt.name = key
	bt.disabled = not enabled
	bt.custom_minimum_size.y = 38
	parent.add_child(bt)
	buttons[key] = bt


func _build_backdrop() -> void:
	# a little standoff: heroes on the left, the Legion on the right
	var heroes := ["shadowblade", "guardian", "ranger", "mender"]
	var foes := ["recruit", "guard", "archer", "mage", "stalker"]
	for i in heroes.size():
		_parade.append(_sprite(heroes[i], Vector2(130 + i * 70, 560 + (i % 2) * 40), false))
	for i in foes.size():
		_parade.append(_sprite(foes[i], Vector2(1150 - i * 70, 560 + (i % 2) * 40), true))
	_sprite("king", Vector2(1080, 300), true).scale = Vector2(6, 6)


func _sprite(kind: String, at: Vector2, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.tex("unit_" + kind)
	s.hframes = 2
	s.scale = Vector2(4, 4)
	s.position = at
	s.flip_h = flip
	s.modulate = Color(1, 1, 1, 0.9)
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	for i in _parade.size():
		_parade[i].frame = int(_t * 1.5 + i * 0.37) % 2


func _on_new() -> void:
	if Campaign.has_progress():
		UI.confirm(modal_layer, "Start a NEW campaign? Your current progress will be erased.", _choose_difficulty, "Start New")
	else:
		_choose_difficulty()


func _choose_difficulty() -> void:
	var m := UI.modal(modal_layer, 560)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "Difficulty"
	v.add_child(UI.label("Choose difficulty", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.wrap_label("You can change it later in Settings. It never locks content.", 14, UI.TEXT_DIM))
	for d: String in UD.DIFFICULTIES:
		var info: Dictionary = UD.DIFFICULTY_INFO[d]
		var dd := d
		var bt := UI.button("%s - %s" % [info["name"], info["desc"]], func() -> void:
			dim.queue_free()
			Campaign.new_campaign(dd)
			Transition.go_campaign("missions"), 520, 15)
		bt.name = "Diff_" + d
		v.add_child(bt)
		if d == "normal":
			bt.call_deferred("grab_focus")
	v.add_child(UI.button("Cancel", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 160))


func _on_reset() -> void:
	UI.confirm(modal_layer, "Reset ALL campaign progress (missions, heroes, upgrades, records)? This cannot be undone.", func() -> void:
		Campaign.reset_progress()
		get_tree().reload_current_scene(), "Reset")


func _on_credits() -> void:
	var m := UI.modal(modal_layer, 620)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("CREDITS", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.wrap_label("Kocur Tactics - a Kocur Studios game.", 17))
	v.add_child(UI.wrap_label("Game design, programming, tactical AI, pixel art, sound effects and music were created originally for this game. All art and audio are generated by the project's own tools (tools/gen_art.py, tools/gen_audio.py).", 14))
	v.add_child(UI.wrap_label("Made with Godot Engine 4.3 (MIT licence, (c) Juan Linietsky, Ariel Manzur and contributors). See LICENSE_GODOT.txt.", 14, UI.TEXT_DIM))
	v.add_child(UI.wrap_label("Thanks for playing, commander. The valley's cats salute you!", 15, UI.HERO))
	var close := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 160)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	close.call_deferred("grab_focus")
