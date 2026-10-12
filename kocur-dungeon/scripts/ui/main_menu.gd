extends Control
## Main menu: Continue, New Game, Level Select, Upgrades, Settings, Credits, Quit.
## Every button here leads somewhere real; options that need a save are
## disabled until one exists.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Sprites := preload("res://scripts/fx/sprites.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")

const INTRO_TEXT := [
	"Deep under the old city lies a dungeon of moss, fire, ice and shadow.",
	"The white-cat clan of the Pale King rules it - and last night the clan stole away ten black cats from your alley.",
	"You are Kocur: small, quick, and very, very angry.",
	"Sharpen your claws. Bring them home.",
]

var ui_root: Control
var _center: CenterContainer
var _bg_far: TextureRect
var _bg_mid: TextureRect
var _t := 0.0
var screen := ""  ## "main", "settings", "credits", "confirm", "intro"
var buttons := {}  ## name -> Button (used by tests)


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_build_background()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)
	Audio.play_music("menu")
	show_main()


func _build_background() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.05, 0.04, 0.09)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	_bg_far = _bg_layer("bg_r1_far.png", 0.75)
	_bg_mid = _bg_layer("bg_r1_mid.png", 1.0)
	var shade := UI.dim_rect(0.35)
	add_child(shade)
	# The hero, sitting on the ledge under the title.
	var cat := Sprites.make_sprite("hero", "idle")
	cat.position = Vector2(512, 300)
	cat.scale = Vector2(2, 2)
	cat.flip_h = true
	add_child(cat)
	var ground := ColorRect.new()
	ground.color = Color(0.1, 0.08, 0.14)
	ground.position = Vector2(440, 316)
	ground.size = Vector2(200, 44)
	add_child(ground)


func _bg_layer(file: String, alpha: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Sprites.texture(file)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 180)
	r.scale = Vector2(2, 2)
	r.modulate.a = alpha
	add_child(r)
	return r


func _process(delta: float) -> void:
	_t += delta
	if _bg_far:
		_bg_far.position.x = -fmod(_t * 4.0, 640.0)
		_bg_mid.position.x = -fmod(_t * 9.0, 640.0)


func _clear() -> void:
	if _center:
		_center.queue_free()
		_center = null
	buttons.clear()


func show_main() -> void:
	_clear()
	screen = "main"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var title := UI.label("KOCUR DUNGEON", 30, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(title)
	box.add_child(UI.label("a Kocur Studios game", 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	var has := Progress.has_progress()
	var cont := _add(box, "continue", "Continue", _on_continue)
	cont.disabled = not has
	if has:
		cont.tooltip_text = "Return to camp"
	_add(box, "new", "New Game", _on_new_game)
	_add(box, "levels", "Level Select", func() -> void: _go_camp_tab("levels")).disabled = not has
	_add(box, "upgrades", "Upgrades", func() -> void: _go_camp_tab("upgrades")).disabled = not has
	_add(box, "settings", "Settings", show_settings)
	_add(box, "credits", "Credits", show_credits)
	_add(box, "quit", "Quit", func() -> void: get_tree().quit())
	if has:
		var info := UI.label("%d / %d levels cleared   %d cats rescued" % [_cleared(), LevelCatalog.count(),
			Progress.data["rescued"].size()], 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(info)
	box.add_child(UI.label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 10,
		Color(UI.C_DIM, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	_center = UI.center(ui_root, box)
	await get_tree().process_frame
	if not is_instance_valid(cont):
		return
	(cont if has else buttons["new"]).grab_focus()


func _add(box: Container, key: String, text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, 150)
	b.name = key
	box.add_child(b)
	buttons[key] = b
	return b


func _cleared() -> int:
	var n := 0
	for lv in LevelCatalog.LEVELS:
		if Progress.is_completed(lv["id"]):
			n += 1
	return n


func _on_continue() -> void:
	if Progress.has_progress():
		_go_camp_tab("levels")


func _go_camp_tab(tab: String) -> void:
	Transition.camp_tab = tab
	Transition.go_camp()


func _on_new_game() -> void:
	if Progress.has_progress():
		_confirm("Start a new game? Your current save (coins, upgrades, rescued cats) will be overwritten.",
			func() -> void: start_new_game())
	else:
		start_new_game()


func start_new_game() -> void:
	Progress.new_game()
	show_intro()


func show_intro() -> void:
	_clear()
	screen = "intro"
	var panel := UI.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UI.label("THE STOLEN NINE... AND ONE", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line: String in INTRO_TEXT:
		var l := UI.label(line, 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(380, 0)
		box.add_child(l)
	var go := UI.button("Begin", func() -> void:
		Progress.data["intro_seen"] = true
		Progress.save_game()
		Transition.go_level("1-1"), 160)
	buttons["begin"] = go
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(go)
	box.add_child(row)
	_center = UI.center(ui_root, panel)
	await get_tree().process_frame
	if is_instance_valid(go):
		go.grab_focus()


func show_settings() -> void:
	_clear()
	screen = "settings"
	var sp := SettingsPanel.new()
	sp.allow_reset = true
	sp.closed.connect(show_main)
	sp.reset_requested.connect(func() -> void:
		Progress.reset_progress()
		show_main())
	_center = UI.center(ui_root, sp)


func show_credits() -> void:
	_clear()
	screen = "credits"
	var panel := UI.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)
	box.add_child(UI.label("CREDITS", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for line: String in credits_lines():
		var l := UI.label(line, 10, UI.C_TEXT if not line.ends_with(":") else UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(340, 0)
		box.add_child(l)
	var back := UI.button("Back", show_main, 100)
	buttons["back"] = back
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(back)
	box.add_child(row)
	_center = UI.center(ui_root, panel)
	await get_tree().process_frame
	if is_instance_valid(back):
		back.grab_focus()


static func credits_lines() -> Array[String]:
	return [
		"A game by Kocur Studios",
		"",
		"Design, code, pixel art, music and sound:",
		"Kocur Studios (made with Claude Code)",
		"",
		"All art, sounds, music and the pixel font were",
		"generated from scratch for this game.",
		"",
		"Built with the Godot Engine (MIT licence)",
		"godotengine.org/license",
		"",
		"Thank you for playing!",
	]


func _confirm(text: String, yes: Callable) -> void:
	_clear()
	screen = "confirm"
	var panel := UI.panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := UI.label(text, 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(280, 0)
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UI.button("No", show_main, 80)
	buttons["no"] = no
	row.add_child(no)
	var yes_b := UI.button("Yes", yes, 80)
	buttons["yes"] = yes_b
	row.add_child(yes_b)
	box.add_child(row)
	_center = UI.center(ui_root, panel)
	await get_tree().process_frame
	if is_instance_valid(no):
		no.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if screen in ["credits", "confirm"]:
			Audio.play("ui_back", -4.0)
			show_main()
			get_viewport().set_input_as_handled()
