extends CanvasLayer
## In-game HUD: hearts + shield, coins, gems, pounce cooldown, blessings,
## level name, guardian health bar, toasts and the level title card.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameData := preload("res://scripts/data/game_data.gd")

var level: Node
var root: Control
var hearts_box: HBoxContainer
var coin_label: Label
var gem_label: Label
var secret_label: Label
var paw_icon: TextureRect
var paw_bar: ColorRect
var blessing_box: HBoxContainer
var boss_panel: Control
var boss_name: Label
var boss_fill: ColorRect
var boss_back: ColorRect
var boss_lag: ColorRect
var toast_box: VBoxContainer
var title_label: Label
var subtitle_label: Label
var _last_hp := -1
var _last_max := -1
var _last_shield := -1
var _boss: Node
var _boss_lag := 1.0


func _ready() -> void:
	layer = 10


func setup(lv: Node) -> void:
	level = lv
	root = UI.root_control()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# --- top-left status block
	var tl := VBoxContainer.new()
	tl.position = Vector2(8, 6)
	tl.add_theme_constant_override("separation", 2)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	hearts_box = HBoxContainer.new()
	hearts_box.add_theme_constant_override("separation", 1)
	tl.add_child(hearts_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	tl.add_child(row)
	row.add_child(UI.icon_rect("coin"))
	coin_label = UI.label("0", 10, UI.C_GOLD)
	row.add_child(coin_label)
	row.add_child(UI.icon_rect("gem"))
	gem_label = UI.label("0/0", 10, Color(0.8, 0.6, 1.0))
	row.add_child(gem_label)
	paw_icon = UI.icon_rect("paw")
	row.add_child(paw_icon)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.12, 0.2)
	bar_bg.custom_minimum_size = Vector2(24, 4)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar_bg)
	paw_bar = ColorRect.new()
	paw_bar.color = Color(0.78, 1.0, 0.3)
	paw_bar.size = Vector2(24, 4)
	bar_bg.add_child(paw_bar)
	secret_label = UI.label("", 10, Color(0.6, 1.0, 0.75))
	tl.add_child(secret_label)
	blessing_box = HBoxContainer.new()
	blessing_box.position = Vector2(8, 336)
	root.add_child(blessing_box)
	for b: String in Progress.run_blessings:
		var ic := UI.icon_rect(GameData.BLESSINGS[b]["icon"])
		ic.tooltip_text = GameData.BLESSINGS[b]["name"]
		ic.modulate = Color(1.0, 0.95, 0.7)
		blessing_box.add_child(ic)
	# --- top-right level name
	var tr := UI.label(level.meta.get("name", ""), 10, UI.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.position = Vector2(440, 6)
	tr.size = Vector2(192, 12)
	tr.text = "%s  %s" % ["FINAL" if level.level_id == "final" else level.level_id, level.meta.get("name", "")]
	root.add_child(tr)
	# --- boss bar
	boss_panel = Control.new()
	boss_panel.position = Vector2(170, 326)
	boss_panel.size = Vector2(300, 26)
	boss_panel.visible = false
	root.add_child(boss_panel)
	boss_name = UI.label("", 10, Color(1, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.size = Vector2(300, 12)
	boss_panel.add_child(boss_name)
	boss_back = ColorRect.new()
	boss_back.color = Color(0.1, 0.05, 0.08)
	boss_back.position = Vector2(0, 13)
	boss_back.size = Vector2(300, 8)
	boss_panel.add_child(boss_back)
	boss_lag = ColorRect.new()
	boss_lag.color = Color(1, 0.9, 0.7)
	boss_lag.position = Vector2(1, 14)
	boss_lag.size = Vector2(298, 6)
	boss_panel.add_child(boss_lag)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.9, 0.2, 0.3)
	boss_fill.position = Vector2(1, 14)
	boss_fill.size = Vector2(298, 6)
	boss_panel.add_child(boss_fill)
	# --- toasts
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(120, 40)
	toast_box.size = Vector2(400, 60)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	# --- title card
	title_label = UI.label("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.position = Vector2(0, 130)
	title_label.size = Vector2(640, 24)
	title_label.modulate.a = 0.0
	root.add_child(title_label)
	subtitle_label = UI.label("", 10, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.position = Vector2(0, 158)
	subtitle_label.size = Vector2(640, 12)
	subtitle_label.modulate.a = 0.0
	root.add_child(subtitle_label)
	level.boss_started.connect(_on_boss_started)
	level.boss_finished.connect(func() -> void: boss_panel.visible = false)


func show_title(title: String, sub: String) -> void:
	title_label.text = title
	subtitle_label.text = sub
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(title_label, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.6)


func toast(text: String, color := Color.WHITE) -> void:
	var l := UI.label(text, 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(400, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast_box.add_child(l)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_boss_started(b: Node) -> void:
	_boss = b
	boss_panel.visible = true
	boss_name.text = b.display_name
	_boss_lag = 1.0


func _process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var p: Node = level.player
	if p.hp != _last_hp or p.max_hp != _last_max or p.shield != _last_shield:
		_rebuild_hearts(p.hp, p.max_hp, p.shield)
	coin_label.text = str(Progress.coins() + level.pending_coins())
	gem_label.text = "%d/%d" % [_gems_have(), level.gems_total]
	var ratio: float = p.combat.pounce_cooldown_ratio()
	paw_bar.size.x = 24.0 * (1.0 - ratio)
	paw_bar.color = Color(0.78, 1.0, 0.3) if ratio <= 0.0 else Color(0.5, 0.5, 0.6)
	paw_icon.modulate = Color.WHITE if ratio <= 0.0 else Color(0.5, 0.5, 0.6)
	if Progress.upgrade_level("whiskers") > 0 and level.secrets_total > 0:
		var found := 0
		for k in level.record["secrets"]:
			found += 1
		for k in level.run_secrets:
			if not level.record["secrets"].has(k):
				found += 1
		secret_label.text = "Secrets: %d/%d" % [found, level.secrets_total]
	else:
		secret_label.text = ""
	if _boss and is_instance_valid(_boss) and boss_panel.visible:
		var r := clampf(float(_boss.hp) / float(_boss.max_hp), 0.0, 1.0)
		boss_fill.size.x = 298.0 * r
		_boss_lag = move_toward(_boss_lag, r, delta * 0.5) if _boss_lag > r else r
		boss_lag.size.x = 298.0 * _boss_lag
		boss_name.text = _boss.display_name + ("" if _boss.phase_name() == "" else "  -  " + _boss.phase_name())


func _gems_have() -> int:
	var n: int = level.record["gems"].size()
	for k in level.run_gems:
		if not level.record["gems"].has(k):
			n += 1
	return n


func _rebuild_hearts(hp: int, max_hp: int, shield: int) -> void:
	_last_hp = hp
	_last_max = max_hp
	_last_shield = shield
	for c in hearts_box.get_children():
		c.queue_free()
	for i in range(max_hp / 2):
		var v := hp - i * 2
		var name := "heart" if v >= 2 else ("half" if v == 1 else "empty")
		hearts_box.add_child(UI.icon_rect(name))
	for i in shield:
		var s := UI.icon_rect("shield")
		hearts_box.add_child(s)
