class_name HUD
extends CanvasLayer
## In-game heads-up display: health, weapon & ammo, decoys, alarm and
## detection, objectives, interaction prompts, objective markers, off-screen
## threat arrows, minimap, notifications, tutorial tips, act title card,
## boss health bar, story/intel reader, damage vignette and the hacking
## mini-game overlay.

signal hack_finished(outcome: String)
signal hack_missed

const MINIMAP_SCALE := 3.0

var game: Game
var _canvas: Control
var _vignette: TextureRect
var _notify_box: VBoxContainer
var _hack: HackOverlay
var _minimap_tex: ImageTexture
var _damage_flash := 0.0
var _t := 0.0
var _font: Font
var _hp_ghost := 1.0
var _weapon_flash := 0.0
var _hitmarker := 0.0
var _hitmarker_kill := false

var _title_root: Control
var _tip_text := ""
var _tip_time := 0.0
var _boss: EnemyWarden
var _boss_ghost := 1.0
var _story_layer: CanvasLayer
var _story_callback := Callable()
var _story_open := false


func setup(g: Game) -> void:
	game = g
	layer = 10
	_font = UITheme.font()

	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette_texture()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 0.1, 0.2, 0.0)
	add_child(_vignette)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	_notify_box = VBoxContainer.new()
	_notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notify_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notify_box.offset_left = -320
	_notify_box.offset_right = 320
	_notify_box.offset_top = 104
	_notify_box.offset_bottom = 300
	_notify_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_notify_box)

	_hack = HackOverlay.new()
	_hack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hack.finished.connect(func(outcome: String): hack_finished.emit(outcome))
	_hack.missed.connect(func(): hack_missed.emit())
	add_child(_hack)

	_minimap_tex = ImageTexture.create_from_image(game.facility.build_minimap_image())
	game.player.weapon_changed.connect(func(_id): _weapon_flash = 1.0)


func _process(delta: float) -> void:
	_t += delta
	_damage_flash = maxf(0.0, _damage_flash - delta * 2.2)
	_weapon_flash = maxf(0.0, _weapon_flash - delta * 2.5)
	_hitmarker = maxf(0.0, _hitmarker - delta * 6.0)
	_tip_time = maxf(0.0, _tip_time - delta)
	var alarm_pulse := 0.0
	if game.alarm.level == AlarmSystem.Level.ALARM:
		alarm_pulse = 0.16 + 0.1 * sin(_t * 6.0)
	var low_hp := 0.0
	if game.player != null and game.player.hp < game.player.max_hp * 0.3 and not game.player.dead:
		low_hp = 0.2 + 0.15 * sin(_t * 8.0)
	_vignette.modulate.a = clampf(maxf(_damage_flash * 0.8, maxf(alarm_pulse, low_hp)), 0.0, 1.0)
	if game.player != null:
		var ratio := game.player.hp / game.player.max_hp
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 0.6) if _hp_ghost > ratio else ratio
	if _boss != null and is_instance_valid(_boss):
		var br := maxf(_boss.hp, 0.0) / _boss.max_hp
		_boss_ghost = move_toward(_boss_ghost, br, delta * 0.4) if _boss_ghost > br else br
	_canvas.queue_redraw()


func hitmarker(killed: bool) -> void:
	_hitmarker = 1.0
	_hitmarker_kill = killed or (_hitmarker_kill and _hitmarker > 0.5)


func flash_damage(amount := 10.0) -> void:
	_damage_flash = clampf(0.5 + amount / 30.0, 0.5, 1.0)


func notify(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.custom_minimum_size = Vector2(640, 26)
	_notify_box.add_child(l)
	while _notify_box.get_child_count() > 4:
		var old := _notify_box.get_child(0)
		_notify_box.remove_child(old)
		old.queue_free()
	l.modulate.a = 0.0
	l.scale = Vector2(1.08, 1.08)
	l.pivot_offset = Vector2(320, 13)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_property(l, "scale", Vector2.ONE, 0.2)
	tw.chain().tween_interval(3.2)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(l.queue_free)


# --------------------------------------------------------------------------
# Title card, tips, boss, story
# --------------------------------------------------------------------------

func show_title(act_label: String, mission_name: String, location: String) -> void:
	_title_root = VBoxContainer.new()
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_root.offset_left = -400
	_title_root.offset_right = 400
	_title_root.offset_top = -150
	_title_root.offset_bottom = -20
	(_title_root as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_title_root)
	var act_col := Palette.MAGENTA
	_title_root.add_child(UITheme.make_label(act_label, 18, act_col, HORIZONTAL_ALIGNMENT_CENTER))
	_title_root.add_child(UITheme.make_title(mission_name.to_upper(), 40, Palette.CYAN))
	_title_root.add_child(UITheme.make_label(location, 16, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for c in _title_root.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.modulate.a = 0.0
	var tw := _title_root.create_tween()
	tw.tween_property(_title_root, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.2)
	tw.tween_property(_title_root, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_title_root.queue_free)


func show_tip(text: String) -> void:
	_tip_text = text
	_tip_time = 8.0
	Sfx.play("ui_hover", -6.0, 0.8)


func show_boss(b: EnemyWarden) -> void:
	_boss = b
	_boss_ghost = 1.0


func hide_boss() -> void:
	_boss = null


func is_story_open() -> bool:
	return _story_open


## Modal text reader for intel fragments and the final reveal. Pauses the
## game; any confirm input closes it and runs `on_close`.
func show_story(title: String, text: String, on_close: Callable) -> void:
	if _story_open:
		return
	_story_open = true
	_story_callback = on_close
	_story_layer = CanvasLayer.new()
	_story_layer.layer = 30
	_story_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_story_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	_story_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UITheme.make_label(title, 22, Palette.GREEN))
	var body := UITheme.make_label(text, 17, Palette.WHITE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(600, 0)
	body.visible_ratio = 0.0
	box.add_child(body)
	var btn := UITheme.make_button("CONTINUE  [E]", close_story, 220)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(btn)
	var tw := body.create_tween()
	tw.tween_property(body, "visible_ratio", 1.0, clampf(text.length() / 140.0, 0.6, 2.5))
	get_tree().paused = true
	UITheme.set_crosshair_cursor(false)
	btn.call_deferred("grab_focus")


func close_story() -> void:
	if not _story_open:
		return
	_story_open = false
	if _story_layer != null:
		_story_layer.queue_free()
	get_tree().paused = false
	UITheme.set_crosshair_cursor(true)
	game._hack_cooldown = 0.4
	if _story_callback.is_valid():
		_story_callback.call()


func _unhandled_input(event: InputEvent) -> void:
	if _story_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close_story()


# --------------------------------------------------------------------------
# Hacking
# --------------------------------------------------------------------------

func begin_hack(title: String, desc: String, hits: int, misses: int, window: float) -> void:
	_hack.follow = game.player
	_hack.begin(title, desc, hits, misses, window)


func abort_hack() -> void:
	if _hack.active:
		_hack.finish("abort")


func is_hacking() -> bool:
	return _hack.active


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _panel(r: Rect2, border: Color) -> void:
	_canvas.draw_rect(r, Color(0.02, 0.02, 0.06, 0.72))
	_canvas.draw_rect(r, Palette.with_alpha(border, 0.55), false, 1.5)
	var c := Palette.with_alpha(border, 0.95)
	_canvas.draw_line(r.position, r.position + Vector2(14, 0), c, 3.0)
	_canvas.draw_line(r.position, r.position + Vector2(0, 14), c, 3.0)
	_canvas.draw_line(r.end, r.end - Vector2(14, 0), c, 3.0)
	_canvas.draw_line(r.end, r.end - Vector2(0, 14), c, 3.0)


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_canvas.draw_string_outline(_font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.8))
	_canvas.draw_string(_font, pos, s, align, width, size, col)


func _draw_hud() -> void:
	var vp := _canvas.size
	var p := game.player
	if p == null:
		return
	_draw_threat_arrows(vp)
	_draw_vitals(p)
	_draw_weapon(p, vp)
	_draw_alarm(vp)
	_draw_objectives(vp)
	_draw_markers(vp)
	_draw_prompt(vp)
	_draw_minimap(vp)
	_draw_tip(vp)
	_draw_boss_bar(vp)
	_draw_hitmarker()


func _draw_hitmarker() -> void:
	if _hitmarker <= 0.0:
		return
	var m := _canvas.get_local_mouse_position()
	var col := Palette.RED if _hitmarker_kill else Palette.WHITE
	col.a = _hitmarker
	var r0 := 7.0 + (1.0 - _hitmarker) * 3.0
	var r1 := r0 + 6.0
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var dir := Vector2.from_angle(a)
		_canvas.draw_line(m + dir * r0, m + dir * r1, col, 2.0, true)


func _draw_vitals(p: Player) -> void:
	var r := Rect2(16, 16, 300, 64)
	_panel(r, Palette.CYAN)
	_text(Vector2(30, 40), "KOCUR", 16, Palette.CYAN)
	_text(Vector2(30, 40), "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)], 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 270)
	var bar := Rect2(30, 50, 270, 14)
	_canvas.draw_rect(bar, Color(0.1, 0.1, 0.18))
	var ratio := clampf(p.hp / p.max_hp, 0.0, 1.0)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_ghost, bar.size.y)), Palette.with_alpha(Palette.WHITE, 0.5))
	var hp_col := Palette.GREEN if ratio > 0.5 else (Palette.YELLOW if ratio > 0.25 else Palette.RED)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_col)
	var segs := int(p.max_hp / 25.0)
	for i in range(1, segs):
		var x := bar.position.x + bar.size.x * i / segs
		_canvas.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.7), 2.0)
	# Status line.
	var sx := 18.0
	var dash_ready := p.dash_timer <= 0.0
	_text(Vector2(sx, 100), "DASH", 13, Palette.CYAN if dash_ready else Palette.DIM)
	sx += 52
	_text(Vector2(sx, 100), "YARN x%d" % p.decoys, 13, Palette.MAGENTA if p.decoys > 0 else Palette.DIM)
	sx += 76
	_text(Vector2(sx, 100), "CR +%d" % game.credits_found, 13, Palette.YELLOW)
	sx += 76
	if p.concealed:
		_text(Vector2(sx, 100), "HIDDEN", 13, Palette.PURPLE.lerp(Palette.WHITE, 0.3))
	elif p.sneaking:
		_text(Vector2(sx, 100), "SNEAKING", 13, Palette.PURPLE)


func _draw_weapon(p: Player, vp: Vector2) -> void:
	var w := p.weapon()
	var col: Color = w["color"]
	var r := Rect2(16, vp.y - 98, 300, 82)
	_panel(r, col.lerp(Palette.WHITE, _weapon_flash * 0.6))
	_text(r.position + Vector2(14, 22), String(w["name"]), 15, col)
	# Weapon slots.
	for i in Weapons.ORDER.size():
		var id: String = Weapons.ORDER[i]
		var owned: bool = id in p.weapons
		var slot := Rect2(r.end.x - 86 + i * 26, r.position.y + 8, 22, 18)
		var sc := Weapons.get_data(id)["color"] as Color
		if id == p.weapon_id:
			_canvas.draw_rect(slot, Palette.with_alpha(sc, 0.35))
		_canvas.draw_rect(slot, sc if owned else Color(0.25, 0.25, 0.35), false, 1.5)
		_text(slot.position + Vector2(0, 14), str(i + 1), 12, Palette.WHITE if owned else Color(0.35, 0.35, 0.45), HORIZONTAL_ALIGNMENT_CENTER, slot.size.x)
	var ammo_y := r.position.y + 64
	if p.reloading:
		_text(Vector2(r.position.x + 14, ammo_y), "RELOADING", 18, Palette.YELLOW)
		_canvas.draw_rect(Rect2(r.position.x + 140, ammo_y - 10, 140.0 * p.reload_progress(), 6), Palette.YELLOW)
	else:
		var low := p.mag <= maxi(1, int(p.mag_size * 0.25))
		_text(Vector2(r.position.x + 14, ammo_y), "%02d" % p.mag, 28, Palette.RED if low else Palette.WHITE)
		_text(Vector2(r.position.x + 62, ammo_y), "/ %d" % p.reserve, 16, Palette.DIM)
		var pip_w := 150.0 / p.mag_size
		for i in p.mag_size:
			var x := r.position.x + 134.0 + i * pip_w
			_canvas.draw_rect(Rect2(x, ammo_y - 18, maxf(1.5, pip_w - 1.5), 16), col if i < p.mag else Color(0.15, 0.17, 0.28))
		if p.mag == 0 and p.reserve == 0:
			_text(Vector2(r.position.x + 134, ammo_y + 14), "NO AMMO - switch weapon", 11, Palette.RED)


func _draw_alarm(vp: Vector2) -> void:
	var a := game.alarm
	var cx := vp.x * 0.5
	var r := Rect2(cx - 150, 14, 300, 58)
	var col := Palette.GREEN
	match a.level:
		AlarmSystem.Level.CAUTION:
			col = Palette.YELLOW
		AlarmSystem.Level.ALARM:
			col = Palette.RED if int(_t * 4.0) % 2 == 0 else Palette.ORANGE
	_panel(r, col)
	var label: String = AlarmSystem.LEVEL_NAMES[a.level]
	if a.lockdown:
		label = "LOCKDOWN"
	_text(Vector2(r.position.x, 38), label, 20, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if a.level != AlarmSystem.Level.CALM and not a.lockdown:
		_canvas.draw_rect(Rect2(r.position.x + 10, 44, (r.size.x - 20) * a.time_ratio(), 3), col)
	if a.times_raised > 0:
		_text(Vector2(r.end.x - 40, 30), "x%d" % a.times_raised, 12, Palette.RED)
	var det := game.detection_level()
	var bar := Rect2(r.position.x + 44, 54, r.size.x - 58, 8)
	_canvas.draw_rect(bar, Color(0.1, 0.1, 0.16))
	var det_col := Palette.YELLOW.lerp(Palette.RED, det)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * det, bar.size.y)), det_col)
	var eye_c := Vector2(r.position.x + 26, 58)
	var open := 2.0 + det * 5.0
	var eye_col := det_col if det > 0.02 else Palette.DIM
	_canvas.draw_arc(eye_c + Vector2(0, open * 1.6), open * 2.2, -PI * 0.82, -PI * 0.18, 10, eye_col, 2.0, true)
	_canvas.draw_arc(eye_c - Vector2(0, open * 1.6), open * 2.2, PI * 0.18, PI * 0.82, 10, eye_col, 2.0, true)
	_canvas.draw_circle(eye_c, 2.5, eye_col)
	if game.cameras_loop_timer > 0.0:
		_text(Vector2(r.position.x, r.end.y + 18), "CAMERAS LOOPED %ds" % int(ceil(game.cameras_loop_timer)), 13, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	elif not game.facility.zones_active and not game.facility.zone_cells.is_empty():
		_text(Vector2(r.position.x, r.end.y + 18), "MOTION SENSORS OFFLINE", 13, Palette.GREEN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_objectives(vp: Vector2) -> void:
	var objs := game.objectives()
	var w := 390.0
	var r := Rect2(vp.x - w - 16, 16, w, 40 + objs.size() * 24)
	_panel(r, Palette.MAGENTA)
	_text(r.position + Vector2(14, 22), String(game.def["name"]).to_upper(), 13, Palette.MAGENTA)
	var y := r.position.y + 48
	for o in objs:
		var done: bool = o.get("done", false)
		var failed: bool = o.get("failed", false)
		var optional: bool = o.get("optional", false)
		var active: bool = o.get("active", true)
		var col := Palette.WHITE
		if done and not optional:
			col = Palette.GREEN
		elif failed:
			col = Palette.RED
		elif optional:
			col = Palette.DIM.lerp(Palette.GREEN, 0.4) if done else Palette.DIM
		elif not active:
			col = Color(0.45, 0.48, 0.6)
		var box := Rect2(r.position.x + 14, y - 11, 11, 11)
		_canvas.draw_rect(box, col, false, 1.5)
		if done and not optional:
			_canvas.draw_rect(box.grow(-3), col)
		elif failed:
			_canvas.draw_line(box.position, box.end, col, 1.5)
		_text(Vector2(r.position.x + 32, y), String(o["text"]), 14, col)
		y += 24


func _draw_markers(vp: Vector2) -> void:
	var targets := game.objective_positions()
	var nearest := game.objective_position()
	for world in targets:
		_draw_marker(vp, world, world == nearest)


func _draw_marker(vp: Vector2, world: Vector2, primary: bool) -> void:
	var xf := _canvas.get_viewport().get_canvas_transform()
	var sp := xf * world
	var col := Palette.GREEN if game.has_data else Palette.YELLOW
	if game.boss != null and not game.boss_defeated and world == game.boss.global_position:
		col = Palette.RED
	var label := "EVAC" if game.has_data else "OBJ"
	var dist := int(game.player.global_position.distance_to(world) / Facility.TILE)
	if not primary:
		col = Palette.with_alpha(col, 0.55)
	var margin := 40.0
	var screen := Rect2(Vector2(margin, margin + 90), vp - Vector2(margin * 2, margin * 2 + 200))
	if screen.has_point(sp):
		var bob := sin(_t * 4.0) * 3.0
		var top := sp + Vector2(0, -46 + bob)
		var d := PackedVector2Array([top + Vector2(0, -8), top + Vector2(7, 0), top + Vector2(0, 8), top + Vector2(-7, 0), top + Vector2(0, -8)])
		_canvas.draw_polyline(d, col, 2.0, true)
		if primary:
			_text(top + Vector2(-60, -14), "%s %dm" % [label, dist], 12, col, HORIZONTAL_ALIGNMENT_CENTER, 120)
	else:
		var center := vp * 0.5
		var dir := (sp - center).normalized()
		var edge := _clamp_to_rect(center, dir, screen)
		var ang := dir.angle()
		var sz := 14.0 if primary else 9.0
		var tri := PackedVector2Array([edge + Vector2.from_angle(ang) * sz, edge + Vector2.from_angle(ang + 2.5) * sz * 0.7, edge + Vector2.from_angle(ang - 2.5) * sz * 0.7])
		_canvas.draw_colored_polygon(tri, col)
		if primary:
			_text(edge - dir * 26.0 + Vector2(-50, 4), "%s %dm" % [label, dist], 12, col, HORIZONTAL_ALIGNMENT_CENTER, 100)


## Edge arrows for enemies that are noticing the cat while off-screen.
func _draw_threat_arrows(vp: Vector2) -> void:
	var xf := _canvas.get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2(24, 24), vp - Vector2(48, 48))
	var center := vp * 0.5
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e.awareness < 0.08 or e.state == Enemy.State.PATROL and e.awareness < 0.25:
			continue
		var sp := xf * e.global_position
		if screen.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		var edge := _clamp_to_rect(center, dir, screen)
		var col := Palette.RED if e.state == Enemy.State.CHASE else Palette.YELLOW
		col.a = 0.4 + 0.6 * e.awareness
		var ang := dir.angle()
		var pts := PackedVector2Array([edge + Vector2.from_angle(ang) * 10.0, edge + Vector2.from_angle(ang + 2.4) * 8.0, edge + Vector2.from_angle(ang - 2.4) * 8.0])
		_canvas.draw_colored_polygon(pts, col)
		_canvas.draw_arc(edge - dir * 4.0, 12.0, ang - 0.8, ang + 0.8, 8, col, 2.0, true)


func _clamp_to_rect(origin: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.001:
		t = minf(t, (r.end.x - origin.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (r.position.x - origin.x) / dir.x)
	if dir.y > 0.001:
		t = minf(t, (r.end.y - origin.y) / dir.y)
	elif dir.y < -0.001:
		t = minf(t, (r.position.y - origin.y) / dir.y)
	if t == INF:
		return origin
	return origin + dir * t


func _draw_prompt(vp: Vector2) -> void:
	if _hack.active:
		return
	var f := game.focus as Hackable
	if f == null:
		if game.has_data and game.extraction.progress > 0.0:
			_text(Vector2(0, vp.y - 140), "EXTRACTING...", 22, Palette.GREEN, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		return
	var y := vp.y - 150
	var r := Rect2(vp.x * 0.5 - 230, y - 26, 460, 58)
	var col := Palette.PURPLE if f.sealed else (Palette.GREEN if f.instant else Palette.CYAN)
	_panel(r, col)
	_text(Vector2(r.position.x, y), f.prompt(), 20, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var d := f.describe()
	if d != "":
		_text(Vector2(r.position.x, y + 22), d, 14, Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_minimap(vp: Vector2) -> void:
	var f := game.facility
	var size := Vector2(f.width, f.height) * MINIMAP_SCALE
	var origin := vp - size - Vector2(16, 16)
	var r := Rect2(origin - Vector2(6, 6), size + Vector2(12, 12))
	_panel(r, Palette.PURPLE)
	_canvas.draw_texture_rect(_minimap_tex, Rect2(origin, size), false)
	var to_map := func(world: Vector2) -> Vector2:
		return origin + world / Facility.TILE * MINIMAP_SCALE
	for d in game.doors:
		if not d.hacked_done or d.locked_in:
			_canvas.draw_circle(to_map.call(d.global_position), 2.5, Palette.PURPLE if d.sealed else Palette.RED)
	for c in game.cores:
		if not c.hacked_done:
			var cc: Color = c._color()
			_canvas.draw_circle(to_map.call(c.global_position), 3.0 + sin(_t * 5.0) * (0.0 if c.sealed else 1.0), Palette.with_alpha(cc, 0.5 if c.sealed else 1.0))
	if game.boss != null and not game.boss_defeated:
		_canvas.draw_arc(to_map.call(game.boss.global_position), 5.0, 0, TAU, 12, Palette.RED, 2.0)
	var evac_col := Palette.GREEN if game.has_data else Palette.with_alpha(Palette.GREEN, 0.4)
	_canvas.draw_arc(to_map.call(game.extraction.global_position), 4.0, 0, TAU, 12, evac_col, 1.5)
	if game.alarm.level == AlarmSystem.Level.ALARM:
		_canvas.draw_arc(to_map.call(game.alarm.last_known), 6.0 + fmod(_t * 10.0, 6.0), 0, TAU, 12, Palette.RED, 1.0)
	var pp: Vector2 = to_map.call(game.player.global_position)
	_canvas.draw_circle(pp, 3.0, Palette.CYAN)
	_canvas.draw_line(pp, pp + Vector2.from_angle(game.player.aim_angle) * 7.0, Palette.CYAN, 1.5)


func _draw_tip(vp: Vector2) -> void:
	if _tip_time <= 0.0 or _tip_text == "":
		return
	var a := clampf(_tip_time, 0.0, 1.0) * clampf((8.0 - _tip_time) * 4.0, 0.0, 1.0)
	var w := minf(460.0, vp.x - 332.0 - 290.0)
	var r := Rect2(332, vp.y - 98, w, 66)
	_canvas.draw_rect(r, Color(0.02, 0.02, 0.06, 0.78 * a))
	_canvas.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Palette.with_alpha(Palette.GREEN, a))
	_text(r.position + Vector2(14, 18), "TIP", 12, Palette.with_alpha(Palette.GREEN, a))
	_canvas.draw_multiline_string(_font, r.position + Vector2(14, 36), _tip_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 13, 3, Palette.with_alpha(Palette.WHITE, a))


func _draw_boss_bar(vp: Vector2) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.is_dead():
		return
	var w := minf(620.0, vp.x - 200.0)
	var r := Rect2((vp.x - w) * 0.5, vp.y - 54, w, 18)
	_text(Vector2(r.position.x, r.position.y - 8), "WARDEN  //  PHASE %d" % _boss.phase, 16, Palette.RED, HORIZONTAL_ALIGNMENT_CENTER, w)
	_canvas.draw_rect(r.grow(3), Color(0.02, 0.0, 0.03, 0.85))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * _boss_ghost, r.size.y)), Palette.with_alpha(Palette.WHITE, 0.45))
	var k := maxf(_boss.hp, 0.0) / _boss.max_hp
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Palette.RED.lerp(Palette.MAGENTA, 1.0 - k))
	for t in [0.33, 0.66]:
		_canvas.draw_line(Vector2(r.position.x + r.size.x * t, r.position.y), Vector2(r.position.x + r.size.x * t, r.end.y), Color(0, 0, 0, 0.8), 2.0)
	_canvas.draw_rect(r, Palette.RED, false, 1.5)


func _make_vignette_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(0.6, Color(1, 1, 1, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 256
	t.height = 256
	return t
