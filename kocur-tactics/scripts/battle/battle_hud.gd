extends Control
## Battle interface: top bar, objective/unit/tile/log panels on the right,
## the action bar at the bottom, banners and floating text.

const UI = preload("res://scripts/ui/ui_kit.gd")
const UD = preload("res://scripts/data/units_data.gd")
const Grid = preload("res://scripts/core/grid.gd")

const HAZARD_NAMES := {"wood": "Thorns", "border": "Caltrops", "crown": "Embers"}

var mission_label: Label
var turn_label: Label
var phase_label: Label
var phase_panel: PanelContainer
var threat_button: Button
var menu_button: Button
var objective_label: Label
var optional_box: VBoxContainer
var unit_portrait: TextureRect
var unit_name: Label
var unit_class: Label
var unit_stats: Label
var unit_status: Label
var unit_hp_bar: ProgressBar
var tile_label: Label
var log_box: RichTextLabel
var preview_label: Label
var action_row: HBoxContainer
var end_button: Button
var banner_label: Label
var region := "wood"


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	# ---- top bar ----
	var top := UI.panel(UI.PANEL_DARK, UI.BORDER)
	top.position = Vector2(8, 4)
	top.size = Vector2(1264, 42)
	add_child(top)
	var th := UI.hbox(12)
	top.add_child(th)
	mission_label = UI.label("", 18, UI.ACCENT)
	mission_label.custom_minimum_size.x = 420
	th.add_child(mission_label)
	turn_label = UI.label("Turn 1", 18)
	turn_label.custom_minimum_size.x = 110
	th.add_child(turn_label)
	phase_panel = UI.panel(Color("1d3a66"), UI.HERO)
	phase_label = UI.label("YOUR TURN", 16, Color.WHITE)
	phase_panel.add_child(phase_label)
	th.add_child(phase_panel)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)
	threat_button = Button.new()
	threat_button.text = "Enemy threat (T)"
	threat_button.toggle_mode = true
	threat_button.focus_mode = Control.FOCUS_NONE
	threat_button.add_theme_font_size_override("font_size", 14)
	th.add_child(threat_button)
	menu_button = Button.new()
	menu_button.text = "Menu (Esc)"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.add_theme_font_size_override("font_size", 14)
	th.add_child(menu_button)
	# ---- right column ----
	var col := UI.vbox(6)
	col.position = Vector2(884, 52)
	col.size = Vector2(388, 576)
	add_child(col)
	var obj := UI.panel()
	col.add_child(obj)
	var ov := UI.vbox(3)
	obj.add_child(ov)
	ov.add_child(UI.label("OBJECTIVE", 13, UI.ACCENT))
	objective_label = UI.wrap_label("", 15)
	objective_label.custom_minimum_size.x = 360
	ov.add_child(objective_label)
	optional_box = UI.vbox(1)
	ov.add_child(optional_box)
	var up := UI.panel()
	up.custom_minimum_size.y = 150
	col.add_child(up)
	var uh := UI.hbox(10)
	up.add_child(uh)
	unit_portrait = UI.icon_rect(null, 72)
	unit_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	uh.add_child(unit_portrait)
	var uv := UI.vbox(2)
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.add_child(uv)
	unit_name = UI.label("No unit selected", 17, UI.TEXT)
	uv.add_child(unit_name)
	unit_class = UI.wrap_label("Click a hero to command it.", 13, UI.TEXT_DIM)
	unit_class.custom_minimum_size.x = 270
	uv.add_child(unit_class)
	unit_hp_bar = ProgressBar.new()
	unit_hp_bar.custom_minimum_size = Vector2(240, 14)
	unit_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.GOOD
	unit_hp_bar.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.6)
	unit_hp_bar.add_theme_stylebox_override("background", bgs)
	uv.add_child(unit_hp_bar)
	unit_stats = UI.label("", 14)
	uv.add_child(unit_stats)
	unit_status = UI.wrap_label("", 13, UI.ACCENT)
	unit_status.custom_minimum_size.x = 270
	uv.add_child(unit_status)
	var tp := UI.panel()
	col.add_child(tp)
	tile_label = UI.wrap_label("Hover a tile to inspect it.", 13, UI.TEXT_DIM)
	tile_label.custom_minimum_size.x = 360
	tp.add_child(tile_label)
	var lp := UI.panel(UI.PANEL_DARK)
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(lp)
	log_box = RichTextLabel.new()
	log_box.scroll_following = true
	log_box.bbcode_enabled = true
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.add_child(log_box)
	# ---- bottom bar ----
	preview_label = UI.label("", 15, UI.ACCENT)
	preview_label.position = Vector2(12, 630)
	preview_label.size = Vector2(1256, 22)
	preview_label.clip_text = true
	add_child(preview_label)
	var bottom := UI.panel(UI.PANEL_DARK, UI.BORDER)
	bottom.position = Vector2(8, 654)
	bottom.size = Vector2(1264, 62)
	add_child(bottom)
	var bh := UI.hbox(8)
	bottom.add_child(bh)
	action_row = UI.hbox(6)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(action_row)
	end_button = Button.new()
	end_button.text = "End Turn (Enter)"
	end_button.custom_minimum_size = Vector2(190, 48)
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.icon = UI.tex("icon_end")
	end_button.expand_icon = false
	end_button.add_theme_font_size_override("font_size", 17)
	bh.add_child(end_button)
	# ---- banner ----
	banner_label = UI.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner_label.position = Vector2(8, 290)
	banner_label.size = Vector2(864, 60)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.add_theme_constant_override("outline_size", 8)
	banner_label.modulate.a = 0.0
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_label)


func set_top(mname: String, turn: int, phase: String, diff: String) -> void:
	mission_label.text = "%s  [%s]" % [mname, UD.DIFFICULTY_INFO[diff]["name"]]
	turn_label.text = "Turn %d" % turn
	if phase == "player":
		phase_label.text = "YOUR TURN"
		phase_panel.add_theme_stylebox_override("panel", UI.box(Color("1d3a66"), UI.HERO))
	elif phase == "enemy":
		phase_label.text = "ENEMY TURN"
		phase_panel.add_theme_stylebox_override("panel", UI.box(Color("5a1d2a"), UI.ENEMY))
	else:
		phase_label.text = "BATTLE OVER"
		phase_panel.add_theme_stylebox_override("panel", UI.box(Color("3a3050"), UI.ACCENT))


func set_objectives(text: String, opts: Array) -> void:
	objective_label.text = text
	for c in optional_box.get_children():
		c.queue_free()
	if not opts.is_empty():
		optional_box.add_child(UI.label("Optional:", 13, UI.TEXT_DIM))
	for o: Dictionary in opts:
		var mark := "[ ]"
		var col := UI.TEXT
		match str(o["state"]):
			"done":
				mark = "[OK]"
				col = UI.GOOD
			"failed":
				mark = "[X]"
				col = UI.BAD
		optional_box.add_child(UI.label("%s %s" % [mark, o["text"]], 13, col))


func show_unit(u: RefCounted, b: RefCounted) -> void:
	if u == null:
		unit_portrait.texture = null
		unit_name.text = "No unit selected"
		unit_class.text = "Click a hero to command it, or an enemy to inspect it."
		unit_stats.text = ""
		unit_status.text = ""
		unit_hp_bar.visible = false
		return
	unit_hp_bar.visible = true
	unit_portrait.texture = UI.unit_portrait(u.kind)
	var side_txt := "Hero" if u.side == "hero" else "Enemy"
	if u.is_object:
		side_txt = "Objective" if u.side == "hero" else "Enemy object"
	unit_name.text = "%s  (%s)" % [u.name, side_txt]
	var role := ""
	if UD.CLASSES.has(u.kind):
		role = "%s - %s" % [UD.CLASSES[u.kind]["name"], UD.CLASSES[u.kind]["role"]]
	elif UD.ENEMIES.has(u.kind):
		role = str(UD.ENEMIES[u.kind]["desc"])
	unit_class.text = role
	unit_hp_bar.max_value = u.max_hp
	unit_hp_bar.value = u.hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.GOOD if u.side == "hero" else UI.BAD
	unit_hp_bar.add_theme_stylebox_override("fill", fill)
	if u.is_object:
		unit_stats.text = "HP %d/%d   DEF %d" % [u.hp, u.max_hp, u.def]
	else:
		unit_stats.text = "HP %d/%d   ATK %d   DEF %d   MOV %d" % [u.hp, u.max_hp, u.atk, u.def, u.effective_move()]
	var st: Array[String] = []
	if u.side == "hero" and not u.is_object:
		if u.acted:
			st.append("Done this turn")
		elif u.moved:
			st.append("Moved - can still act")
		else:
			st.append("Ready")
	if not u.awake:
		st.append("Asleep (Zz)")
	var names := {"stance": "Protective Stance (+3 DEF)", "chilled": "Chilled (-2 MOV)", "exhausted": "EXHAUSTED: DEF 0",
		"drained": "DRAINED: DEF 0", "iron_guard": "Iron Guard (+3 DEF)"}
	for k: String in u.status:
		st.append(names.get(k, k))
	if b.boss_immune(u):
		st.append("IMMUNE while Crown Pylons stand")
	for tg: Dictionary in b.telegraphs:
		if int(tg["uid"]) == u.uid:
			st.append("Preparing: %s" % tg["label"])
	unit_status.text = " | ".join(st)


func show_tile(c: Vector2i, b: RefCounted) -> void:
	if not b.grid.in_bounds(c):
		tile_label.text = ""
		return
	var t: String = b.grid.terrain(c)
	var info: Dictionary = Grid.TERRAIN[t]
	var nm: String = info["name"]
	if t == "hazard":
		nm = HAZARD_NAMES.get(region, nm)
	var lines: Array[String] = ["[%d,%d] %s" % [c.x, c.y, nm]]
	var cost := int(info["cost"])
	lines.append("Move cost: %s   Cover DEF: +%d" % ["impassable" if cost == 0 else str(cost), int(info["def"])])
	lines.append(str(info["desc"]))
	if b.exits.has(c):
		lines.append("Exit tile: units that must escape can use Escape here.")
	if b.defend_cells.has(c):
		lines.append("Shrine tile: no enemy may stand here at the end of their turn!")
	if b.relics.has(c):
		lines.append("Relic altar: " + ("claimed" if b.claimed.has(c) else "stand here and Claim"))
	if c == b.treasure_cell and not b.treasure_taken:
		lines.append("Treasure! Move a hero here to grab it.")
	tile_label.text = "\n".join(lines)


func set_preview(text: String) -> void:
	preview_label.text = text


func add_log(text: String) -> void:
	log_box.append_text(text + "\n")


func clear_actions() -> void:
	for c in action_row.get_children():
		c.queue_free()


func add_action(text: String, icon_name: String, enabled: bool, active: bool, tip: String, cb: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.icon = UI.tex(icon_name) if icon_name != "" else null
	bt.disabled = not enabled
	bt.focus_mode = Control.FOCUS_NONE
	bt.custom_minimum_size = Vector2(0, 48)
	bt.add_theme_font_size_override("font_size", 14)
	bt.tooltip_text = tip
	if active:
		bt.add_theme_stylebox_override("normal", UI.box(Color("4a3a72"), UI.ACCENT, 3))
	bt.pressed.connect(cb)
	bt.mouse_entered.connect(func() -> void: set_preview(tip.split("\n")[0]))
	action_row.add_child(bt)
	return bt


func banner(text: String, color := Color.WHITE, hold := 0.9) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	var tw := create_tween()
	banner_label.modulate.a = 0.0
	tw.tween_property(banner_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(hold)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.3)
