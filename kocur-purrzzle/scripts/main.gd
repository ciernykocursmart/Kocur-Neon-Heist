extends Control
## Screens (menu, level select, settings, credits, game HUD, overlays) and input handling.

const INK := Color("f6efe2")
const ACCENT := Color("ffb347")
const DIRKEYS := {
	"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
}

class Backdrop extends Control:
	var t := 0.0
	var stars: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 60:
			stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var top := Color("2a1f4d")
		var bot := Color("0f0b1f")
		for i in 12:
			draw_rect(Rect2(0, size.y * i / 12.0, size.x, size.y / 12.0 + 1), top.lerp(bot, i / 11.0))
		for s in stars:
			var a := 0.3 + 0.7 * absf(sin(t * (0.6 + s.z) + s.z * 20.0))
			draw_rect(Rect2(s.x * size.x, s.y * size.y, 3, 3), Color(1, 0.95, 0.8, a))
		draw_circle(Vector2(size.x * 0.86, size.y * 0.2), 54, Color("fff1c4"))
		draw_circle(Vector2(size.x * 0.86 + 18, size.y * 0.2 - 8), 48, Color("2a1f4d"))

class StarRow extends Control:
	var count := 0
	var star_size := 18.0
	func _init(c := 0, sz := 18.0) -> void:
		count = c
		star_size = sz
		custom_minimum_size = Vector2(sz * 3.3, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in 3:
			var c := Vector2(star_size * (0.55 + 1.1 * i), star_size * 0.52)
			var pts := PackedVector2Array()
			for k in 10:
				var r := star_size * (0.5 if k % 2 == 0 else 0.22)
				pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * r)
			draw_colored_polygon(pts, Color("ffd23f") if i < count else Color(1, 1, 1, 0.16))

var ui: Control
var overlay: Control = null
var overlay_kind := ""
var confirm_box: Control = null
var mode := "menu"
var board: Board
var pz: Puzzle
var level := 0
var hud := {}
var held_dir := ""
var hold_t := 0.0
var win_token := 0
var stuck_count := 0
var skip_delays := false

func _ready() -> void:
	theme = _make_theme()
	_apply_fullscreen()
	Sfx.start_music()
	show_menu()

# ------------------------------------------------------------------ theme & helpers
func _sb(col: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _make_theme() -> Theme:
	var th := Theme.new()
	th.set_font_size("font_size", "Button", 22)
	th.set_font_size("font_size", "Label", 22)
	th.set_color("font_color", "Label", INK)
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	th.set_stylebox("normal", "Button", _sb(Color("3a2d63"), Color("5a4a92"), 2))
	th.set_stylebox("hover", "Button", _sb(Color("4d3d82"), ACCENT, 2))
	th.set_stylebox("pressed", "Button", _sb(Color("2a2048"), ACCENT, 2))
	th.set_stylebox("focus", "Button", _sb(Color("4d3d82"), ACCENT, 3))
	th.set_stylebox("disabled", "Button", _sb(Color("261d44"), Color("352a58"), 2))
	th.set_stylebox("panel", "PanelContainer", _sb(Color("241b3a"), Color("5a4a92"), 3, 14))
	th.set_font_size("font_size", "CheckButton", 22)
	th.set_color("font_color", "CheckButton", INK)
	return th

func _label(text: String, size := 22, col := INK, center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _btn(text: String, cb: Callable, min_size := Vector2(280, 50)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _clear_screen() -> void:
	win_token += 1
	held_dir = ""
	_close_overlay()
	_close_confirm()
	if ui:
		ui.queue_free()
	ui = Control.new()
	_full(ui)
	add_child(ui)
	hud = {}
	board = null

func _menu_screen(title: String) -> VBoxContainer:
	_clear_screen()
	ui.add_child(Backdrop.new())
	_full(ui.get_child(0))
	var cc := CenterContainer.new()
	_full(cc)
	ui.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	cc.add_child(box)
	if title != "":
		var l := _label(title, 44, ACCENT)
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color("1a1230"))
		box.add_child(l)
	return box

func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if SaveData.data.settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _tex(name: String, sz: float, region := 0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Sprites.tex(name, region)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ------------------------------------------------------------------ menu screens
func show_menu() -> void:
	mode = "menu"
	var box := _menu_screen("")
	var cat := _tex("cat_open", 150)
	cat.pivot_offset = Vector2(75, 75)
	box.add_child(cat)
	var tw := cat.create_tween().set_loops()
	tw.tween_property(cat, "position:y", -10.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(cat, "position:y", 10.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	var title := _label("KOCUR PURRZZLE", 64, ACCENT)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("1a1230"))
	box.add_child(title)
	box.add_child(_label("Stars %d / %d     Fish %d     Levels %d / %d" % [SaveData.total_stars(), Levels.LIST.size() * 3, SaveData.total_fish(), SaveData.completed_count(), Levels.LIST.size()], 20, Color("c9bfe8")))
	var play := _btn("Play" if SaveData.completed_count() == 0 else "Continue", _on_play)
	box.add_child(play)
	box.add_child(_btn("Level Select", show_select))
	box.add_child(_btn("Settings", show_settings))
	box.add_child(_btn("Credits", show_credits))
	box.add_child(_btn("Quit", func():
		SaveData.save()
		get_tree().quit()))
	play.grab_focus()
	if SaveData.load_error != "":
		box.add_child(_label(SaveData.load_error, 16, Color("ff9a9a")))

func _next_level() -> int:
	for i in Levels.LIST.size():
		if not SaveData.is_completed(i):
			return i
	return Levels.LIST.size() - 1

func _on_play() -> void:
	if not SaveData.data.seen_tutorial:
		SaveData.data.seen_tutorial = true
		SaveData.save()
		_show_howto(func(): start_level(_next_level()))
	else:
		start_level(_next_level())

func _show_howto(on_close: Callable) -> void:
	var box := _open_overlay("howto")
	box.add_child(_label("How to Play", 36, ACCENT))
	var lines := [
		"Guide the cat to the glowing exit. Move with WASD or the arrow keys.",
		"Push crates onto the paw targets. Crates can only be pushed, never pulled.",
		"The exit opens once every target holds a crate.",
		"Z undoes your last move, R restarts the level, Space waits a beat, Esc pauses.",
		"Stars: finish = 1, few moves = 2, few moves and every fish = 3.",
		"New tricks (plates, keys, ice, warp pads) are explained when you meet them.",
	]
	for l in lines:
		var lb := _label(l, 20, INK, false)
		lb.custom_minimum_size = Vector2(640, 0)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lb)
	var b := _btn("Got it!", func():
		_close_overlay()
		on_close.call())
	box.add_child(b)
	b.grab_focus()

func show_select() -> void:
	mode = "select"
	_clear_screen()
	ui.add_child(Backdrop.new())
	_full(ui.get_child(0))
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	root.add_theme_constant_override("separation", 4)
	ui.add_child(root)
	root.add_child(_label("Select Level      Stars %d / %d" % [SaveData.total_stars(), Levels.LIST.size() * 3], 32, ACCENT))
	var focus_btn: Button = null
	var first_open := _next_level()
	for r in Levels.REGIONS.size():
		var done := 0
		for i in Levels.LIST.size():
			if Levels.LIST[i].region == r and SaveData.is_completed(i):
				done += 1
		root.add_child(_label("%s     %d / 6 cleared" % [Levels.REGIONS[r].name, done], 18, Sprites.THEMES[r].spark.lerp(Color.WHITE, 0.3)))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		root.add_child(row)
		for i in Levels.LIST.size():
			if Levels.LIST[i].region != r:
				continue
			var unlocked := SaveData.is_unlocked(i)
			var b := Button.new()
			b.custom_minimum_size = Vector2(112, 72)
			b.text = ("%d\n " % (i + 1)) if unlocked else ""
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.disabled = not unlocked
			if i == first_open:
				b.add_theme_stylebox_override("normal", _sb(Color("4d3d82"), ACCENT, 3))
			if unlocked:
				b.pressed.connect(func():
					Sfx.play("click")
					start_level(i))
				var sr := StarRow.new(SaveData.stars(i), 16)
				sr.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
				sr.position = Vector2(112 / 2.0 - sr.custom_minimum_size.x / 2.0, 46)
				b.add_child(sr)
			else:
				var lk := _tex("locked", 28)
				lk.position = Vector2(112 / 2.0 - 14, 22)
				b.add_child(lk)
			row.add_child(b)
			if i == first_open and unlocked:
				focus_btn = b
	var back := _btn("Back", show_menu, Vector2(200, 44))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(back)
	root.add_child(hb)
	if focus_btn:
		focus_btn.grab_focus()
	else:
		back.grab_focus()

func show_settings() -> void:
	mode = "settings"
	var box := _menu_screen("Settings")
	var st: Dictionary = SaveData.data.settings
	for pair in [["Music volume", "music"], ["Effects volume", "sfx"]]:
		var key: String = pair[1]
		box.add_child(_label(pair[0], 22, INK))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = st[key]
		sl.custom_minimum_size = Vector2(380, 26)
		sl.value_changed.connect(func(v: float):
			SaveData.data.settings[key] = v
			Sfx.apply_settings()
			if key == "sfx":
				Sfx.play("fish"))
		box.add_child(sl)
		if key == "music":
			sl.grab_focus()
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = st.fullscreen
	fs.toggled.connect(func(on: bool):
		SaveData.data.settings.fullscreen = on
		_apply_fullscreen())
	box.add_child(fs)
	var pad := CheckButton.new()
	pad.text = "On-screen arrow pad"
	pad.button_pressed = st.pad
	pad.toggled.connect(func(on: bool): SaveData.data.settings.pad = on)
	box.add_child(pad)
	box.add_child(_btn("How to Play", func(): _show_howto(func(): show_settings())))
	box.add_child(_btn("Reset Progress", func(): _confirm("Erase all stars and progress?", func():
		SaveData.reset_progress()
		show_settings())))
	box.add_child(_btn("Back", func():
		SaveData.save()
		show_menu()))

func show_credits() -> void:
	mode = "credits"
	var box := _menu_screen("Credits")
	box.add_child(_tex("cat_happy", 120))
	for l in ["KOCUR PURRZZLE", "A Kocur Studios game", "Design, code, pixel art and sound: Kocur Studios", "Every sprite and sound is original and generated in code.", "Made with the Godot Engine (MIT licence).", "Thanks for playing!"]:
		box.add_child(_label(l, 22, INK))
	var b := _btn("Back", show_menu)
	box.add_child(b)
	b.grab_focus()

# ------------------------------------------------------------------ overlays
func _open_overlay(kind: String) -> VBoxContainer:
	_close_overlay()
	overlay_kind = kind
	overlay = Control.new()
	_full(overlay)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	_full(dim)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	_full(cc)
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(box)
	return box

func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	overlay_kind = ""

func _confirm(msg: String, on_yes: Callable) -> void:
	_close_confirm()
	confirm_box = Control.new()
	_full(confirm_box)
	add_child(confirm_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	_full(dim)
	confirm_box.add_child(dim)
	var cc := CenterContainer.new()
	_full(cc)
	confirm_box.add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pc.add_child(box)
	box.add_child(_label(msg, 26))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(_btn("Yes", func():
		_close_confirm()
		on_yes.call(), Vector2(150, 46)))
	var no := _btn("No", _close_confirm, Vector2(150, 46))
	row.add_child(no)
	no.grab_focus()

func _close_confirm() -> void:
	if confirm_box:
		confirm_box.queue_free()
		confirm_box = null

func blocked() -> bool:
	return overlay != null or confirm_box != null

# ------------------------------------------------------------------ game
func start_level(i: int) -> void:
	level = clampi(i, 0, Levels.LIST.size() - 1)
	var L: Dictionary = Levels.LIST[level]
	mode = "game"
	_clear_screen()
	SaveData.data.last_level = level
	pz = Puzzle.new(L.rows)
	board = Board.new()
	_full(board)
	ui.add_child(board)
	board.setup(pz, L.region)
	stuck_count = 0
	_build_hud(L)
	_update_hud()
	if level == Levels.region_start(L.region):
		var banner := _label(Levels.REGIONS[L.region].name, 60, Color.WHITE)
		banner.add_theme_constant_override("outline_size", 14)
		banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_full(banner)
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(banner)
		var tw := banner.create_tween()
		tw.tween_interval(1.1)
		tw.tween_property(banner, "modulate:a", 0.0, 0.8)
		tw.tween_callback(banner.queue_free)

func _hud_btn(text: String, cb: Callable, w := 96.0) -> Button:
	var b := _btn(text, cb, Vector2(w, 42))
	b.focus_mode = Control.FOCUS_NONE
	return b

func _build_hud(L: Dictionary) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.05, 0.14, 0.88), Color(0, 0, 0, 0), 0, 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	hud.title = _label("%d-%d  %s" % [L.region + 1, level - Levels.region_start(L.region) + 1, L.name], 26, ACCENT, false)
	hud.title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hud.title)
	hud.moves = _label("", 22)
	row.add_child(hud.moves)
	var fr := HBoxContainer.new()
	fr.add_child(_tex("fish", 30))
	hud.fish = _label("", 22)
	fr.add_child(hud.fish)
	row.add_child(fr)
	var kr := HBoxContainer.new()
	kr.add_child(_tex("key", 30))
	hud.keys = _label("", 22)
	kr.add_child(hud.keys)
	hud.keybox = kr
	row.add_child(kr)
	row.add_child(_hud_btn("Undo", undo, 80))
	row.add_child(_hud_btn("Wait", wait_beat, 80))
	row.add_child(_hud_btn("Restart", _ask_restart, 96))
	row.add_child(_hud_btn("Pause", show_pause, 88))
	var hint := _label(L.hint, 20, Color("fff3d0"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.05, 0.14, 0.82), Color(0, 0, 0, 0), 0, 12))
	hp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hp.custom_minimum_size = Vector2(820, 0)
	hp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hp.position.y -= 8
	hint.custom_minimum_size = Vector2(790, 0)
	hp.add_child(hint)
	ui.add_child(hp)
	hud.warn = _label("A crate is stuck in a corner! Press Z to undo.", 22, Color("ff7b7b"))
	hud.warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud.warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.warn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.warn.position.y -= 92
	hud.warn.visible = false
	ui.add_child(hud.warn)
	if SaveData.data.settings.pad:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		grid.position -= Vector2(24, 24)
		grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
		ui.add_child(grid)
		var cells := [["", ""], ["^", "up"], ["", ""], ["<", "left"], ["v", "down"], [">", "right"]]
		for c in cells:
			if c[1] == "":
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(52, 52)
				grid.add_child(sp)
			else:
				var d: String = c[1]
				var b := _hud_btn(c[0], func(): try_move(d), 52)
				b.custom_minimum_size = Vector2(52, 52)
				b.modulate.a = 0.8
				grid.add_child(b)

func _update_hud() -> void:
	var tgt := Levels.target(level)
	hud.moves.text = "Moves %d / %d" % [pz.moves, tgt]
	hud.moves.add_theme_color_override("font_color", INK if pz.moves <= tgt else Color("ff9a9a"))
	hud.fish.text = "%d / %d" % [pz.fish_collected(), pz.fish_total]
	hud.fish.get_parent().visible = pz.fish_total > 0
	var has_keys := false
	for row in pz.base:
		if "L" in row:
			has_keys = true
	hud.keybox.visible = has_keys
	hud.keys.text = "x %d" % pz.keys
	var n := pz.stuck_crates().size()
	hud.warn.visible = n > 0
	if n > stuck_count:
		Sfx.play("warn")
	stuck_count = n

func try_move(dir: String) -> bool:
	if mode != "game" or blocked() or pz == null or pz.won:
		return false
	if board.busy():
		return false
	var doors_before := pz.doors_open
	var plates_before := _plates_down()
	var res := pz.move(dir)
	if not res.ok:
		board.bump(Puzzle.DIRS[dir])
		board.facing = -1 if dir == "left" else (1 if dir == "right" else board.facing)
		Sfx.play("bump")
		return false
	if dir == "left":
		board.facing = -1
	elif dir == "right":
		board.facing = 1
	_after_action(res, doors_before, plates_before)
	return true

func _plates_down() -> int:
	var n := 0
	for s in pz.switches:
		if pz.crate_at(s) >= 0 or pz.player == s:
			n += 1
	return n

func _after_action(res: Dictionary, doors_before: bool, plates_before: int) -> void:
	if res.get("pushed", false):
		board.squash = 1.0
	if res.get("tp", false):
		board.snap_player_to_logic()
		board.burst(pz.player, Color("9ff4ff"), true)
		Sfx.play("tp")
	elif res.get("won", false):
		pass
	elif res.get("fish", 0) > 0:
		board.burst(pz.player, Color("ffb347"))
		Sfx.play("fish")
	elif res.get("key", false):
		board.burst(pz.player, Color("ffd23f"))
		Sfx.play("key")
	elif res.get("door", false):
		board.burst(pz.player, Color("ffd23f"), true)
		Sfx.play("door")
	elif pz.doors_open != doors_before or _plates_down() != plates_before:
		Sfx.play("switch")
	elif res.get("pushed", false):
		Sfx.play("push")
	elif res.get("slid", false):
		Sfx.play("slide")
	else:
		Sfx.play("step")
	_update_hud()
	if res.get("won", false):
		_on_win()

func undo() -> void:
	if mode != "game" or blocked() or not pz.can_undo():
		return
	pz.undo()
	Sfx.play("undo")
	_update_hud()

func wait_beat() -> void:
	if mode != "game" or blocked() or pz.won or board.busy():
		return
	pz.wait()
	Sfx.play("step")
	_update_hud()

func _ask_restart() -> void:
	if mode != "game" or blocked():
		return
	if pz.moves == 0:
		return
	_confirm("Restart this level?", restart_level)

func restart_level() -> void:
	win_token += 1
	pz.restart()
	board.setup(pz, Levels.LIST[level].region)
	stuck_count = 0
	_update_hud()
	Sfx.play("undo")

func show_pause() -> void:
	if mode != "game" or blocked():
		return
	held_dir = ""
	var box := _open_overlay("pause")
	box.add_child(_label("Paused", 40, ACCENT))
	var res := _btn("Resume", resume)
	box.add_child(res)
	box.add_child(_btn("Restart Level", func():
		resume()
		if pz.moves > 0:
			_confirm("Restart this level?", restart_level)))
	box.add_child(_btn("Main Menu", func():
		if pz.moves > 0 and not pz.won:
			_confirm("Leave this level? Your moves here will be lost.", show_menu)
		else:
			show_menu()))
	res.grab_focus()

func resume() -> void:
	if overlay_kind == "pause":
		_close_overlay()

func _on_win() -> void:
	board.happy = true
	Sfx.play("win")
	win_token += 1
	var tok := win_token
	var info := SaveData.record(level, pz.moves, pz.fish_collected(), pz.fish_total)
	if not skip_delays:
		await get_tree().create_timer(0.9).timeout
	if tok != win_token or mode != "game":
		return
	_show_victory(info)

func _show_victory(info: Dictionary) -> void:
	var last := level >= Levels.LIST.size() - 1
	var box := _open_overlay("victory")
	box.add_child(_label("Level Complete!" if not last else "You finished Kocur Purrzzle!", 40, ACCENT))
	var sr := StarRow.new(info.stars, 44)
	var c := CenterContainer.new()
	c.add_child(sr)
	box.add_child(c)
	box.add_child(_label("Moves: %d     Target: %d     Best: %d" % [pz.moves, Levels.target(level), SaveData.level_info(level).moves], 22))
	box.add_child(_label("Fish: %d / %d" % [pz.fish_collected(), pz.fish_total], 22))
	if info.new_best:
		box.add_child(_label("New best!", 22, Color("9dff9d")))
	if last:
		box.add_child(_label("Every garden, ruin, pond, catacomb and temple is yours. Purrfect!", 20, INK))
	var first: Button
	if not last:
		first = _btn("Next Level", func(): start_level(level + 1))
		box.add_child(first)
	else:
		first = _btn("Credits", show_credits)
		box.add_child(first)
	box.add_child(_btn("Replay Level", func(): start_level(level)))
	box.add_child(_btn("Level Select", show_select))
	first.grab_focus()

# ------------------------------------------------------------------ input
func _dir_down(dir: String) -> bool:
	for k in DIRKEYS[dir]:
		if Input.is_physical_key_pressed(k):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F11:
			SaveData.data.settings.fullscreen = not SaveData.data.settings.fullscreen
			_apply_fullscreen()
			return
		if event.is_action_pressed("ui_cancel") and not event.echo:
			if confirm_box:
				_close_confirm()
			elif overlay_kind == "pause":
				resume()
			elif overlay_kind == "howto":
				pass
			elif mode == "game" and overlay == null:
				show_pause()
			elif mode in ["select", "settings", "credits"]:
				show_menu()
			get_viewport().set_input_as_handled()
			return
		if mode != "game" or blocked() or event.echo:
			return
		for d in DIRKEYS:
			if event.physical_keycode in DIRKEYS[d]:
				held_dir = d
				hold_t = -0.14
				try_move(d)
				get_viewport().set_input_as_handled()
				return
		match event.physical_keycode:
			KEY_Z, KEY_U, KEY_BACKSPACE:
				undo()
			KEY_R:
				_ask_restart()
			KEY_SPACE, KEY_X:
				wait_beat()
			KEY_P:
				show_pause()

func _process(delta: float) -> void:
	if mode != "game" or blocked() or held_dir == "":
		return
	if not _dir_down(held_dir):
		held_dir = ""
		for d in DIRKEYS:
			if _dir_down(d):
				held_dir = d
				hold_t = -0.14
		return
	hold_t += delta
	if hold_t >= 0.11:
		if try_move(held_dir):
			hold_t = 0.0
		elif not board.busy():
			hold_t = 0.0
