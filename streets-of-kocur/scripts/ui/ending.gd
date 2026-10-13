extends Control
## Ending: the neighbourhood gets its food back. A short illustrated epilogue,
## final stats, campaign completion (already saved by the level), then
## Play Again or Main Menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const LK = preload("res://scripts/data/looks.gd")

const PAGES := [
	"Lord Lardpaw rolls one last time... straight into his own pantry door. THUD.",
	"The White Crown gang scatters into the night, leaving every stolen fish, can and drumstick behind.",
	"Kocur drags the whole feast back to the neighbourhood. Nobody goes hungry tonight.",
	"Even Lardpaw gets a small plate. He promises to share from now on. Probably.",
]

var t := 0.0
var page := 0
var page_t := 0.0
var panel: Control
var done := false
var font: Font


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	Engine.time_scale = 1.0
	Audio.play_music("ending")


func _process(delta: float) -> void:
	t += delta
	page_t += delta
	if not done and (page_t > 4.2 or (page_t > 0.5 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack")))):
		page += 1
		page_t = 0.0
		if page >= PAGES.size():
			_show_final()
	queue_redraw()


func _show_final() -> void:
	done = true
	Audio.play("victory")
	var m := UI.modal(self, 560)
	panel = m[0]
	panel.name = "Final"
	panel.color = Color(0, 0, 0, 0.35)
	var v: VBoxContainer = m[1]
	v.add_child(UI.label("CAMPAIGN COMPLETE!", 32, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("The streets belong to the cats again.", 16, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Final score  %d" % Game.score, 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Difficulty: %s" % String(Game.diff()["name"]), 16, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var golden := 0
	var medals := 0
	for i in 6:
		golden += int(Game.has_golden(i))
		medals += int(Game.has_challenge(i))
	v.add_child(UI.label("Golden fish %d / 6     Challenges %d / 6" % [golden, medals], 16, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Campaign clears: %d     Best campaign score: %d" % [int(Game.data["completions"]), int(Game.data["best_campaign_score"])], 15, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Try a harder difficulty, find every golden fish, or chase S ranks in Level Select!", 14, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := UI.button("Play again", func() -> void:
		Game.new_campaign(Game.difficulty)
		Transition.go_level(), 180, 18)
	again.name = "PlayAgain"
	row.add_child(again)
	var mm := UI.button("Main menu", func() -> void: Transition.go_menu(), 180, 18)
	mm.name = "MainMenu"
	row.add_child(mm)
	UI.focus(again)


func _draw() -> void:
	# Sunrise over the neighbourhood.
	var sky := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 470), Vector2(0, 470)])
	draw_polygon(sky, PackedColorArray([Color("3a2a6a"), Color("3a2a6a"), Color("ffb070"), Color("ffb070")]))
	draw_circle(Vector2(640, 470), 120 + sin(t) * 3.0, Color("ffe08a"))
	for i in 9:
		var x := i * 150.0 - 40.0
		var h := 140.0 + fmod(i * 73.0, 120.0)
		draw_rect(Rect2(x, 470 - h, 130, h), Color("4a2a4a"))
		for wy in range(int(470 - h) + 16, 450, 26):
			draw_rect(Rect2(x + 16, wy, 14, 14), Color(1, 0.85, 0.5, 0.8))
			draw_rect(Rect2(x + 76, wy, 14, 14), Color(1, 0.85, 0.5, 0.8))
	draw_rect(Rect2(0, 470, 1280, 250), Color("5a4a52"))
	# The feast pile.
	var kinds := ["can", "fish", "chicken", "can", "fish", "golden", "chicken", "fish", "can"]
	for i in 18:
		var x2 := 470.0 + (i % 6) * 60.0 + (i / 6) * 30.0
		var y2 := 640.0 - (i / 6) * 34.0
		PickupArt.draw_item(self, kinds[i % kinds.size()], Vector2(x2, y2), 1.3, t)
	# Kocur on top, neighbourhood cats cheering around.
	var bounce := absf(sin(t * 4.0)) * 10.0
	draw_set_transform(Vector2(640, 548 - bounce), 0.0, Vector2(2.0, 2.0))
	CatPainter.draw_cat(self, LK.LOOKS["hero"], {"tail": t * 4.0, "arm_f": Vector2(8, -38), "arm_b": Vector2(-8, -34), "eyes": "happy", "mouth": "grin"})
	var friends := [[260.0, Color("e0904a")], [380.0, Color("8a8a96")], [900.0, Color("f0d0a0")], [1020.0, Color("3a3a44")]]
	for i in friends.size():
		var fx: float = friends[i][0]
		var lk := {"fur": friends[i][1], "outline": Color("2a2235"), "eye": Color("8aff7a"), "belly": (friends[i][1] as Color).lightened(0.3), "acc": []}
		var b2 := absf(sin(t * 5.0 + i)) * 14.0
		draw_set_transform(Vector2(fx, 680 - b2), 0.0, Vector2(1.5 * (1 if fx < 640 else -1), 1.5))
		CatPainter.draw_cat(self, lk, {"tail": t * 5.0 + i, "arm_f": Vector2(6, -30), "eyes": "happy", "mouth": "open"})
	# Lardpaw, sheepish, with a tiny plate.
	draw_set_transform(Vector2(1160, 690), 0.0, Vector2(-1.1, 1.1))
	CatPainter.draw_cat(self, LK.LOOKS["lardpaw"], {"tail": t, "eyes": "closed", "mouth": "o", "arm_f": Vector2(14, 0)})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Story text.
	if not done and page < PAGES.size():
		var a := clampf(page_t * 2.0, 0.0, 1.0)
		draw_rect(Rect2(140, 40, 1000, 110), Color(0.08, 0.03, 0.12, 0.75 * a))
		draw_string_outline(font, Vector2(160, 104), PAGES[page], HORIZONTAL_ALIGNMENT_CENTER, 960, 24, 6, Color(0.08, 0.03, 0.12, a))
		draw_string(font, Vector2(160, 104), PAGES[page], HORIZONTAL_ALIGNMENT_CENTER, 960, 24, Color(1, 1, 1, a))
		draw_string(font, Vector2(160, 140), "J / Enter: next", HORIZONTAL_ALIGNMENT_RIGHT, 960, 14, Color(0.8, 0.75, 0.9, a))
