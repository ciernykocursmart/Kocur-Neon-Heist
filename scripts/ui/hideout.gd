extends Control
## The safehouse between missions: upgrade shop, armory overview, intel
## archive, campaign/endless briefing and deploy.

var _credits_label: Label
var _rows := {}
var _list: VBoxContainer
var _tab_pages := {}
var _tab_buttons := {}


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
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UITheme.make_title("HIDEOUT", 42, Palette.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var sub := UITheme.make_label("  // rooftop safehouse, sector 9", 16, Palette.DIM)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(sub)
	_credits_label = UITheme.make_title("", 32, Palette.YELLOW)
	header.add_child(_credits_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- Left: tabbed panel ---
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45
	body.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left.add_child(left_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left_box.add_child(tabs)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(pages)
	for t in [["upgrades", "UPGRADES"], ["armory", "ARMORY"], ["intel", "INTEL %d/%d" % [GameState.intel.size(), Campaign.INTEL.size()]]]:
		var b := UITheme.make_button(t[1], _show_tab.bind(t[0]), 150)
		b.custom_minimum_size.y = 36
		b.add_theme_font_size_override("font_size", 16)
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pages.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		scroll.add_child(page)
		_tab_pages[t[0]] = scroll
		match t[0]:
			"upgrades":
				_list = page
				for id in GameState.UPGRADE_ORDER:
					_add_upgrade_row(id)
			"armory":
				_build_armory(page)
			"intel":
				_build_intel(page)

	# --- Right: briefing ---
	var brief := PanelContainer.new()
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(brief)
	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 7)
	brief.add_child(bbox)
	_build_briefing(bbox)

	_show_tab("upgrades")
	_refresh()
	GameState.credits_changed.connect(func(_v): _refresh())
	Sfx.play_music("music")
	Sfx.set_music_pitch(0.9)


func _show_tab(id: String) -> void:
	for k in _tab_pages.keys():
		(_tab_pages[k] as Control).visible = k == id
		var b: Button = _tab_buttons[k]
		b.modulate = Color.WHITE if k == id else Color(0.6, 0.6, 0.7)


func _build_briefing(bbox: VBoxContainer) -> void:
	var finale_replay := GameState.campaign_complete and not GameState.is_endless()
	var def := GameState.get_mission_def()
	var act_col := Palette.CYAN
	if not GameState.is_endless():
		act_col = Campaign.ACTS[int(def["act"])]["color"]
	bbox.add_child(UITheme.make_label(String(def.get("act_label", "")), 15, act_col))
	if finale_replay:
		bbox.add_child(UITheme.make_label("CAMPAIGN COMPLETE", 22, Palette.GREEN))
		var done := UITheme.make_label("CRADLE has fallen. Replay the finale, or switch to the Endless Heist for ever-harder contracts and bigger payouts.", 14, Palette.DIM)
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		done.custom_minimum_size = Vector2(300, 0)
		bbox.add_child(done)
	bbox.add_child(UITheme.make_label(String(def["name"]), 21, Palette.WHITE))
	var desc := UITheme.make_label(String(def.get("briefing", "")), 14, Palette.DIM.lerp(Palette.WHITE, 0.3))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	bbox.add_child(desc)
	var objective := String(def.get("objective", "data"))
	var obj_text := "Steal %s, then reach EVAC" % def["target"]
	if objective == "shards":
		obj_text = "Steal %s from %d cores, then reach EVAC" % [def["target"], int(def["shards"])]
	elif objective == "final":
		obj_text = "Breach 3 uplinks, destroy the WARDEN, take the archive, escape"
	var obj := UITheme.make_label("OBJECTIVE: " + obj_text, 14, Palette.YELLOW)
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.custom_minimum_size = Vector2(300, 0)
	bbox.add_child(obj)
	var idx := int(def["index"])
	var threat_col := Palette.GREEN if idx <= 3 else (Palette.YELLOW if idx <= 6 else (Palette.ORANGE if idx <= 9 else Palette.RED))
	var lines := [
		["Location", String(def["corp"]), Palette.WHITE],
		["Threat level", String(def["threat"]), threat_col],
		["Facility", "%d x %d sectors" % [int(def["cols"]), int(def["rows"])], Palette.WHITE],
		["Guards / Drones", "%d / %d" % [int(def["guards"]), int(def["drones"])], Palette.WHITE],
		["Hunters / Enforcers", "%d / %d" % [int(def["hunters"]), int(def.get("enforcers", 0))], Palette.PURPLE if int(def["hunters"]) + int(def.get("enforcers", 0)) > 0 else Palette.DIM],
		["Payment", "%d CR  (+50%% ghost bonus)" % int(def["reward"]), Palette.YELLOW],
	]
	if GameState.is_endless():
		lines.append(["Best depth", str(GameState.endless_best), Palette.CYAN])
	for line in lines:
		var row := HBoxContainer.new()
		var l := UITheme.make_label(line[0], 15, Palette.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UITheme.make_label(line[1], 15, line[2]))
		bbox.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bbox.add_child(spacer)
	var deploy := UITheme.make_button("DEPLOY  >>" if not finale_replay else "REPLAY FINALE  >>", _on_deploy, 200)
	deploy.custom_minimum_size.y = 54
	deploy.add_theme_font_size_override("font_size", 24)
	bbox.add_child(deploy)
	if GameState.campaign_complete:
		var switch_text := "SWITCH TO CAMPAIGN" if GameState.is_endless() else "ENDLESS HEIST"
		bbox.add_child(UITheme.make_button(switch_text, _toggle_mode, 200))
	bbox.add_child(UITheme.make_button("MAIN MENU", _on_menu, 200))
	deploy.call_deferred("grab_focus")


func _build_armory(page: VBoxContainer) -> void:
	page.add_child(UITheme.make_label("LOADOUT", 20, Palette.MAGENTA))
	for i in Weapons.ORDER.size():
		var id: String = Weapons.ORDER[i]
		var w := Weapons.get_data(id)
		var owned := GameState.weapon_unlocked(id)
		var col: Color = w["color"] if owned else Palette.DIM
		var head := UITheme.make_label("[%d] %s  -  %s" % [i + 1, w["name"], w["role"]], 18, col)
		page.add_child(head)
		if owned:
			var stats := "DMG %d%s  |  RATE %.1f/s  |  MAG %d  |  RELOAD %.1fs" % [
				int(float(w["damage"]) * GameState.damage_multiplier()),
				(" x%d" % int(w["pellets"])) if int(w["pellets"]) > 1 else "",
				1.0 / float(w["interval"]),
				GameState.weapon_mag(id),
				float(w["reload"]) * GameState.reload_multiplier(),
			]
			page.add_child(UITheme.make_label(stats, 13, Palette.WHITE))
			var d := UITheme.make_label(String(w["desc"]), 13, Palette.DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			page.add_child(d)
		else:
			page.add_child(UITheme.make_label("Locked - delivered by MOTH before mission %d." % int(GameState.WEAPON_UNLOCK[id]), 13, Palette.DIM))
		page.add_child(HSeparator.new())
	page.add_child(UITheme.make_label("GADGETS", 20, Palette.MAGENTA))
	var g := UITheme.make_label("Yarn decoy x%d per mission [G]: lands where you aim and squeaks three times, luring guards." % Player.DECOY_CHARGES, 13, Palette.DIM)
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(g)


func _build_intel(page: VBoxContainer) -> void:
	page.add_child(UITheme.make_label("RECOVERED INTEL", 20, Palette.GREEN))
	if GameState.intel.is_empty():
		var none := UITheme.make_label("Nothing yet. Every campaign mission hides one green intel fragment - find it and press E.", 14, Palette.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(none)
	for i in Campaign.INTEL.size():
		var data: Dictionary = Campaign.INTEL[i]
		if GameState.has_intel(i):
			page.add_child(UITheme.make_label("%02d  %s" % [i + 1, data["title"]], 16, Palette.GREEN))
			var t := UITheme.make_label(String(data["text"]), 13, Palette.WHITE)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			page.add_child(t)
		else:
			page.add_child(UITheme.make_label("%02d  [ ENCRYPTED - mission %d ]" % [i + 1, i + 1], 14, Color(0.4, 0.42, 0.55)))


func _add_upgrade_row(id: String) -> void:
	var data: Dictionary = GameState.UPGRADES[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_child(UITheme.make_label(String(data["name"]), 17, Palette.WHITE))
	var pips := UITheme.make_label("", 17, Palette.CYAN)
	name_row.add_child(pips)
	info.add_child(name_row)
	info.add_child(UITheme.make_label(String(data["desc"]), 12, Palette.DIM))
	row.add_child(info)
	var btn := UITheme.make_button("", func(): _buy(id), 130)
	btn.custom_minimum_size.y = 38
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
		Sfx.play("upgrade")
		var r: Dictionary = _rows[id]
		var row: Control = r["row"]
		row.modulate = Color(0.6, 2.0, 1.4)
		create_tween().tween_property(row, "modulate", Color.WHITE, 0.4)
	else:
		Sfx.play("denied")
	_refresh()


func _toggle_mode() -> void:
	if GameState.is_endless():
		GameState.start_campaign_mode()
	else:
		GameState.start_endless()
	Transition.change_scene("res://scenes/hideout.tscn")


func _on_deploy() -> void:
	Transition.change_scene("res://scenes/game.tscn")


func _on_menu() -> void:
	Transition.change_scene("res://scenes/main_menu.tscn")
