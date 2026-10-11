extends Node3D
## Garage: pick racer, kart body, paint, wheels and accessory on a 3D
## turntable. Locked items show exactly how to earn them.

const CATEGORIES := [
	["racer", "Racer"], ["kart", "Kart"], ["paint", "Paint"], ["wheels", "Wheels"], ["accessory", "Accessory"],
]

var sel := {}
var turntable: Node3D
var model: KartModel
var ui: Control
var rows := {}
var info: Label
var stats_box: VBoxContainer
var _spin := 0.0


func _ready() -> void:
	sel = Game.selection()
	_build_stage()
	_build_ui()
	_refresh()
	Audio.play_music("menu")


func _build_stage() -> void:
	var th := TrackThemes.get_theme("royal")
	var env := RaceEnvironment.apply(self, th)
	env.environment.fog_enabled = false
	var floor_kit := MeshKit.new()
	floor_kit.cylinder(Transform3D(Basis(), Vector3(0, -0.3, 0)), 4.2, 4.2, 0.3, Color(0.22, 0.16, 0.32), 32)
	floor_kit.cylinder(Transform3D(Basis(), Vector3(0, -0.02, 0)), 3.6, 3.6, 0.04, Color(1.0, 0.55, 0.2), 32)
	var plinth := MeshInstance3D.new()
	plinth.mesh = floor_kit.commit(TrackBuilder.flat_material(0.5))
	add_child(plinth)
	var ground := MeshKit.new()
	ground.quad(Vector3(-60, -0.31, -60), Vector3(60, -0.31, -60), Vector3(60, -0.31, 60), Vector3(-60, -0.31, 60), Color(0.12, 0.09, 0.18), Vector3.UP)
	var gm := MeshInstance3D.new()
	gm.mesh = ground.commit(TrackBuilder.flat_material(0.9))
	add_child(gm)
	turntable = Node3D.new()
	turntable.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(turntable)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.1, 6.2)
	cam.fov = 40.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.55, 0), Vector3.UP)
	cam.h_offset = -1.9   # keep the kart clear of the left-hand panel
	cam.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UI.theme()
	layer.add_child(ui)
	var p := UI.panel(Vector2(560, 0))
	p.position = Vector2(36, 36)
	ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("GARAGE", 44, UI.ACCENT, true, 8))
	for c in CATEGORIES:
		var row := HBoxContainer.new()
		var name := UI.label(c[1], 22, UI.MUTED, true)
		name.custom_minimum_size = Vector2(120, 0)
		row.add_child(name)
		var prev := UI.button("<", func(): _cycle(c[0], -1), 54)
		row.add_child(prev)
		var val := UI.label("", 24, UI.TEXT, true)
		val.custom_minimum_size = Vector2(250, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val)
		row.add_child(UI.button(">", func(): _cycle(c[0], 1), 54))
		rows[c[0]] = val
		v.add_child(row)
	info = UI.label("", 19, UI.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(520, 60)
	v.add_child(info)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	v.add_child(stats_box)
	v.add_child(UI.button("Done", _done, 520))
	await get_tree().process_frame
	UI.focus_first(v)


func _list(cat: String) -> Array:
	match cat:
		"racer": return Catalog.PLAYABLE
		"kart": return Catalog.KART_ORDER
		"paint": return Catalog.PAINT_ORDER
		"wheels": return Catalog.WHEEL_ORDER
		"accessory": return Catalog.ACCESSORY_ORDER
	return []


func _entry(cat: String, id: String) -> Dictionary:
	match cat:
		"racer": return Catalog.RACERS[id]
		"kart": return Catalog.KARTS[id]
		"paint": return Catalog.PAINTS[id]
		"wheels": return Catalog.WHEELS[id]
		"accessory": return Catalog.ACCESSORIES[id]
	return {}


func _cycle(cat: String, dir: int) -> void:
	var list := _list(cat)
	var i := list.find(sel[cat])
	i = posmod(i + dir, list.size())
	sel[cat] = list[i]
	_refresh(cat)


func _refresh(focus_cat := "") -> void:
	var locked_any := false
	for c in CATEGORIES:
		var cat: String = c[0]
		var e := _entry(cat, sel[cat])
		var ok := Progression.is_unlocked(Save.data, e["unlock"])
		rows[cat].text = e["name"] + ("" if ok else "  (locked)")
		rows[cat].add_theme_color_override("font_color", UI.TEXT if ok else UI.LOCKED)
		if not ok:
			locked_any = true
	var cat2 := focus_cat if focus_cat != "" else "racer"
	var e2 := _entry(cat2, sel[cat2])
	var ok2 := Progression.is_unlocked(Save.data, e2["unlock"])
	var desc: String = e2.get("desc", "")
	info.text = (desc + "\n" if desc != "" else "") + ("Unlocked" if ok2 else "LOCKED - " + Catalog.unlock_text(e2["unlock"]))
	info.add_theme_color_override("font_color", UI.MUTED if ok2 else UI.GOLD)
	_stats()
	if model:
		model.queue_free()
	model = KartModel.create(sel)
	turntable.add_child(model)
	model.position = Vector3.ZERO


func _stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var st: Dictionary = Catalog.KARTS[sel["kart"]]["stats"]
	var labels := [["Speed", "speed"], ["Acceleration", "accel"], ["Handling", "handling"], ["Drift", "drift"], ["Weight", "weight"]]
	for l in labels:
		var row := HBoxContainer.new()
		var n := UI.label(l[0], 18, UI.MUTED, true)
		n.custom_minimum_size = Vector2(140, 0)
		row.add_child(n)
		var bar := ProgressBar.new()
		bar.min_value = 0.7
		bar.max_value = 1.3
		bar.value = float(st[l[1]])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 18)
		bar.add_theme_stylebox_override("background", UI.box(Color(0.08, 0.06, 0.12), 6))
		bar.add_theme_stylebox_override("fill", UI.box(UI.ACCENT2, 6))
		row.add_child(bar)
		stats_box.add_child(row)


func _done() -> void:
	# Only unlocked choices are saved; locked ones fall back to the last
	# valid selection so the player never races with something unearned.
	var saved: Dictionary = Save.data["selection"]
	for c in CATEGORIES:
		var cat: String = c[0]
		if Progression.is_unlocked(Save.data, _entry(cat, sel[cat])["unlock"]):
			saved[cat] = sel[cat]
	Save.save_game()
	Game.to_menu("single" if Game.race_config.get("mode", "") == "single" else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_done()


func _process(delta: float) -> void:
	_spin += delta * 0.6
	if model:
		model.rotation.y = _spin
