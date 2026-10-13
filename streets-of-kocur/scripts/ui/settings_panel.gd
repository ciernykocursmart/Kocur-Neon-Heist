extends RefCounted
## Settings and Controls windows, shared by the main menu and the pause menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const B = preload("res://scripts/data/balance.gd")


static func open(parent: Node, in_game := false) -> Control:
	var m := UI.modal(parent, 600)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "SettingsWindow"
	v.add_child(UI.label("SETTINGS", 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var first: Control = null
	for pair in [["Master volume", "master"], ["Music volume", "music"], ["Effects volume", "sfx"]]:
		grid.add_child(UI.label(pair[0]))
		var s := HSlider.new()
		s.name = "Slider_" + pair[1]
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(280, 26)
		s.value = Settings.get(pair[1] + "_volume")
		var kind: String = pair[1]
		s.value_changed.connect(func(val: float) -> void:
			Settings.set_volume(kind, val)
			if kind == "sfx":
				Audio.play("jab"))
		grid.add_child(s)
		if first == null:
			first = s
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
	grid.add_child(UI.label("Screen shake"))
	var sh := CheckBox.new()
	sh.name = "ScreenShake"
	sh.button_pressed = Settings.screen_shake
	sh.toggled.connect(func(on: bool) -> void: Settings.set_screen_shake(on))
	grid.add_child(sh)
	grid.add_child(UI.label("Difficulty"))
	var df := OptionButton.new()
	df.name = "Difficulty"
	for d: String in B.DIFFICULTIES:
		df.add_item(B.DIFFICULTY_INFO[d]["name"])
	df.selected = B.DIFFICULTIES.find(Game.difficulty)
	grid.add_child(df)
	var dnote := UI.wrap_label(B.DIFFICULTY_INFO[Game.difficulty]["desc"], 14, UI.TEXT_DIM)
	df.item_selected.connect(func(i: int) -> void:
		Game.set_difficulty(B.DIFFICULTIES[i])
		dnote.text = B.DIFFICULTY_INFO[B.DIFFICULTIES[i]]["desc"] + ("  (Takes full effect from the next street.)" if in_game else ""))
	v.add_child(dnote)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.button("Controls", func() -> void: open_controls(parent), 180))
	var close := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 140)
	close.name = "Close"
	row.add_child(close)
	UI.focus(close)
	return dim


const CONTROLS_TEXT := """[b][color=#ffd23a]KEYBOARD[/color][/b]                                   [b][color=#ffd23a]GAMEPAD[/color][/b]
[b]A / D[/b] or [b]Left / Right[/b]  walk                       Left stick / D-pad
[b]W / S[/b] or [b]Up / Down[/b]  move along the street      Left stick / D-pad
[b]Double-tap[/b] a direction or hold [b]Shift[/b]  run       RB
[b]Space[/b]  jump                                              A
[b]J[/b]  attack                                                    X
[b]K[/b]  PAWQUAKE special                                   Y
[b]E[/b]  grab / throw                                         B
[b]Esc[/b] or [b]P[/b]  pause                                      Start

[b][color=#ffd23a]MOVES[/color][/b]
[b]Combo:[/b] tap [b]J J J[/b] for paw - claw - WHAM. The third hit knocks enemies down. Pause too long and the combo restarts.
[b]Flying kick:[/b] [b]Space[/b] then [b]J[/b]. Jumps also clear bottles, shockwaves and low attacks.
[b]Pounce:[/b] run and press [b]J[/b].
[b]PAWQUAKE:[/b] [b]K[/b] spins and blasts everyone around you. You are invulnerable during the spin. Costs one of the two blue energy bars; energy refills when you land hits, take hits, and slowly over time.
[b]Grab:[/b] walk into a gang cat and press [b]E[/b]. [b]J[/b] = knee (3x), [b]E[/b] = throw (hold a direction to throw that way). Thrown cats bowl over their friends. Enforcers and bosses can't be grabbed.

[b][color=#ffd23a]HEALTH, LIVES, SCORE[/color][/b]
Food heals: [b]fish[/b] +20, [b]chicken[/b] +40, [b]cat food can[/b] +70. Smash crates, barrels and stalls for hidden food. A [b]Golden Fish[/b] (one hidden per street) gives 3000 points and a full special meter.
After a hit you blink and are briefly invulnerable. Lose all health and you lose a life; you get back up where you fell. Out of lives = Game Over: use a [b]continue[/b] to restart from the last checkpoint (each cleared fight is a checkpoint).
Extra life every [b]40,000[/b] points. Score: enemies, combos of 5+ hits, bosses, items, plus time and health bonuses at the end of each street.

[b][color=#ffd23a]READ THE GANG[/color][/b]
A yellow [b]![/b] over a cat = it is about to attack. A red glow or red zone on the ground = a big hit is coming there - get out of it. Bosses show [b]OPEN![/b] when they are vulnerable after a big move.
"""


static func open_controls(parent: Node) -> Control:
	var m := UI.modal(parent, 900)
	var dim: Control = m[0]
	var v: VBoxContainer = m[1]
	dim.name = "ControlsWindow"
	v.add_child(UI.label("CONTROLS & RULES", 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = CONTROLS_TEXT
	rt.custom_minimum_size = Vector2(860, 540)
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.focus_mode = Control.FOCUS_ALL
	v.add_child(rt)
	var close := UI.button("Close", func() -> void:
		Audio.play("ui_back")
		dim.queue_free(), 140)
	close.name = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	UI.focus(close)
	return dim
