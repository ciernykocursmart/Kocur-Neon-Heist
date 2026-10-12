extends Control
## The camp (hub): level select, permanent upgrade shop, rescued cats,
## records. Rescued cats appear around the campfire.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Sprites := preload("res://scripts/fx/sprites.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

const TABS := ["levels", "upgrades", "cats", "records"]
const TAB_NAMES := {"levels": "Adventure", "upgrades": "Upgrades", "cats": "Cats", "records": "Records"}

var tab := "levels"
var tab_buttons := {}
var level_buttons := {}   ## level id -> Button (tests)
var buy_buttons := {}     ## upgrade id -> Button (tests)
var _bar: HBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _scene: Control
var _fire: Node2D
var _cats_root: Node2D
var _overlay: CenterContainer


class Campfire extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-14, -2, 28, 4), Color(0.35, 0.22, 0.14))
		draw_rect(Rect2(-10, -5, 20, 3), Color(0.45, 0.28, 0.16))
		for i in 5:
			var ph := t * 7.0 + i * 1.7
			var h := 12.0 + sin(ph) * 4.0 + (i % 2) * 3.0
			var x := -8.0 + i * 4.0
			draw_rect(Rect2(x - 2, -5 - h, 4, h), Color(1.0, 0.45 + 0.1 * sin(ph), 0.15, 0.9))
			draw_rect(Rect2(x - 1, -5 - h * 0.6, 2, h * 0.6), Color(1.0, 0.85, 0.4))
		var glow := 0.18 + 0.04 * sin(t * 5.0)
		draw_circle(Vector2(0, -10), 46, Color(1.0, 0.55, 0.2, glow * 0.35))


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	if Transition.camp_tab in TABS:
		tab = Transition.camp_tab
	Transition.camp_tab = ""
	Audio.play_music("camp")
	_build()
	refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var far := TextureRect.new()
	far.texture = Sprites.texture("bg_r1_far.png")
	far.stretch_mode = TextureRect.STRETCH_TILE
	far.size = Vector2(320, 180)
	far.scale = Vector2(2, 2)
	far.modulate = Color(0.6, 0.55, 0.7)
	add_child(far)
	# Campfire scene on the left.
	_scene = Control.new()
	_scene.position = Vector2(0, 0)
	_scene.size = Vector2(224, 360)
	add_child(_scene)
	var ground := ColorRect.new()
	ground.color = Color(0.11, 0.09, 0.15)
	ground.position = Vector2(0, 300)
	ground.size = Vector2(224, 60)
	_scene.add_child(ground)
	_fire = Campfire.new()
	_fire.position = Vector2(112, 300)
	_scene.add_child(_fire)
	_cats_root = Node2D.new()
	_scene.add_child(_cats_root)
	# Top bar + tabs.
	var top := VBoxContainer.new()
	top.position = Vector2(8, 4)
	top.size = Vector2(624, 40)
	add_child(top)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	top.add_child(_bar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	top.add_child(tabs)
	for t: String in TABS:
		var b := UI.button(TAB_NAMES[t], func() -> void: show_tab(t), 84)
		b.toggle_mode = true
		tabs.add_child(b)
		tab_buttons[t] = b
	tabs.add_child(UI.button("Settings", show_settings, 70))
	tabs.add_child(UI.button("Main Menu", func() -> void: Transition.go_menu(), 80))
	# Content panel.
	var panel := UI.panel()
	panel.position = Vector2(228, 50)
	panel.size = Vector2(404, 302)
	add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(396, 294)
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(384, 0)
	_content.add_theme_constant_override("separation", 3)
	_scroll.add_child(_content)


func refresh() -> void:
	_refresh_bar()
	_refresh_cats()
	show_tab(tab)


func _refresh_bar() -> void:
	for c in _bar.get_children():
		c.queue_free()
	_bar.add_child(UI.label("CAMP", 20, UI.C_GOLD))
	_stat(_bar, "coin", str(Progress.coins()))
	_stat(_bar, "gem", "%d/%d" % [Progress.total_gems(), LevelCatalog.all_gems()])
	_stat(_bar, "cat", "%d/%d" % [Progress.data["rescued"].size(), GameData.CAT_ORDER.size()])
	_stat(_bar, "relic", "%d/5" % Progress.data["relics"].size())
	_stat(_bar, "star", "%d%%" % Progress.completion_percent())


func _stat(box: Container, icon: String, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.add_child(UI.icon_rect(icon))
	h.add_child(UI.label(text, 10))
	box.add_child(h)


## Rescued cats sit around the fire - the camp grows as you free them.
func _refresh_cats() -> void:
	for c in _cats_root.get_children():
		c.queue_free()
	var hero := Sprites.make_sprite("hero", "idle")
	hero.position = Vector2(80, 286)
	_cats_root.add_child(hero)
	var spots := [Vector2(144, 286), Vector2(40, 290), Vector2(180, 290), Vector2(60, 268), Vector2(164, 266),
		Vector2(20, 270), Vector2(200, 270), Vector2(100, 252), Vector2(130, 254), Vector2(112, 236)]
	var i := 0
	for cat: String in GameData.CAT_ORDER:
		if not Progress.has_cat(cat):
			continue
		var s := AnimatedSprite2D.new()
		s.sprite_frames = Sprites.captive_frames(int(GameData.CATS[cat]["color"]))
		s.play("default")
		s.frame = i % 4
		s.position = spots[i % spots.size()]
		s.flip_h = s.position.x > 112
		_cats_root.add_child(s)
		i += 1
	if i == 0:
		var l := UI.label("Your friends are\nstill captive...", 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		l.position = Vector2(40, 200)
		l.size = Vector2(144, 30)
		_cats_root.add_child(l)


func _clear_content() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_scroll.visible = true
	for c in _content.get_children():
		c.queue_free()
	level_buttons.clear()
	buy_buttons.clear()


func show_tab(t: String) -> void:
	tab = t
	for k in tab_buttons:
		tab_buttons[k].set_pressed_no_signal(k == t)
	_clear_content()
	match t:
		"levels": _build_levels()
		"upgrades": _build_upgrades()
		"cats": _build_cats()
		"records": _build_records()
	_scroll.scroll_vertical = 0
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var first: Control = _first_focusable(_content)
	if first:
		first.grab_focus()
	elif tab_buttons.has(t):
		tab_buttons[t].grab_focus()


func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button and not (c as Button).disabled:
			return c
		var r := _first_focusable(c)
		if r:
			return r
	return null


# --------------------------------------------------------------------------
# Adventure / level select
# --------------------------------------------------------------------------

func _build_levels() -> void:
	var nxt := Progress.next_level_id()
	var cont := UI.button("Continue: " + LevelCatalog.level_title(nxt), func() -> void: Transition.go_level(nxt), 380)
	level_buttons["continue"] = cont
	_content.add_child(cont)
	if Progress.run_blessings.size() == 0 and Progress.is_completed(nxt):
		pass
	var region := 0
	for lv: Dictionary in LevelCatalog.LEVELS:
		var id: String = lv["id"]
		if int(lv["region"]) != region:
			region = int(lv["region"])
			_content.add_child(HSeparator.new())
			_content.add_child(UI.label("Region %d - %s" % [region, LevelCatalog.REGION_NAMES[region - 1]], 10, UI.C_GOLD))
			if Progress.is_unlocked(id):
				var intro := UI.label(LevelCatalog.REGION_INTROS[region - 1], 10, UI.C_DIM)
				intro.autowrap_mode = TextServer.AUTOWRAP_WORD
				intro.custom_minimum_size = Vector2(380, 0)
				_content.add_child(intro)
		_content.add_child(_level_row(id, lv))


func _level_row(id: String, lv: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var unlocked := Progress.is_unlocked(id)
	var title := LevelCatalog.level_title(id)
	if lv.has("boss"):
		title += "  (guardian)"
	var b := UI.button(title if unlocked else "Locked", func() -> void: Transition.go_level(id), 196)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not unlocked
	if not unlocked:
		b.icon = UI.icon_tex("lock")
	level_buttons[id] = b
	row.add_child(b)
	if not unlocked:
		return row
	var rec := Progress.record(id)
	var tot := LevelCatalog.totals(id)
	row.add_child(UI.icon_rect("check" if rec["completed"] else "empty"))
	if int(tot["gems"]) > 0:
		row.add_child(UI.icon_rect("gem"))
		row.add_child(UI.label("%d/%d" % [rec["gems"].size(), tot["gems"]], 10,
			UI.C_GOOD if rec["gems"].size() >= int(tot["gems"]) else UI.C_TEXT))
	if int(tot["secrets"]) > 0:
		row.add_child(UI.icon_rect("star"))
		row.add_child(UI.label("%d/%d" % [rec["secrets"].size(), tot["secrets"]], 10,
			UI.C_GOOD if rec["secrets"].size() >= int(tot["secrets"]) else UI.C_TEXT))
	if tot["cat"] != "":
		var cat_icon := UI.icon_rect("cat")
		cat_icon.modulate = Color.WHITE if Progress.has_cat(tot["cat"]) else Color(1, 1, 1, 0.25)
		row.add_child(cat_icon)
	if rec["best_time"] > 0:
		row.add_child(UI.label(UI.fmt_time(rec["best_time"]), 10, UI.C_DIM))
	if rec["challenges"].size() > 0:
		row.add_child(UI.label("+%d" % rec["challenges"].size(), 10, UI.C_GOLD))
	return row


# --------------------------------------------------------------------------
# Upgrades
# --------------------------------------------------------------------------

func _build_upgrades() -> void:
	_content.add_child(UI.label("Permanent upgrades. Some need Shadow Gems (you keep the gems).", 10, UI.C_DIM))
	for id: String in GameData.UPGRADE_ORDER:
		var u: Dictionary = GameData.UPGRADES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(UI.icon_rect(u["icon"]))
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(240, 0)
		col.add_theme_constant_override("separation", 0)
		var lvl := Progress.upgrade_level(id)
		var mx := Progress.upgrade_max(id)
		col.add_child(UI.label("%s  [%d/%d]" % [u["name"], lvl, mx], 10, UI.C_GOLD if lvl >= mx else UI.C_TEXT))
		var d := UI.label(u["desc"], 10, UI.C_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size = Vector2(240, 0)
		col.add_child(d)
		row.add_child(col)
		var cost := Progress.upgrade_cost(id)
		var gems := Progress.upgrade_gem_req(id)
		var text := "MAX"
		if cost >= 0:
			text = "%d coins" % cost + (" +%d gems" % gems if gems > 0 else "")
		var b := UI.button(text, func() -> void: _buy(id), 120)
		b.disabled = cost < 0
		if cost >= 0 and not Progress.can_buy(id):
			b.modulate = Color(1, 1, 1, 0.55)
		buy_buttons[id] = b
		row.add_child(b)
		_content.add_child(row)
	if Progress.has_cat("bramble"):
		_content.add_child(UI.label("Bramble haggles: prices -15%.", 10, UI.C_GOOD))


func _buy(id: String) -> void:
	if Progress.buy(id):
		Audio.play("buy")
		_refresh_bar()
		show_tab("upgrades")
		await get_tree().process_frame
		if buy_buttons.has(id) and is_instance_valid(buy_buttons[id]) and not buy_buttons[id].disabled:
			buy_buttons[id].grab_focus()
	else:
		Audio.play("denied")


# --------------------------------------------------------------------------
# Cats
# --------------------------------------------------------------------------

func _build_cats() -> void:
	_content.add_child(UI.label("Every rescued cat lends you a permanent perk.", 10, UI.C_DIM))
	for cat: String in GameData.CAT_ORDER:
		var c: Dictionary = GameData.CATS[cat]
		var row := HBoxContainer.new()
		var has := Progress.has_cat(cat)
		var icon := TextureRect.new()
		icon.texture = Sprites.region("captives.png", Rect2(0, int(c["color"]) * 32, 32, 32)) if has else UI.icon_tex("lock")
		icon.custom_minimum_size = Vector2(32, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		if has:
			col.add_child(UI.label(c["name"], 10, UI.C_GOLD))
			col.add_child(UI.label(c["perk"], 10, UI.C_GOOD))
		else:
			col.add_child(UI.label("???", 10, UI.C_DIM))
			col.add_child(UI.label("Held captive in level %s." % c["level"], 10, UI.C_DIM))
		row.add_child(col)
		_content.add_child(row)


# --------------------------------------------------------------------------
# Records
# --------------------------------------------------------------------------

func _build_records() -> void:
	var st: Dictionary = Progress.data["stats"]
	var lines := [
		["star", "Completion", "%d%%" % Progress.completion_percent()],
		["check", "Levels cleared", "%d / %d" % [int(st["levels_done"]), LevelCatalog.count()]],
		["cat", "Cats rescued", "%d / %d" % [Progress.data["rescued"].size(), GameData.CAT_ORDER.size()]],
		["gem", "Shadow Gems", "%d / %d" % [Progress.total_gems(), LevelCatalog.all_gems()]],
		["star", "Secrets found", "%d / %d" % [Progress.total_secrets(), LevelCatalog.all_secrets()]],
		["relic", "Relics", "%d / 5" % Progress.data["relics"].size()],
		["check", "Challenges done", str(Progress.challenges_done())],
		["sword", "Enemies defeated", str(int(st["enemies"]))],
		["skull", "Guardians defeated", str(int(st["bosses"]))],
		["paw", "Pounces", str(int(st["pounces"]))],
		["coin", "Coins earned", str(int(st["coins_earned"]))],
		["skull", "Deaths", str(int(st["deaths"]))],
		["clock", "Play time", UI.fmt_time(float(st["play_time"]))],
	]
	for l: Array in lines:
		var row := HBoxContainer.new()
		row.add_child(UI.icon_rect(l[0]))
		var a := UI.label(l[1], 10)
		a.custom_minimum_size = Vector2(170, 0)
		row.add_child(a)
		row.add_child(UI.label(l[2], 10, UI.C_GOLD))
		_content.add_child(row)
	if Progress.data["game_complete"]:
		_content.add_child(UI.label("The Pale King is defeated. The alley cats are home!", 10, UI.C_GOOD))
	var relic_names: PackedStringArray = []
	for lv: Dictionary in LevelCatalog.LEVELS:
		if lv.has("relic_name") and Progress.data["relics"].has(lv.get("boss", "")):
			relic_names.append(lv["relic_name"])
	if not relic_names.is_empty():
		var rl := UI.label("Relics: " + ", ".join(relic_names), 10, UI.C_DIM)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD
		rl.custom_minimum_size = Vector2(380, 0)
		_content.add_child(rl)


# --------------------------------------------------------------------------
# Settings overlay
# --------------------------------------------------------------------------

func show_settings() -> void:
	_clear_content()
	_scroll.visible = false
	var sp := SettingsPanel.new()
	sp.closed.connect(func() -> void: show_tab(tab))
	_overlay = CenterContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := UI.dim_rect(0.6)
	add_child(dim)
	add_child(_overlay)
	_overlay.add_child(sp)
	_overlay.tree_exiting.connect(dim.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _overlay:
			show_tab(tab)
		else:
			Transition.go_menu()
		get_viewport().set_input_as_handled()
