extends Node
## Main menu: Grand Prix, Single Race, Time Trial, Garage, Records,
## Settings, Credits and Quit, over a live 3D backdrop.

const DIFFS := ["easy", "normal", "hard"]
const DIFF_NAMES := {"easy": "Easy", "normal": "Normal", "hard": "Hard"}
const DIFF_DESC := {"easy": "Relaxed rivals, gentle cornering.", "normal": "Competent racers with natural mistakes.", "hard": "Fast, clean rivals who drift and boost."}

var backdrop: MenuBackdrop
var ui: Control
var content: VBoxContainer
var side: Control
var _difficulty := "normal"
var _laps := 3
var _selected_track := "whiskerwood"
var _confirm: Control
var _overlay: Control
var page := "main"


func _ready() -> void:
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	backdrop.build("whiskerwood", 4)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UI.theme()
	layer.add_child(ui)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.1, 0.55)
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.0
	shade.offset_right = 560
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	_logo()
	side = VBoxContainer.new()
	side.position = Vector2(48, 210)
	side.custom_minimum_size = Vector2(470, 0)
	ui.add_child(side)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	side.add_child(content)
	var ver := UI.label("v%s  ·  Kocur Studios" % ProjectSettings.get_setting("application/config/version"), 16, UI.MUTED)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 24
	ver.offset_top = -34
	ui.add_child(ver)
	_difficulty = String(Save.data.get("last_difficulty", "normal"))
	_laps = int(Save.data.get("last_laps", 3))
	Audio.play_music("menu")
	var start_page := Game.menu_page
	Game.menu_page = ""
	match start_page:
		"grand_prix": _page_gp()
		"single": _page_single()
		"time_trial": _page_tt()
		_: _page_main()
	if Save.load_status == "reset_corrupt":
		_toast("Your save file was damaged and has been reset. A copy was kept as save.corrupt.json.")
	elif Save.load_status == "recovered":
		_toast("Save restored from backup.")


func _logo() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(44, 34)
	box.add_theme_constant_override("separation", -10)
	ui.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -14)
	row.add_child(title)
	title.add_child(UI.label("KOCUR", 72, UI.TEXT, true, 14))
	title.add_child(UI.label("KART", 72, UI.ACCENT, true, 14))


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()


func _heading(text: String, sub := "") -> void:
	content.add_child(UI.label(text, 40, UI.ACCENT, true, 8))
	if sub != "":
		var s := UI.label(sub, 19, UI.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(460, 0)
		content.add_child(s)


func _focus_later() -> void:
	await get_tree().process_frame
	if is_instance_valid(content):
		UI.focus_first(content)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlay == null:
		get_viewport().set_input_as_handled()
		if _confirm != null:
			_confirm.queue_free()
			_confirm = null
			return
		if page != "main":
			Audio.play("ui_back")
			_page_main()


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------

func _page_main() -> void:
	page = "main"
	_clear()
	content.add_child(UI.button("Grand Prix", _page_gp, 440))
	content.add_child(UI.button("Single Race", _page_single, 440))
	content.add_child(UI.button("Time Trial", _page_tt, 440))
	content.add_child(UI.button("Garage", func(): Game.to_garage(), 440))
	content.add_child(UI.button("Records & Progress", _page_records, 440))
	content.add_child(UI.button("Settings", _open_settings, 440))
	content.add_child(UI.button("Credits", _page_credits, 440))
	content.add_child(UI.button("Quit", func(): get_tree().quit(), 440))
	_focus_later()


func _difficulty_row() -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var info := UI.label(DIFF_DESC[_difficulty], 18, UI.MUTED)
	for d in DIFFS:
		var b := UI.button(DIFF_NAMES[d], func():
			_difficulty = d
			_refresh_page(), 140)
		if d == _difficulty:
			b.add_theme_stylebox_override("normal", UI.box(UI.ACCENT.darkened(0.25), 14, UI.GOLD))
		row.add_child(b)
	content.add_child(info)


func _refresh_page() -> void:
	match page:
		"grand_prix": _page_gp()
		"single": _page_single()
		"time_trial": _page_tt()


func _page_gp() -> void:
	page = "grand_prix"
	_clear()
	_heading("GRAND PRIX", "Two races per cup. Points: 10-7-5-3-2-1. Finish top three for a trophy and unlock the next cup.")
	_difficulty_row()
	for c in TrackCatalog.CUPS:
		var unlocked := Progression.cup_unlocked(Save.data, c["id"])
		var cd: Dictionary = Save.data["cups"][c["id"]]
		var trophy := int(cd["trophy"])
		var names := " + ".join(c["tracks"].map(func(t): return TrackCatalog.track_name(t)))
		var b := UI.button("", func(): Game.start_grand_prix(c["id"], _difficulty), 440)
		b.custom_minimum_size = Vector2(440, 74)
		b.disabled = not unlocked
		b.text = "%s   %s\n%s" % [c["name"], ("[%s]" % Progression.TROPHY_NAMES[trophy]) if trophy > 0 else "", names if unlocked else "Locked: " + Progression.cup_unlock_text(c["id"])]
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", UI.trophy_color(trophy) if trophy > 0 else UI.TEXT)
		content.add_child(b)
	content.add_child(UI.button("Back", _page_main, 440))
	_focus_later()


func _track_list(on_pick: Callable, show: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for tid in TrackCatalog.ORDER:
		var unlocked := Progression.track_unlocked(Save.data, tid)
		var rec: Dictionary = Save.data["records"][tid]
		var line2 := ""
		if not unlocked:
			line2 = "Locked"
		elif show == "tt":
			line2 = "%s  %s" % [Progression.MEDAL_NAMES[int(rec["tt_medal"])] if int(rec["tt_medal"]) > 0 else "No medal", UI.time_text(rec["tt_time"])]
		else:
			line2 = "Best %s" % UI.time_text(rec["race_time"])
		var b := UI.button("%s\n%s" % [TrackCatalog.track_name(tid), line2], func():
			_selected_track = tid
			on_pick.call(tid), 216)
		b.custom_minimum_size = Vector2(216, 70)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = not unlocked
		if tid == _selected_track:
			b.add_theme_stylebox_override("normal", UI.box(UI.ACCENT.darkened(0.25), 14, UI.GOLD))
		if show == "tt" and unlocked:
			b.add_theme_color_override("font_color", UI.trophy_color(int(rec["tt_medal"])) if int(rec["tt_medal"]) > 0 else UI.TEXT)
		grid.add_child(b)


func _page_single() -> void:
	page = "single"
	_clear()
	_heading("SINGLE RACE", "Any unlocked track, your choice of rivals' skill and lap count.")
	_track_list(func(_t): _page_single(), "race")
	_difficulty_row()
	var laps_row := HBoxContainer.new()
	content.add_child(laps_row)
	laps_row.add_child(UI.button("-", func():
		_laps = maxi(1, _laps - 1)
		_page_single(), 60))
	laps_row.add_child(UI.label("  %d lap%s  " % [_laps, "" if _laps == 1 else "s"], 26, UI.TEXT, true))
	laps_row.add_child(UI.button("+", func():
		_laps = mini(5, _laps + 1)
		_page_single(), 60))
	var sel := Game.selection()
	content.add_child(UI.label("Racer: %s · %s" % [Catalog.RACERS[sel["racer"]]["name"], Catalog.KARTS[sel["kart"]]["name"]], 19, UI.MUTED))
	var h := HBoxContainer.new()
	content.add_child(h)
	h.add_child(UI.button("Start Race", func(): Game.start_single(_selected_track, _difficulty, _laps), 216))
	h.add_child(UI.button("Garage", func(): Game.to_garage(), 216))
	content.add_child(UI.button("Back", _page_main, 440))
	_focus_later()


func _page_tt() -> void:
	page = "time_trial"
	_clear()
	_heading("TIME TRIAL", "Race the clock over three laps. Beat your ghost and earn medals.")
	_track_list(func(_t): _page_tt(), "tt")
	var m: Array = TrackCatalog.TRACKS[_selected_track]["medals"]
	var rec: Dictionary = Save.data["records"][_selected_track]
	content.add_child(UI.label("%s\nGold %s · Silver %s · Bronze %s\nYour best %s · Best lap %s" % [TrackCatalog.track_name(_selected_track),
		UI.time_text(m[0]), UI.time_text(m[1]), UI.time_text(m[2]), UI.time_text(rec["tt_time"]), UI.time_text(rec["tt_lap"])], 19, UI.TEXT))
	var h := HBoxContainer.new()
	content.add_child(h)
	h.add_child(UI.button("Start", func(): Game.start_time_trial(_selected_track), 216))
	h.add_child(UI.button("Back", _page_main, 216))
	_focus_later()


func _page_records() -> void:
	page = "records"
	_clear()
	_heading("RECORDS & PROGRESS")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	for c in TrackCatalog.CUPS:
		var cd: Dictionary = Save.data["cups"][c["id"]]
		var t := int(cd["trophy"])
		var line := "%s: %s" % [c["name"], Progression.TROPHY_NAMES[t] if t > 0 else ("Locked" if not Progression.cup_unlocked(Save.data, c["id"]) else "Not finished")]
		if t > 0:
			line += "  (best %d pts)" % int(cd["best_points"])
		v.add_child(UI.label(line, 20, UI.trophy_color(t) if t > 0 else UI.MUTED, true))
	v.add_child(UI.label(" ", 8))
	for tid in TrackCatalog.ORDER:
		var r: Dictionary = Save.data["records"][tid]
		v.add_child(UI.label(TrackCatalog.track_name(tid), 20, UI.ACCENT2, true))
		v.add_child(UI.label("  Time Trial %s  ·  lap %s  ·  %s" % [UI.time_text(r["tt_time"]), UI.time_text(r["tt_lap"]), Progression.MEDAL_NAMES[int(r["tt_medal"])] + " medal"], 17, UI.TEXT))
		v.add_child(UI.label("  Race best %s  ·  lap %s  ·  wins %d" % [UI.time_text(r["race_time"]), UI.time_text(r["race_lap"]), int(r["wins"])], 17, UI.TEXT))
	var st: Dictionary = Save.data["stats"]
	v.add_child(UI.label(" ", 8))
	v.add_child(UI.label("Races %d · Wins %d · Podiums %d · Time Trials %d" % [st["races"], st["wins"], st["podiums"], st["time_trials"]], 18, UI.MUTED, true))
	var unl := 0
	var total := 0
	for u in Progression.all_unlockables():
		total += 1
		if Progression.is_unlocked(Save.data, u["rule"]):
			unl += 1
	v.add_child(UI.label("Unlocked %d of %d items · %d gold medals" % [unl, total, Progression.gold_medals(Save.data)], 18, UI.MUTED, true))
	if not Save.data["recent"].is_empty():
		v.add_child(UI.label("Recent results", 20, UI.ACCENT2, true))
		for r in Save.data["recent"]:
			var what := "Time Trial" if r["mode"] == "time_trial" else UI.ordinal(int(r["position"]))
			v.add_child(UI.label("  %s  %s  %s  %s" % [r.get("date", ""), TrackCatalog.track_name(r["track"]), what, UI.time_text(float(r["time"]))], 16, UI.TEXT))
	var h := HBoxContainer.new()
	content.add_child(h)
	h.add_child(UI.button("Reset Progress", _ask_reset, 216))
	h.add_child(UI.button("Back", _page_main, 216))
	_focus_later()


func _ask_reset() -> void:
	var p := UI.panel(Vector2(560, 0))
	_confirm = UI.center(ui, p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var q := UI.label("Reset all progress?", 34, UI.BAD, true, 6)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var d := UI.label("Trophies, records, medals, ghosts and unlocks will be erased.\nSettings are kept. This cannot be undone.", 20, UI.TEXT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var no := UI.button("Cancel", func():
		_confirm.queue_free()
		_confirm = null
		_focus_later(), 200)
	h.add_child(no)
	h.add_child(UI.button("Erase Everything", func():
		Save.reset_progress()
		_confirm.queue_free()
		_confirm = null
		_toast("Progress reset.")
		_page_records(), 240))
	no.grab_focus()


func _page_credits() -> void:
	page = "credits"
	_clear()
	_heading("CREDITS")
	var text := """KOCUR KART
A Kocur Studios game

Design, code, art, audio and testing
Kocur Studios with Claude (Anthropic)

All 3D models, textures, music and sound
effects were created procedurally for this game.

Engine: Godot Engine (MIT licence)
Font: Fredoka (SIL Open Font License)

Thanks for racing! Meow!"""
	var l := UI.label(text, 20, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	content.add_child(l)
	content.add_child(UI.button("Back", _page_main, 440))
	_focus_later()


func _open_settings() -> void:
	_overlay = preload("res://scripts/ui/settings_panel.gd").new()
	ui.add_child(_overlay)
	_overlay.tree_exited.connect(func():
		_overlay = null
		_focus_later())


func _toast(text: String) -> void:
	var l := UI.label(text, 20, UI.GOLD, true, 6)
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -80
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
