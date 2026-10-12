extends Control
## Campaign hub: mission select (with squad selection), roster, upgrades,
## tactical challenges and campaign records.

const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")
const Missions = preload("res://scripts/data/missions.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const TABS := ["missions", "roster", "upgrades", "challenges", "records"]
const TAB_NAMES := {"missions": "Missions", "roster": "Roster", "upgrades": "Upgrades", "challenges": "Challenges",
	"records": "Records"}
const MEDALS := ["-", "Bronze", "Silver", "Gold"]
const OBJ_NAMES := {"eliminate": "Eliminate", "defend": "Defend", "survive": "Survive waves", "escape": "Reach extraction",
	"rescue_escape": "Rescue & escape", "escort": "Escort", "protect": "Protect objective", "commander": "Defeat commander",
	"claim": "Secure relics", "boss": "BOSS"}

var tab := "missions"
var content: Control
var shards_label: Label
var tab_buttons := {}
var modal_layer: Control
var selected_mission := ""
var squad: Array[String] = []
var upgrade_hero := "nox"


func _ready() -> void:
	theme = UI.theme()
	if not Campaign.has_progress():
		Campaign.data["started"] = true
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var top := UI.panel(UI.PANEL_DARK)
	top.position = Vector2(8, 6)
	top.size = Vector2(1264, 48)
	add_child(top)
	var th := UI.hbox(8)
	top.add_child(th)
	th.add_child(UI.label("KOCUR TACTICS", 20, UI.ACCENT))
	for t: String in TABS:
		var tt := t
		var bt := UI.button(TAB_NAMES[t], func() -> void: show_tab(tt), 120, 15)
		bt.name = "Tab_" + t
		th.add_child(bt)
		tab_buttons[t] = bt
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)
	shards_label = UI.label("", 16, UI.ACCENT)
	th.add_child(shards_label)
	th.add_child(UI.button("Settings", func() -> void: SettingsPanel.open(modal_layer), 0, 15))
	th.add_child(UI.button("Main Menu", func() -> void: Transition.go_menu(), 0, 15))
	content = Control.new()
	content.position = Vector2(8, 62)
	content.size = Vector2(1264, 650)
	add_child(content)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	Campaign.changed.connect(_update_shards)
	selected_mission = Campaign.next_mission()
	var want: String = Transition.campaign_tab
	Transition.campaign_tab = ""
	Audio.play_music("campaign")
	show_tab(want if want in TABS else "missions")


func _update_shards() -> void:
	if is_instance_valid(shards_label):
		shards_label.text = "Relic Shards: %d" % int(Campaign.data["shards"])


func show_tab(t: String) -> void:
	tab = t
	for k: String in tab_buttons:
		var bt: Button = tab_buttons[k]
		if k == t:
			bt.add_theme_stylebox_override("normal", UI.box(Color("4a3a72"), UI.ACCENT, 3))
		else:
			bt.remove_theme_stylebox_override("normal")
	for c in content.get_children():
		c.queue_free()
	_update_shards()
	match t:
		"missions": _build_missions()
		"roster": _build_roster()
		"upgrades": _build_upgrades()
		"challenges": _build_challenges()
		"records": _build_records()


# --------------------------------------------------------------------------
# Missions
# --------------------------------------------------------------------------

func _build_missions() -> void:
	var left := UI.panel()
	left.position = Vector2(0, 0)
	left.size = Vector2(420, 650)
	content.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var lv := UI.vbox(4)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lv)
	var act := 0
	for m: Dictionary in Missions.MISSIONS:
		if int(m["act"]) != act:
			act = int(m["act"])
			lv.add_child(UI.label(Missions.ACTS[act]["name"], 15, UI.ACCENT))
		var id: String = m["id"]
		var unlocked := Campaign.is_unlocked(id)
		var rec := Campaign.mission_record(id)
		var txt := "%d. %s" % [Missions.index_of(id) + 1, m["name"]] if unlocked else "%d. ???  (locked)" % (Missions.index_of(id) + 1)
		if unlocked and bool(rec.get("completed", false)):
			txt += "   [%s]" % MEDALS[int(rec.get("medal", 0))]
		var idc := id
		var bt := UI.button(txt, func() -> void:
			selected_mission = idc
			squad.clear()
			show_tab("missions"), 380, 15)
		bt.name = "Mission_" + id
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.disabled = not unlocked
		if id == selected_mission:
			bt.add_theme_stylebox_override("normal", UI.box(Color("4a3a72"), UI.ACCENT, 3))
		lv.add_child(bt)
	_build_mission_detail()


func _build_mission_detail() -> void:
	var m := Missions.get_mission(selected_mission)
	var right := UI.panel()
	right.position = Vector2(432, 0)
	right.size = Vector2(832, 650)
	content.add_child(right)
	var v := UI.vbox(8)
	right.add_child(v)
	if m.is_empty() or not Campaign.is_unlocked(selected_mission):
		v.add_child(UI.label("Select an unlocked mission.", 18))
		return
	var act: Dictionary = Missions.ACTS[int(m["act"])]
	v.add_child(UI.label(act["name"], 14, UI.TEXT_DIM))
	if Missions.index_of(selected_mission) in [0, 4, 8]:
		v.add_child(UI.wrap_label(act["intro"], 14, UI.TEXT_DIM))
	v.add_child(UI.label(str(m["name"]), 26, UI.ACCENT))
	var ot: String = m["objective"]["type"]
	v.add_child(UI.label("Mission type: %s" % OBJ_NAMES.get(ot, ot), 15, UI.ENEMY if ot == "boss" else UI.HERO))
	v.add_child(UI.wrap_label(str(m["brief"]), 15))
	v.add_child(UI.label("Objective: " + str(m["objective"]["text"]) + (
		"  (turn limit %d)" % int(m["turn_limit"]) if m.has("turn_limit") else ""), 15, UI.GOOD))
	var rec := Campaign.mission_record(selected_mission)
	var opts: Array = rec.get("optional", [])
	var i := 0
	for o: Dictionary in m["optional"]:
		var done := i < opts.size() and bool(opts[i])
		v.add_child(UI.label("%s Optional: %s  (+%d shards)" % ["[OK]" if done else "[  ]", o["text"], int(o.get("shards", 1))],
			14, UI.GOOD if done else UI.TEXT))
		i += 1
	if bool(rec.get("completed", false)):
		v.add_child(UI.label("Completed - best %d turns - medal: %s" % [int(rec["best_turns"]), MEDALS[int(rec["medal"])]], 14, UI.ACCENT))
	else:
		v.add_child(UI.label("First clear reward: +%d Relic Shards and XP for the squad" % int(m.get("shards", 3)), 14, UI.ACCENT))
	# squad selection
	var slots := int(m.get("slots", 3))
	var avail := Campaign.available_heroes(selected_mission)
	if squad.is_empty():
		squad = Campaign.default_squad(selected_mission)
	v.add_child(UI.label("Squad (%d/%d) - click to add or remove:" % [squad.size(), slots], 16, UI.ACCENT))
	var row := UI.hbox(8)
	v.add_child(row)
	for hid in avail:
		var hc := hid
		var lvl := Campaign.hero_level(hid)
		var in_squad := squad.has(hid)
		var bt := Button.new()
		bt.name = "Squad_" + hid
		bt.text = "%s\nLv %d %s" % [UD.HEROES[hid]["name"], lvl, UD.CLASSES[UD.HEROES[hid]["class"]]["name"]]
		bt.icon = UI.unit_portrait(UD.HEROES[hid]["class"])
		bt.expand_icon = true
		bt.custom_minimum_size = Vector2(150, 64)
		bt.add_theme_font_size_override("font_size", 12)
		bt.add_theme_constant_override("icon_max_width", 36)
		if in_squad:
			bt.add_theme_stylebox_override("normal", UI.box(Color("1d3a66"), UI.HERO, 3))
		bt.pressed.connect(func() -> void:
			if squad.has(hc):
				squad.erase(hc)
				Audio.play("ui_back")
			elif squad.size() < slots:
				squad.append(hc)
				Audio.play("ui_ok")
			else:
				Audio.play("denied")
			show_tab("missions"))
		row.add_child(bt)
	if avail.size() < UD.HERO_ORDER.size() and m.has("captives"):
		v.add_child(UI.label("A hero held captive in this mission cannot be deployed here.", 13, UI.TEXT_DIM))
	var start := UI.button("Start Mission", func() -> void:
		if squad.is_empty():
			Audio.play("denied")
			return
		Transition.go_battle(selected_mission, squad), 240, 18)
	start.name = "StartMission"
	start.disabled = squad.is_empty()
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(start)
	start.call_deferred("grab_focus")


# --------------------------------------------------------------------------
# Roster
# --------------------------------------------------------------------------

func _build_roster() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for hid: String in UD.HERO_ORDER:
		var card := UI.panel()
		card.custom_minimum_size = Vector2(416, 316)
		grid.add_child(card)
		var v := UI.vbox(4)
		card.add_child(v)
		var hd: Dictionary = UD.HEROES[hid]
		if not Campaign.is_recruited(hid):
			v.add_child(UI.label("??? - not yet recruited", 18, UI.TEXT_DIM))
			var where := Missions.get_mission(str(hd.get("joins", "")))
			v.add_child(UI.wrap_label("Joins after: %s" % (where["name"] if Campaign.is_completed(where["id"]) or Campaign.is_unlocked(where["id"]) else "a later mission"), 14, UI.TEXT_DIM))
			continue
		var cls: Dictionary = UD.CLASSES[hd["class"]]
		var h := UI.hbox(10)
		v.add_child(h)
		h.add_child(UI.icon_rect(UI.unit_portrait(hd["class"]), 64))
		var hv := UI.vbox(2)
		h.add_child(hv)
		var lvl := Campaign.hero_level(hid)
		hv.add_child(UI.label("%s  -  %s  Lv %d" % [hd["name"], cls["name"], lvl], 18, UI.ACCENT))
		var xp := Campaign.hero_xp(hid)
		var xp_txt := "MAX LEVEL" if lvl >= UD.MAX_LEVEL else "XP %d / %d" % [xp % UD.XP_PER_LEVEL, UD.XP_PER_LEVEL]
		hv.add_child(UI.label(xp_txt, 13, UI.TEXT_DIM))
		var st := Campaign.hero_stats(hid)
		hv.add_child(UI.label("HP %d  ATK %d  DEF %d  MOV %d" % [st["hp"], st["atk"], st["def"], st["move"]], 15))
		v.add_child(UI.wrap_label(cls["role"], 13, UI.HERO))
		for a: String in cls["abilities"]:
			var ab := UD.ability(a)
			v.add_child(UI.wrap_label("%s: %s" % [ab["name"], ab["desc"]], 12))
		v.add_child(UI.wrap_label(hd["bio"], 12, UI.TEXT_DIM))


# --------------------------------------------------------------------------
# Upgrades
# --------------------------------------------------------------------------

func _build_upgrades() -> void:
	if not Campaign.is_recruited(upgrade_hero):
		upgrade_hero = "nox"
	var left := UI.panel()
	left.size = Vector2(300, 650)
	content.add_child(left)
	var lv := UI.vbox(6)
	left.add_child(lv)
	lv.add_child(UI.label("Choose a hero", 16, UI.ACCENT))
	for hid in Campaign.recruited():
		var hc := hid
		var bt := UI.button("%s (Lv %d)" % [UD.HEROES[hid]["name"], Campaign.hero_level(hid)], func() -> void:
			upgrade_hero = hc
			show_tab("upgrades"), 260, 15)
		bt.name = "UpHero_" + hid
		bt.icon = UI.unit_portrait(UD.HEROES[hid]["class"])
		bt.expand_icon = true
		bt.add_theme_constant_override("icon_max_width", 28)
		if hid == upgrade_hero:
			bt.add_theme_stylebox_override("normal", UI.box(Color("4a3a72"), UI.ACCENT, 3))
		lv.add_child(bt)
	lv.add_child(UI.wrap_label("Relic Shards come from first clears and optional objectives. Upgrades are permanent and never required - the campaign is beatable without them.", 13, UI.TEXT_DIM))
	var right := UI.panel()
	right.position = Vector2(312, 0)
	right.size = Vector2(952, 650)
	content.add_child(right)
	var v := UI.vbox(10)
	right.add_child(v)
	var hd: Dictionary = UD.HEROES[upgrade_hero]
	var st := Campaign.hero_stats(upgrade_hero)
	v.add_child(UI.label("%s the %s" % [hd["name"], UD.CLASSES[hd["class"]]["name"]], 24, UI.ACCENT))
	v.add_child(UI.label("Current stats: HP %d  ATK %d  DEF %d  MOV %d" % [st["hp"], st["atk"], st["def"], st["move"]], 16))
	for up: String in UD.UPGRADE_ORDER:
		var info: Dictionary = UD.UPGRADES[up]
		var rank := Campaign.upgrade_rank(upgrade_hero, up)
		var maxr: int = (info["costs"] as Array).size()
		var desc: String = info["desc"] if up != "special" else UD.SPECIAL_DESC[hd["class"]]
		var row := UI.hbox(12)
		v.add_child(row)
		var l := UI.label("%s  (%d/%d)" % [info["name"], rank, maxr], 17)
		l.custom_minimum_size.x = 240
		row.add_child(l)
		var d := UI.label(desc, 15, UI.TEXT_DIM)
		d.custom_minimum_size.x = 420
		row.add_child(d)
		var cost := Campaign.upgrade_cost(upgrade_hero, up)
		var upc := up
		var bt := UI.button("MAXED" if cost < 0 else "Buy (%d shards)" % cost, func() -> void:
			if Campaign.buy(upgrade_hero, upc):
				Audio.play("buy")
			else:
				Audio.play("denied")
			show_tab("upgrades"), 200, 15)
		bt.name = "Buy_" + up
		bt.disabled = not Campaign.can_buy(upgrade_hero, up)
		row.add_child(bt)


# --------------------------------------------------------------------------
# Challenges and records
# --------------------------------------------------------------------------

func _build_challenges() -> void:
	var v := UI.vbox(10)
	v.size = Vector2(1264, 650)
	content.add_child(v)
	v.add_child(UI.label("TACTICAL CHALLENGES", 24, UI.ACCENT))
	v.add_child(UI.wrap_label("Hand-made puzzles with a fixed squad. Your roster's levels and upgrades do not apply. Unlocked by finishing each act.", 15, UI.TEXT_DIM))
	for c: Dictionary in Missions.CHALLENGES:
		var p := UI.panel()
		v.add_child(p)
		var h := UI.hbox(16)
		p.add_child(h)
		var cv := UI.vbox(4)
		cv.custom_minimum_size.x = 960
		h.add_child(cv)
		var id: String = c["id"]
		var unlocked := Campaign.is_unlocked(id)
		cv.add_child(UI.label(str(c["name"]), 19, UI.ACCENT if unlocked else UI.TEXT_DIM))
		if unlocked:
			cv.add_child(UI.wrap_label(str(c["brief"]), 14))
			var names: Array[String] = []
			for pair: Array in c["squad"]:
				names.append("%s Lv %d" % [UD.HEROES[pair[0]]["name"], int(pair[1])])
			cv.add_child(UI.label("Squad: " + ", ".join(names), 14, UI.HERO))
			var rec: Dictionary = Campaign.data["challenges"].get(id, {})
			if bool(rec.get("completed", false)):
				cv.add_child(UI.label("Completed - best %d turns" % int(rec["best_turns"]), 14, UI.GOOD))
		else:
			var um := Missions.get_mission(str(c["unlock"]))
			cv.add_child(UI.label("Locked - complete mission %d (%s) to unlock." % [Missions.index_of(um["id"]) + 1,
				um["name"] if Campaign.is_unlocked(um["id"]) else "???"], 14, UI.TEXT_DIM))
		var idc := id
		var squad_ids := []
		for pair: Array in c["squad"]:
			squad_ids.append(pair[0])
		var bt := UI.button("Start", func() -> void: Transition.go_battle(idc, squad_ids), 160, 17)
		bt.name = "Challenge_" + id
		bt.disabled = not unlocked
		h.add_child(bt)


func _build_records() -> void:
	var p := UI.panel()
	p.size = Vector2(1264, 650)
	content.add_child(p)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("CAMPAIGN RECORDS", 24, UI.ACCENT))
	var d: Dictionary = Campaign.data
	v.add_child(UI.label("Difficulty: %s" % UD.DIFFICULTY_INFO[Campaign.difficulty()]["name"], 16))
	v.add_child(UI.label("Missions completed: %d / 12" % Campaign.completed_count(), 16))
	v.add_child(UI.label("Medal points: %d / 36" % Campaign.medal_count(), 16))
	var opt_done := 0
	var opt_total := 0
	for m: Dictionary in Missions.MISSIONS:
		var r := Campaign.mission_record(m["id"])
		opt_total += (m["optional"] as Array).size()
		for x: Variant in r.get("optional", []):
			if bool(x):
				opt_done += 1
	v.add_child(UI.label("Optional objectives: %d / %d" % [opt_done, opt_total], 16))
	var ch := 0
	for id: String in Missions.challenge_ids():
		if Campaign.is_completed(id):
			ch += 1
	v.add_child(UI.label("Tactical challenges: %d / %d" % [ch, Missions.CHALLENGES.size()], 16))
	v.add_child(UI.label("Battles won: %d   lost: %d" % [int(d["battles_won"]), int(d["battles_lost"])], 16))
	v.add_child(UI.label("Heroes recruited: %d / %d" % [Campaign.recruited().size(), UD.HERO_ORDER.size()], 16))
	v.add_child(UI.label("Relic Shards earned: %d" % int(d["shards_earned"]), 16))
	v.add_child(UI.label("CAMPAIGN COMPLETE - the valley is free!" if bool(d["campaign_complete"]) else "The Pale King still sits on his throne...",
		18, UI.GOOD if bool(d["campaign_complete"]) else UI.TEXT_DIM))
	if bool(d["campaign_complete"]):
		v.add_child(UI.button("Watch the ending again", func() -> void: Transition.go_ending(), 260))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for m: Dictionary in Missions.MISSIONS:
		var r := Campaign.mission_record(m["id"])
		var txt := "%d. %s" % [Missions.index_of(m["id"]) + 1, m["name"]]
		if bool(r.get("completed", false)):
			txt += "  %s, %d turns" % [MEDALS[int(r["medal"])], int(r["best_turns"])]
		else:
			txt += "  -"
		grid.add_child(UI.label(txt, 13, UI.TEXT if bool(r.get("completed", false)) else UI.TEXT_DIM))
