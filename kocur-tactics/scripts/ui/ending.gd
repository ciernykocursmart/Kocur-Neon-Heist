extends Control
## Campaign ending: epilogue, final records and credits.

const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")

const EPILOGUE := [
	"The Pale King's crown rolled across the throne room and came to rest at Bramble's paws.",
	"Without their ruler, the White Crown Legion lost all interest in invading anything. Most of them admitted they had only joined for the free capes.",
	"The Crown Relics returned to Shadowwood Valley. The Moonwell sparkled. The orchard grew back. The mill bridges were declared fish-crate-free zones.",
	"Nox, Bramble, Willow, Moss, Soot and Pepper were named Guardians of the Valley, a title that came with a very large cushion.",
	"And somewhere in the Pale Citadel, a former king is learning that napping in the sun is far better than conquering it.",
]

var _t := 0.0
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = Color("1a1430")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UI.vbox(12)
	v.position = Vector2(190, 40)
	v.size = Vector2(900, 640)
	add_child(v)
	v.add_child(UI.label("THE VALLEY IS FREE!", 44, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	for line: String in EPILOGUE:
		var l := UI.wrap_label(line, 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var d: Dictionary = Campaign.data
	v.add_child(UI.label("Difficulty: %s   |   Medal points: %d / 36   |   Battles won: %d" % [
		UD.DIFFICULTY_INFO[Campaign.difficulty()]["name"], Campaign.medal_count(), int(d["battles_won"])], 15, UI.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Kocur Tactics - a Kocur Studios game. Thank you for playing!", 16, UI.HERO, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Tactical Challenges and every mission stay open for replay and better medals.", 14, UI.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var cont := UI.button("Back to Campaign", func() -> void: Transition.go_campaign("records"), 220)
	cont.name = "BackToCampaign"
	row.add_child(cont)
	row.add_child(UI.button("Main Menu", func() -> void: Transition.go_menu(), 200))
	cont.call_deferred("grab_focus")
	var kinds := ["guardian", "shadowblade", "ranger", "mender", "shadowblade", "ranger"]
	for i in kinds.size():
		var s := Sprite2D.new()
		s.texture = UI.tex("unit_" + kinds[i])
		s.hframes = 2
		s.scale = Vector2(4, 4)
		s.position = Vector2(340 + i * 120, 670)
		add_child(s)
		_sprites.append(s)
	Audio.play_music("ending")


func _process(delta: float) -> void:
	_t += delta
	for i in _sprites.size():
		_sprites[i].frame = int(_t * 2 + i) % 2
		_sprites[i].position.y = 670 - absf(sin(_t * 3.0 + i)) * 10.0
