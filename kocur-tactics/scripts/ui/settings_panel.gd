extends RefCounted
## Settings and Help windows, shared by the main menu, campaign and pause menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")


static func open(parent: Node, in_battle := false) -> Control:
	var m := UI.modal(parent, 560)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "SettingsWindow"
	v.add_child(UI.label("SETTINGS", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for pair in [["Master volume", "master"], ["Music volume", "music"], ["Effects volume", "sfx"]]:
		grid.add_child(UI.label(pair[0]))
		var s := HSlider.new()
		s.name = "Slider_" + pair[1]
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(260, 24)
		s.value = Settings.get(pair[1] + "_volume")
		var kind: String = pair[1]
		s.value_changed.connect(func(val: float) -> void:
			Settings.set_volume(kind, val)
			if kind == "sfx":
				Audio.play("ui_move"))
		grid.add_child(s)
	grid.add_child(UI.label("Fullscreen"))
	var fs := CheckBox.new()
	fs.name = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	grid.add_child(fs)
	grid.add_child(UI.label("Window size"))
	var res := OptionButton.new()
	res.name = "Resolution"
	for r: Vector2i in Settings.RESOLUTIONS:
		res.add_item("%d x %d" % [r.x, r.y])
	res.selected = Settings.resolution_index
	res.item_selected.connect(func(i: int) -> void: Settings.set_resolution(i))
	grid.add_child(res)
	grid.add_child(UI.label("Animation speed"))
	var sp := OptionButton.new()
	sp.name = "Speed"
	for n: String in Settings.SPEED_NAMES:
		sp.add_item(n)
	sp.selected = Settings.speed_index
	sp.item_selected.connect(func(i: int) -> void: Settings.set_speed(i))
	grid.add_child(sp)
	grid.add_child(UI.label("Difficulty"))
	var df := OptionButton.new()
	df.name = "Difficulty"
	for d: String in UD.DIFFICULTIES:
		df.add_item(UD.DIFFICULTY_INFO[d]["name"])
	df.selected = UD.DIFFICULTIES.find(Campaign.difficulty())
	grid.add_child(df)
	var dnote := UI.wrap_label(UD.DIFFICULTY_INFO[Campaign.difficulty()]["desc"], 13, UI.TEXT_DIM)
	df.item_selected.connect(func(i: int) -> void:
		Campaign.set_difficulty(UD.DIFFICULTIES[i])
		dnote.text = UD.DIFFICULTY_INFO[UD.DIFFICULTIES[i]]["desc"] + (
			"  (Applies from the next battle.)" if in_battle else ""))
	v.add_child(dnote)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.button("Controls & Rules", func() -> void: open_help(parent), 200))
	var close := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 140)
	close.name = "Close"
	row.add_child(close)
	close.call_deferred("grab_focus")
	return dim


const HELP_TEXT := """[b][color=#f2c230]CONTROLS[/color][/b]
[b]Left click[/b] a hero to select it. Blue tiles = where it can move. Click one to move.
Red-marked enemies can be attacked by the armed ability. [b]Click once to aim[/b] (shows the exact damage), [b]click again to confirm[/b].
[b]Right click / Backspace[/b]: cancel aim, then undo an uncommitted move, then deselect.
[b]1-4[/b] pick an ability, [b]F[/b] interact (Free / Claim / Escape), [b]W[/b] wait, [b]Z[/b] undo move, [b]Tab[/b] next hero, [b]Space[/b] confirm, [b]T[/b] show enemy threat, [b]Enter/E[/b] end turn, [b]Esc[/b] menu.

[b][color=#f2c230]TURNS[/color][/b]
Each hero may [b]move once, then act once[/b] (attack, ability, interact or wait). You cannot move after acting. A move can be undone until the hero acts. Heroes that are done are greyed out. Then the enemy phase plays.

[b][color=#f2c230]COMBAT[/color][/b]
Damage = attacker ATK (+ ability bonus) - target DEF, minimum 1. No random rolls, no critical hits: the preview is exactly what happens.
[b]Flanking:[/b] a melee attack gets +2 when another ally of the attacker stands next to the target. Enemies flank too!
[b]Line of sight:[/b] ranged attacks need a clear line. Walls and pillars block it; forests, water and units do not.
Units can walk through allies but never through enemies, and never end on an occupied tile.

[b][color=#f2c230]TERRAIN[/color][/b]
Forest: +1 DEF, costs 2 movement.  Mud/snow: costs 2.  Hill: ranged attacks +1 range, costs 2.
Water: impassable, but see-through. Walls/pillars: impassable, block sight.
Thorns/embers/caltrops (spiky tiles): 3 damage to a unit standing there when its side's turn starts.

[b][color=#f2c230]ENEMY INFO[/color][/b]
Click an enemy to see its stats and every tile it can attack next turn. Zz = asleep (wakes when a hero comes close or it is hit).
[b]Hatched orange tiles with ![/b] = a telegraphed boss attack. It lands at the start of the next enemy turn - move out!
A red X marks where enemy reinforcements arrive this turn.

[b][color=#f2c230]KNOCK-OUTS[/color][/b]
A hero at 0 HP is knocked out for the rest of the battle but returns, fully healed, for the next one. Nobody is lost forever.
"""


static func open_help(parent: Node) -> Control:
	var m := UI.modal(parent, 860)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "HelpWindow"
	v.add_child(UI.label("CONTROLS & RULES", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = HELP_TEXT
	rt.custom_minimum_size = Vector2(820, 520)
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(rt)
	var close := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 140)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	close.call_deferred("grab_focus")
	return dim
