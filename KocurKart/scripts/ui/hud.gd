extends CanvasLayer
## Race HUD: position, laps, timers, Purr meter, drift charge, speed,
## standings, minimap, countdown and race messages.

var race: Race
var root: Control
var pos_label: Label
var pos_total: Label
var lap_label: Label
var time_label: Label
var best_label: Label
var total_label: Label
var speed_label: Label
var purr_bars: Array[Panel] = []
var drift_pill: PanelContainer
var drift_label: Label
var center_label: Label
var message_label: Label
var sub_label: Label
var wrong_way: Label
var standings_box: VBoxContainer
var minimap: Control
var medal_label: Label
var _msg_time := 0.0
var _center_time := 0.0
var _wrong := false


func setup(r: Race) -> void:
	race = r
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_build()
	race.countdown_tick.connect(_on_tick)
	race.lap_completed.connect(_on_lap)
	race.final_lap.connect(_on_final)
	race.kart_finished.connect(_on_finished)
	race.wrong_way_changed.connect(func(a): _wrong = a)
	race.player.kart.recovered.connect(func(): flash("RECOVERED", UI.ACCENT2, 1.0))
	race.player.kart.drift_level_changed.connect(_on_drift_level)
	race.player.kart.boost_started.connect(_on_boost)


func _build() -> void:
	var tt := race.mode == "time_trial"
	# Position (top-left).
	var pos_box := HBoxContainer.new()
	pos_box.position = Vector2(28, 14)
	pos_box.add_theme_constant_override("separation", 4)
	root.add_child(pos_box)
	pos_label = UI.label("1st", 84, UI.GOLD, true, 12)
	pos_box.add_child(pos_label)
	pos_total = UI.label("/6", 36, UI.TEXT, true, 8)
	pos_total.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_box.add_child(pos_total)
	pos_box.visible = not tt
	# Lap and timers (top-right).
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -330
	right.offset_right = -26
	right.offset_top = 18
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation", 0)
	root.add_child(right)
	lap_label = UI.label("LAP 1/3", 46, UI.TEXT, true, 10)
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(lap_label)
	time_label = UI.label("0:00.000", 30, UI.TEXT, true, 8)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(time_label)
	best_label = UI.label("BEST  --:--.---", 22, UI.ACCENT2, true, 6)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(best_label)
	total_label = UI.label("TOTAL 0:00.000", 22, UI.MUTED, true, 6)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(total_label)
	if tt:
		medal_label = UI.label("", 20, UI.GOLD, true, 6)
		medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(medal_label)
	# Purr meter + drift + speed (bottom-left).
	var bl := VBoxContainer.new()
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 28
	bl.offset_top = -150
	bl.offset_right = 420
	bl.add_theme_constant_override("separation", 6)
	root.add_child(bl)
	speed_label = UI.label("0 km/h", 30, UI.TEXT, true, 8)
	bl.add_child(speed_label)
	var purr_row := HBoxContainer.new()
	purr_row.add_theme_constant_override("separation", 6)
	bl.add_child(purr_row)
	var pl := UI.label("PURR", 20, UI.ACCENT2, true, 6)
	purr_row.add_child(pl)
	for i in 3:
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(64, 22)
		bar.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.08, 0.16, 0.85), 8, Color(1, 1, 1, 0.2)))
		purr_row.add_child(bar)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = UI.ACCENT2
		fill.position = Vector2(3, 3)
		fill.size = Vector2(0, 16)
		bar.add_child(fill)
		purr_bars.append(bar)
	var key := UI.label("[%s]" % Controls.primary_key_name("boost"), 16, UI.MUTED, false, 4)
	purr_row.add_child(key)
	drift_pill = PanelContainer.new()
	drift_pill.add_theme_stylebox_override("panel", UI.box(Color(0.3, 0.75, 1.0, 0.9), 12))
	drift_label = UI.label("DRIFT", 20, Color(0.05, 0.05, 0.1), true)
	drift_pill.add_child(drift_label)
	drift_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	drift_pill.visible = false
	bl.add_child(drift_pill)
	# Standings (left, under position).
	standings_box = VBoxContainer.new()
	standings_box.position = Vector2(30, 130)
	standings_box.add_theme_constant_override("separation", 2)
	standings_box.visible = not tt
	root.add_child(standings_box)
	# Minimap (bottom-right).
	minimap = preload("res://scripts/ui/minimap.gd").new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = -250
	minimap.offset_top = -250
	minimap.offset_right = -20
	minimap.offset_bottom = -20
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.visible = bool(Settings.get_value("show_minimap", true))
	root.add_child(minimap)
	minimap.setup(race)
	# Centre texts.
	center_label = UI.label("", 150, UI.GOLD, true, 20)
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_label.pivot_offset = Vector2(0, 0)
	root.add_child(center_label)
	message_label = UI.label("", 56, UI.TEXT, true, 12)
	message_label.anchor_left = 0.0
	message_label.anchor_right = 1.0
	message_label.anchor_top = 0.24
	message_label.anchor_bottom = 0.24
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(message_label)
	sub_label = UI.label("", 26, UI.MUTED, true, 8)
	sub_label.anchor_left = 0.0
	sub_label.anchor_right = 1.0
	sub_label.anchor_top = 0.24
	sub_label.anchor_bottom = 0.24
	sub_label.offset_top = 70
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub_label)
	wrong_way = UI.label("WRONG WAY!", 64, UI.BAD, true, 14)
	wrong_way.anchor_left = 0.0
	wrong_way.anchor_right = 1.0
	wrong_way.anchor_top = 0.42
	wrong_way.anchor_bottom = 0.42
	wrong_way.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_way.visible = false
	root.add_child(wrong_way)


func flash(text: String, col := UI.TEXT, seconds := 1.6, sub := "") -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", col)
	sub_label.text = sub
	_msg_time = seconds


func _on_tick(v: int) -> void:
	center_label.text = str(v) if v > 0 else "GO!"
	center_label.add_theme_color_override("font_color", UI.GOLD if v > 0 else UI.GOOD)
	_center_time = 0.9 if v > 0 else 1.0


func _on_lap(e: RaceEntry, lap: int, t: float, best: bool) -> void:
	if e != race.player:
		return
	if lap < race.laps:
		flash("LAP %d" % (lap + 1), UI.TEXT, 1.4, ("NEW BEST LAP  " if best and lap > 1 else "") + UI.time_text(t))


func _on_final(e: RaceEntry) -> void:
	if e == race.player:
		flash("FINAL LAP!", UI.ACCENT, 2.0, UI.time_text(e.lap_times[-1]) if not e.lap_times.is_empty() else "")


func _on_finished(e: RaceEntry) -> void:
	if e == race.player:
		var text := "FINISH!" if race.mode == "time_trial" else "%s PLACE!" % UI.ordinal(e.position).to_upper()
		flash(text, UI.GOLD if e.position <= 3 or race.mode == "time_trial" else UI.TEXT, 4.0, UI.time_text(e.finish_time))


func _on_drift_level(level: int) -> void:
	if level > 0:
		drift_pill.visible = true
		var col: Color = KartModel.SPARK_COLORS[level]
		drift_pill.add_theme_stylebox_override("panel", UI.box(col, 12))
		drift_label.text = "DRIFT  " + ("•" if level == 1 else "• •")


func _on_boost(kind: StringName) -> void:
	if kind == &"drift2":
		flash("SUPER BOOST!", UI.ACCENT, 0.8)


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var e := race.player
	var k := e.kart
	pos_label.text = UI.ordinal(e.position)
	pos_label.add_theme_color_override("font_color", UI.trophy_color(4 - e.position) if e.position <= 3 else UI.TEXT)
	pos_total.text = "/%d" % race.entries.size()
	lap_label.text = "LAP %d/%d" % [e.display_lap(race.laps), race.laps]
	var cur := race.race_time - e.lap_start if race.state != Race.State.COUNTDOWN else 0.0
	if e.finished:
		cur = e.lap_times[-1] if not e.lap_times.is_empty() else 0.0
	time_label.text = UI.time_text(cur)
	best_label.text = "BEST  " + UI.time_text(e.best_lap if e.best_lap != INF else 0.0)
	total_label.text = "TOTAL " + UI.time_text(e.finish_time if e.finished else race.race_time)
	if medal_label:
		var m: Array = race.track.def.get("medals", [0, 0, 0])
		medal_label.text = "GOLD %s   SILVER %s" % [UI.time_text(m[0], false), UI.time_text(m[1], false)]
	speed_label.text = "%d km/h" % int(absf(k.forward_speed) * 3.6)
	for i in 3:
		var fill: ColorRect = purr_bars[i].get_node("Fill")
		var amt := clampf(k.purr - i, 0.0, 1.0)
		fill.size = Vector2((purr_bars[i].size.x - 6) * amt, purr_bars[i].size.y - 6)
		fill.color = UI.ACCENT2 if amt >= 1.0 else UI.ACCENT2.darkened(0.45)
	if not k.drifting or k.drift_level == 0:
		drift_pill.visible = false
	_update_standings()
	# Centre countdown animation.
	if _center_time > 0.0:
		_center_time -= delta
		var s := 1.0 + maxf(_center_time - 0.5, 0.0) * 0.8
		center_label.scale = Vector2(s, s)
		center_label.pivot_offset = center_label.size * 0.5
		center_label.modulate.a = clampf(_center_time * 2.5, 0.0, 1.0)
	else:
		center_label.text = ""
	if _msg_time > 0.0:
		_msg_time -= delta
		message_label.modulate.a = clampf(_msg_time * 3.0, 0.0, 1.0)
		sub_label.modulate.a = message_label.modulate.a
	else:
		message_label.text = ""
		sub_label.text = ""
	wrong_way.visible = _wrong and int(Time.get_ticks_msec() / 300) % 2 == 0


func _update_standings() -> void:
	if not standings_box.visible:
		return
	var order := race.entries.duplicate()
	order.sort_custom(func(a, b): return a.position < b.position)
	while standings_box.get_child_count() < order.size():
		var l := UI.label("", 20, UI.TEXT, true, 6)
		standings_box.add_child(l)
	for i in order.size():
		var e: RaceEntry = order[i]
		var l: Label = standings_box.get_child(i)
		l.text = "%d  %s%s" % [e.position, e.kart.display_name, "  FIN" if e.finished else ""]
		l.add_theme_color_override("font_color", UI.ACCENT if e == race.player else UI.TEXT)
