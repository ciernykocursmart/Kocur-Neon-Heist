extends Control
## The safehouse between missions: upgrade shop, mission briefing, deploy.

var _credits_label: Label
var _rows := {}
var _list: VBoxContainer


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	UITheme.set_crosshair_cursor(false)
	var bg := NeonBackground.new()
	bg.modulate = Color(0.45, 0.45, 0.55)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UITheme.make_title("HIDEOUT", 44, Palette.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var sub := UITheme.make_label("  // rooftop safehouse, sector 9", 16, Palette.DIM)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(sub)
	_credits_label = UITheme.make_title("", 32, Palette.YELLOW)
	header.add_child(_credits_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- Upgrade shop ---
	var shop := PanelContainer.new()
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.size_flags_stretch_ratio = 1.5
	body.add_child(shop)
	var shop_box := VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 8)
	shop.add_child(shop_box)
	shop_box.add_child(UITheme.make_label("CYBERNETIC UPGRADES", 22, Palette.MAGENTA))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	for id in GameState.UPGRADE_ORDER:
		_add_upgrade_row(id)

	# --- Briefing ---
	var brief := PanelContainer.new()
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(brief)
	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 8)
	brief.add_child(bbox)
	var def := GameState.get_mission_def()
	bbox.add_child(UITheme.make_label("NEXT CONTRACT  #%d" % int(def["index"]), 22, Palette.CYAN))
	bbox.add_child(UITheme.make_label(String(def["name"]), 20, Palette.WHITE))
	var desc := UITheme.make_label("Client wants the %s held by %s. Get in, pull the data from the core, reach the EVAC pad." % [def["target"], def["corp"]], 15, Palette.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	bbox.add_child(desc)
	var threat_col := Palette.GREEN if int(def["index"]) <= 2 else (Palette.YELLOW if int(def["index"]) <= 4 else Palette.RED)
	for line in [
		["Threat level", String(def["threat"]), threat_col],
		["Facility", "%d x %d sectors" % [int(def["cols"]), int(def["rows"])], Palette.WHITE],
		["Guards / Drones", "%d / %d" % [int(def["guards"]), int(def["drones"])], Palette.WHITE],
		["Elite hunters", str(def["hunters"]), Palette.PURPLE if int(def["hunters"]) > 0 else Palette.DIM],
		["Cameras", str(def["cameras"]), Palette.WHITE],
		["Payment", "%d CR (+50%% ghost bonus)" % int(def["reward"]), Palette.YELLOW],
	]:
		var row := HBoxContainer.new()
		var l := UITheme.make_label(line[0], 16, Palette.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UITheme.make_label(line[1], 16, line[2]))
		bbox.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bbox.add_child(spacer)
	var stats := GameState.stats
	var stat_label := UITheme.make_label("Missions %d  |  Kills %d  |  Ghost runs %d  |  Deaths %d" % [int(stats.get("missions_completed", 0)), int(stats.get("kills", 0)), int(stats.get("ghost_runs", 0)), int(stats.get("deaths", 0))], 13, Palette.DIM)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bbox.add_child(stat_label)
	var deploy := UITheme.make_button("DEPLOY  >>", _on_deploy, 200)
	deploy.custom_minimum_size.y = 56
	deploy.add_theme_font_size_override("font_size", 26)
	bbox.add_child(deploy)
	bbox.add_child(UITheme.make_button("MAIN MENU", _on_menu, 200))
	deploy.call_deferred("grab_focus")

	_refresh()
	GameState.credits_changed.connect(func(_v): _refresh())
	Sfx.play_music("music")
	Sfx.set_music_pitch(0.9)


func _add_upgrade_row(id: String) -> void:
	var data: Dictionary = GameState.UPGRADES[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	var name_label := UITheme.make_label(String(data["name"]), 18, Palette.WHITE)
	name_row.add_child(name_label)
	var pips := UITheme.make_label("", 18, Palette.CYAN)
	name_row.add_child(pips)
	info.add_child(name_row)
	var d := UITheme.make_label(String(data["desc"]), 13, Palette.DIM)
	info.add_child(d)
	row.add_child(info)
	var btn := UITheme.make_button("", func(): _buy(id), 150)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	_list.add_child(row)
	var sep := HSeparator.new()
	sep.modulate = Color(0.6, 0.4, 1.0, 0.4)
	_list.add_child(sep)
	_rows[id] = {"pips": pips, "button": btn, "row": row}


func _refresh() -> void:
	_credits_label.text = "%d CR" % GameState.credits
	for id in _rows.keys():
		var data: Dictionary = GameState.UPGRADES[id]
		var lvl := GameState.upgrade_level(id)
		var max_lvl := int(data["max"])
		var r: Dictionary = _rows[id]
		(r["pips"] as Label).text = "  " + "[#]".repeat(lvl) + "[ ]".repeat(max_lvl - lvl)
		var b: Button = r["button"]
		if lvl >= max_lvl:
			b.text = "MAXED"
			b.disabled = true
		else:
			b.text = "%d CR" % GameState.upgrade_cost(id)
			b.disabled = not GameState.can_buy_upgrade(id)


func _buy(id: String) -> void:
	if GameState.buy_upgrade(id):
		Sfx.play("pickup")
		var r: Dictionary = _rows[id]
		var row: Control = r["row"]
		var tw := create_tween()
		row.modulate = Color(0.6, 2.0, 1.4)
		tw.tween_property(row, "modulate", Color.WHITE, 0.4)
	else:
		Sfx.play("denied")
	_refresh()


func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
