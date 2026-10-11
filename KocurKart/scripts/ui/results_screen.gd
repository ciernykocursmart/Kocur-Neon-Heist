extends CanvasLayer
## Post-race flow: race results, records and unlocks, Grand Prix standings,
## cup trophy and the championship finale.

var race: Race
var summary: Dictionary
var root: Control
var _page: Control


func setup(r: Race, s: Dictionary) -> void:
	race = r
	summary = s
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	UI.dim_backdrop(root, 0.5)
	_show_results()


func _new_page(min_w := 820) -> VBoxContainer:
	if _page:
		_page.queue_free()
	var p := UI.panel(Vector2(min_w, 0))
	_page = UI.center(root, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _title(v: VBoxContainer, text: String, col := UI.ACCENT, size := 46) -> void:
	var t := UI.label(text, size, col, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)


func _buttons(v: VBoxContainer, list: Array) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for b in list:
		h.add_child(UI.button(b[0], b[1], 230))
	await get_tree().process_frame
	if is_instance_valid(h) and h.get_child_count() > 0:
		h.get_child(0).grab_focus()


func _show_results() -> void:
	var res: Dictionary = summary["results"]
	var tt: bool = res["mode"] == "time_trial"
	var v := _new_page()
	_title(v, ("TIME TRIAL" if tt else "RACE RESULTS"))
	var sub := UI.label("%s  ·  %s" % [TrackCatalog.track_name(res["track"]), ("%d laps" % res["laps"]) if tt else String(res["difficulty"]).capitalize()], 22, UI.MUTED, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if tt:
		_time_trial_block(v, res)
	else:
		_table(v, res)
	_badges(v)
	match String(res["mode"]):
		"grand_prix":
			var gp: Dictionary = summary.get("gp", {})
			_buttons(v, [["Standings", _show_standings], ["Retry Race", func(): Game.retry_gp_race()], ["Quit Cup", func(): Game.to_menu("grand_prix")]])
		"time_trial":
			_buttons(v, [["Retry", func(): Game.restart_race()], ["Choose Track", func(): Game.to_menu("time_trial")], ["Main Menu", func(): Game.to_menu()]])
		_:
			_buttons(v, [["Race Again", func(): Game.restart_race()], ["Choose Track", func(): Game.to_menu("single")], ["Main Menu", func(): Game.to_menu()]])


func _table(v: VBoxContainer, res: Dictionary) -> void:
	var gp: Dictionary = summary.get("gp", {})
	var pts: Dictionary = gp.get("points", {})
	var grid := GridContainer.new()
	grid.columns = 5 if not pts.is_empty() else 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var heads := ["POS", "RACER", "TIME", "BEST LAP"]
	if not pts.is_empty():
		heads.append("PTS")
	for h in heads:
		grid.add_child(UI.label(h, 18, UI.MUTED, true))
	for row in res["rows"]:
		var col := UI.ACCENT if row["player"] else UI.TEXT
		grid.add_child(UI.label(UI.ordinal(row["position"]), 24, UI.trophy_color(4 - row["position"]) if row["position"] <= 3 else col, true))
		grid.add_child(UI.label(row["name"] + ("  (you)" if row["player"] else ""), 24, col, true))
		grid.add_child(UI.label(("~" if row["estimated"] else "") + UI.time_text(row["time"]), 22, col))
		grid.add_child(UI.label(UI.time_text(row["best_lap"]), 22, col))
		if not pts.is_empty():
			grid.add_child(UI.label("+%d" % int(pts.get(row["racer"], 0)), 22, UI.GOOD, true))


func _time_trial_block(v: VBoxContainer, res: Dictionary) -> void:
	var rec: Dictionary = summary.get("records", {})
	var big := UI.label(UI.time_text(res["player_time"]), 64, UI.TEXT, true, 8)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var laps := HBoxContainer.new()
	laps.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(laps)
	var lt: Array = res.get("player_laps", [])
	for i in lt.size():
		var best: bool = is_equal_approx(lt[i], res["player_best_lap"])
		laps.add_child(UI.label("Lap %d  %s" % [i + 1, UI.time_text(lt[i])], 22, UI.ACCENT2 if best else UI.MUTED, true))
	var medal := Progression.medal_for(res["track"], res["player_time"])
	var m := UI.label("%s MEDAL" % Progression.MEDAL_NAMES[medal].to_upper() if medal > 0 else "NO MEDAL — keep practising!", 34, UI.trophy_color(medal), true, 6)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var meds: Array = TrackCatalog.TRACKS[res["track"]]["medals"]
	var targets := UI.label("Gold %s   ·   Silver %s   ·   Bronze %s" % [UI.time_text(meds[0], false), UI.time_text(meds[1], false), UI.time_text(meds[2], false)], 20, UI.MUTED)
	targets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(targets)
	var r: Dictionary = Save.data["records"].get(res["track"], {})
	var pb := UI.label("Personal best: %s   ·   Best lap: %s" % [UI.time_text(r.get("tt_time", 0.0)), UI.time_text(r.get("tt_lap", 0.0))], 20, UI.TEXT)
	pb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pb)
	if not res.get("valid", false):
		var inv := UI.label("Run not recorded (incomplete).", 20, UI.BAD)
		inv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(inv)


func _badges(v: VBoxContainer) -> void:
	var rec: Dictionary = summary.get("records", {})
	var line := []
	if rec.get("new_best_time", false):
		line.append("NEW RECORD TIME!")
	if rec.get("new_best_lap", false):
		line.append("NEW BEST LAP!")
	if rec.get("medal_improved", false):
		line.append("%s MEDAL EARNED!" % Progression.MEDAL_NAMES[int(rec["medal"])].to_upper())
	if not line.is_empty():
		var b := UI.label("   ".join(line), 24, UI.GOLD, true, 6)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
	var unlocks: Array = summary.get("unlocks", [])
	if not unlocks.is_empty():
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.box(Color(0.3, 0.2, 0.05, 0.9), 14, UI.GOLD))
		var uv := VBoxContainer.new()
		box.add_child(uv)
		uv.add_child(UI.label("UNLOCKED!", 26, UI.GOLD, true))
		for u in unlocks:
			uv.add_child(UI.label("%s: %s" % [u["kind"], u["name"]], 22, UI.TEXT, true))
		v.add_child(box)
		Audio.play("unlock")


func _show_standings() -> void:
	var gp: Dictionary = summary["gp"]
	var v := _new_page(640)
	_title(v, "%s — STANDINGS" % TrackCatalog.cup_name(gp["cup"]).to_upper(), UI.ACCENT, 38)
	var cup := TrackCatalog.cup(gp["cup"])
	var info := UI.label("After race %d of %d" % [int(gp["index"]) + 1, cup["tracks"].size()], 22, UI.MUTED, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	v.add_child(grid)
	var i := 0
	for row in gp["standings"]:
		i += 1
		var col := UI.ACCENT if row["player"] else UI.TEXT
		grid.add_child(UI.label(UI.ordinal(i), 26, UI.trophy_color(4 - i) if i <= 3 else col, true))
		grid.add_child(UI.label(row["name"], 26, col, true))
		grid.add_child(UI.label("%d pts  (+%d)" % [row["points"], int(gp["points"].get(row["racer"], 0))], 24, col))
	if gp["last"]:
		_buttons(v, [["Cup Result", _show_cup]])
	else:
		var next_track: String = cup["tracks"][int(gp["index"]) + 1]
		var nt := UI.label("Next: %s" % TrackCatalog.track_name(next_track), 22, UI.ACCENT2, true)
		nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nt)
		_buttons(v, [["Next Race", func(): Game.gp_next()], ["Quit Cup", func(): Game.to_menu("grand_prix")]])


func _show_cup() -> void:
	var gp: Dictionary = summary["gp"]
	var v := _new_page(640)
	var trophy := int(gp.get("trophy", 0))
	_title(v, TrackCatalog.cup_name(gp["cup"]).to_upper(), UI.ACCENT, 40)
	var big := UI.label(("%s TROPHY!" % Progression.TROPHY_NAMES[trophy].to_upper()) if trophy > 0 else "NO TROPHY", 56, UI.trophy_color(trophy), true, 10)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var standing := int(gp.get("standing", 6))
	var s := UI.label("You finished the cup %s." % UI.ordinal(standing), 26, UI.TEXT, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	if trophy == 0:
		var hint := UI.label("Finish in the top three to earn a trophy and unlock the next cup.", 20, UI.MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	Audio.play("fanfare" if trophy > 0 else "ui_back")
	if gp.get("champion", false) and trophy > 0:
		_buttons(v, [["Continue", _show_champion]])
	else:
		_buttons(v, [["Continue", func(): Game.gp_next()]])


func _show_champion() -> void:
	var v := _new_page(760)
	_title(v, "CHAMPIONSHIP COMPLETE!", UI.GOLD, 50)
	var msg := UI.label("All three cups conquered. The Royal Catnip trophy is yours!", 24, UI.TEXT, true)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	v.add_child(grid)
	var total := 0
	for c in TrackCatalog.CUPS:
		var cd: Dictionary = Save.data["cups"][c["id"]]
		total += int(cd["best_points"])
		grid.add_child(UI.label(c["name"], 26, UI.TEXT, true))
		grid.add_child(UI.label(Progression.TROPHY_NAMES[int(cd["trophy"])], 26, UI.trophy_color(int(cd["trophy"])), true))
		grid.add_child(UI.label("%d pts" % int(cd["best_points"]), 24, UI.MUTED))
	var tot := UI.label("Championship total: %d points" % total, 28, UI.GOLD, true)
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tot)
	var next := UI.label("Try Hard difficulty and chase Time Trial golds for more rewards.", 20, UI.MUTED)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(next)
	Audio.play("fanfare")
	_buttons(v, [["Main Menu", func(): Game.gp_next()]])
