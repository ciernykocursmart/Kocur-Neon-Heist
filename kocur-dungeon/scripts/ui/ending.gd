extends Control
## Ending: the cats come home. Story, completion statistics and credits.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Sprites := preload("res://scripts/fx/sprites.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")

const STORY := [
	"The Pale King's crown rolls across the marble floor.",
	"Without their king the white clan scatters into the dark, and the dungeon falls quiet.",
	"Kocur leads the way home - up through shadow, ice, fire and moss - with every friend found trailing behind.",
]

var page := 0
var _center: CenterContainer
var _root: Control
var continue_button: Button


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var far := TextureRect.new()
	far.texture = Sprites.texture("bg_r5_far.png")
	far.stretch_mode = TextureRect.STRETCH_TILE
	far.size = Vector2(320, 180)
	far.scale = Vector2(2, 2)
	far.modulate = Color(0.55, 0.5, 0.7)
	add_child(far)
	add_child(UI.dim_rect(0.4))
	# A parade of the hero and every rescued cat walking home.
	var parade := Node2D.new()
	add_child(parade)
	var hero := Sprites.make_sprite("hero", "run")
	hero.position = Vector2(560, 334)
	parade.add_child(hero)
	var x := 530.0
	for cat: String in GameData.CAT_ORDER:
		if Progress.has_cat(cat):
			var s := AnimatedSprite2D.new()
			s.sprite_frames = Sprites.captive_frames(int(GameData.CATS[cat]["color"]))
			s.play("default")
			s.position = Vector2(x, 334)
			parade.add_child(s)
			x -= 26.0
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	Audio.play_music("victory")
	show_page(0)


func show_page(p: int) -> void:
	page = p
	if _center:
		_center.queue_free()
	var panel := UI.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	match p:
		0:
			box.add_child(UI.label("THE CATS COME HOME", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			for line: String in STORY:
				_wrap(box, line, UI.C_TEXT)
			var n: int = Progress.data["rescued"].size()
			if n >= GameData.CAT_ORDER.size():
				_wrap(box, "All ten friends are safe. The alley has never been so loud at dinner time.", UI.C_GOOD)
			else:
				_wrap(box, "%d of %d friends are home. Somewhere below, %d still wait for you..." % [
					n, GameData.CAT_ORDER.size(), GameData.CAT_ORDER.size() - n], UI.C_DIM)
		1:
			box.add_child(UI.label("YOUR JOURNEY", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			for l: Array in stat_lines():
				var row := HBoxContainer.new()
				var a := UI.label(l[0], 10)
				a.custom_minimum_size = Vector2(200, 0)
				row.add_child(a)
				row.add_child(UI.label(l[1], 10, UI.C_GOLD))
				box.add_child(row)
		_:
			box.add_child(UI.label("CREDITS", 20, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			for line: String in MainMenu.credits_lines():
				box.add_child(UI.label(line, 10, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	if p < 2:
		continue_button = UI.button("Next", func() -> void: show_page(p + 1), 100)
		row2.add_child(continue_button)
	else:
		continue_button = UI.button("Return to Camp", Transition.go_camp, 130)
		row2.add_child(continue_button)
		row2.add_child(UI.button("Main Menu", Transition.go_menu, 110))
	box.add_child(row2)
	_center = UI.center(_root, panel)
	_center.offset_bottom = -40
	await get_tree().process_frame
	if is_instance_valid(continue_button):
		continue_button.grab_focus()


func _wrap(box: Container, text: String, color: Color) -> void:
	var l := UI.label(text, 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(400, 0)
	box.add_child(l)


static func stat_lines() -> Array:
	var st: Dictionary = Progress.data["stats"]
	return [
		["Completion", "%d%%" % Progress.completion_percent()],
		["Cats rescued", "%d / %d" % [Progress.data["rescued"].size(), GameData.CAT_ORDER.size()]],
		["Shadow Gems", "%d / %d" % [Progress.total_gems(), LevelCatalog.all_gems()]],
		["Secrets found", "%d / %d" % [Progress.total_secrets(), LevelCatalog.all_secrets()]],
		["Challenges completed", str(Progress.challenges_done())],
		["Enemies defeated", str(int(st["enemies"]))],
		["Coins earned", str(int(st["coins_earned"]))],
		["Deaths", str(int(st["deaths"]))],
		["Play time", UI.fmt_time(float(st["play_time"]))],
	]
