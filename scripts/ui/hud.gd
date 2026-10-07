class_name HUD
extends CanvasLayer
## In-game heads-up display: health, ammo, alarm & detection, objectives,
## interaction prompts, objective markers, minimap, notifications, damage
## vignette and the hacking mini-game overlay.

signal hack_finished(outcome: String)
signal hack_missed

var game: Game
var _canvas: Control
var _vignette: TextureRect
var _notify_box: VBoxContainer
var _hack: HackOverlay
var _minimap_tex: ImageTexture
var _damage_flash := 0.0
var _t := 0.0
var _font: Font
var _last_hp := -1.0
var _hp_ghost := 1.0

const MINIMAP_SCALE := 3.0


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
	_notify_box.offset_left = -300
	_notify_box.offset_right = 300
	_notify_box.offset_top = 112
	_notify_box.offset_bottom = 312
	_notify_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_notify_box)

	_hack = HackOverlay.new()
	_hack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hack.finished.connect(func(outcome: String): hack_finished.emit(outcome))
	_hack.missed.connect(func(): hack_missed.emit())
	add_child(_hack)

	_minimap_tex = ImageTexture.create_from_image(game.facility.build_minimap_image())


func _process(delta: float) -> void:
	_t += delta
	_damage_flash = maxf(0.0, _damage_flash - delta * 2.2)
	var alarm_pulse := 0.0
	if game.alarm.level == AlarmSystem.Level.ALARM:
		alarm_pulse = 0.18 + 0.12 * sin(_t * 6.0)
	var low_hp := 0.0
	if game.player != null and game.player.hp < game.player.max_hp * 0.3 and not game.player.dead:
		low_hp = 0.2 + 0.15 * sin(_t * 8.0)
	_vignette.modulate.a = clampf(maxf(_damage_flash * 0.8, maxf(alarm_pulse, low_hp)), 0.0, 1.0)
	if game.player != null:
		var ratio := game.player.hp / game.player.max_hp
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 0.6) if _hp_ghost > ratio else ratio
	_canvas.queue_redraw()


func flash_damage() -> void:
	_damage_flash = 1.0


func notify(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.custom_minimum_size = Vector2(600, 26)
	_notify_box.add_child(l)
	while _notify_box.get_child_count() > 4:
		var old := _notify_box.get_child(0)
		_notify_box.remove_child(old)
		old.queue_free()
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


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
	# Corner accents.
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
	_draw_vitals(p)
	_draw_alarm(vp)
	_draw_objectives(vp)
	_draw_marker(vp)
	_draw_prompt(vp)
	_draw_minimap(vp)
	_draw_controls_hint(vp)


func _draw_vitals(p: Player) -> void:
	var r := Rect2(16, 16, 300, 92)
	_panel(r, Palette.CYAN)
	_text(Vector2(30, 40), "KOCUR", 16, Palette.CYAN)
	_text(Vector2(30, 40), "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)], 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 270)
	# Health bar (segmented) with trailing damage ghost.
	var bar := Rect2(30, 48, 270, 12)
	_canvas.draw_rect(bar, Color(0.1, 0.1, 0.18))
	var ratio := clampf(p.hp / p.max_hp, 0.0, 1.0)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_ghost, bar.size.y)), Palette.with_alpha(Palette.WHITE, 0.5))
	var hp_col := Palette.GREEN if ratio > 0.5 else (Palette.YELLOW if ratio > 0.25 else Palette.RED)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_col)
	var segs := int(p.max_hp / 25.0)
	for i in range(1, segs):
		var x := bar.position.x + bar.size.x * i / segs
		_canvas.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.7), 2.0)

	# Ammo.
	var ammo_y := 86.0
	if p.reloading:
		_text(Vector2(30, ammo_y), "RELOADING", 16, Palette.YELLOW)
		_canvas.draw_rect(Rect2(140, ammo_y - 10, 100.0 * p.reload_progress(), 6), Palette.YELLOW)
	else:
		var col := Palette.WHITE if p.mag > 3 else Palette.RED
		_text(Vector2(30, ammo_y), "%02d" % p.mag, 24, col)
		_text(Vector2(70, ammo_y), "/ %d" % p.reserve, 16, Palette.DIM)
		for i in p.mag_size:
			var x := 140.0 + i * (150.0 / p.mag_size)
			var filled := i < p.mag
			_canvas.draw_rect(Rect2(x, ammo_y - 16, maxf(2.0, 150.0 / p.mag_size - 2.0), 14), Palette.CYAN if filled else Color(0.15, 0.17, 0.28))
	# Dash + credits line below.
	var dash_ready := p.dash_timer <= 0.0
	_text(Vector2(18, 128), "DASH", 13, Palette.CYAN if dash_ready else Palette.DIM)
	_text(Vector2(70, 128), "CR +%d" % game.credits_found, 13, Palette.YELLOW)
	if p.sneaking:
		_text(Vector2(160, 128), "SNEAKING", 13, Palette.PURPLE)


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
	_text(Vector2(r.position.x, 38), AlarmSystem.LEVEL_NAMES[a.level], 20, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if a.level != AlarmSystem.Level.CALM:
		_canvas.draw_rect(Rect2(r.position.x + 10, 44, (r.size.x - 20) * a.time_ratio(), 3), col)
	# Detection meter.
	var det := game.detection_level()
	var bar := Rect2(r.position.x + 44, 54, r.size.x - 58, 8)
	_canvas.draw_rect(bar, Color(0.1, 0.1, 0.16))
	var det_col := Palette.YELLOW.lerp(Palette.RED, det)
	_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * det, bar.size.y)), det_col)
	# Eye icon.
	var eye_c := Vector2(r.position.x + 26, 58)
	var open := 2.0 + det * 5.0
	var eye_col := det_col if det > 0.02 else Palette.DIM
	_canvas.draw_arc(eye_c + Vector2(0, open * 1.6), open * 2.2, -PI * 0.82, -PI * 0.18, 10, eye_col, 2.0, true)
	_canvas.draw_arc(eye_c - Vector2(0, open * 1.6), open * 2.2, PI * 0.18, PI * 0.82, 10, eye_col, 2.0, true)
	_canvas.draw_circle(eye_c, 2.5, eye_col)
	if game.cameras_loop_timer > 0.0:
		_text(Vector2(r.position.x, r.end.y + 18), "CAMERAS LOOPED %ds" % int(ceil(game.cameras_loop_timer)), 13, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	elif not game.facility.zones_active:
		_text(Vector2(r.position.x, r.end.y + 18), "MOTION SENSORS OFFLINE", 13, Palette.GREEN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_objectives(vp: Vector2) -> void:
	var objs := game.objectives()
	var w := 380.0
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


func _draw_marker(vp: Vector2) -> void:
	var world := game.objective_position()
	var xf := _canvas.get_viewport().get_canvas_transform()
	var sp := xf * world
	var col := Palette.GREEN if game.has_data else Palette.YELLOW
	var label := "EVAC" if game.has_data else "DATA"
	var dist := int(game.player.global_position.distance_to(world) / Facility.TILE)
	var margin := 40.0
	var screen := Rect2(Vector2(margin, margin + 70), vp - Vector2(margin * 2, margin * 2 + 70))
	if screen.has_point(sp):
		var bob := sin(_t * 4.0) * 3.0
		var top := sp + Vector2(0, -46 + bob)
		var d := PackedVector2Array([top + Vector2(0, -8), top + Vector2(7, 0), top + Vector2(0, 8), top + Vector2(-7, 0), top + Vector2(0, -8)])
		_canvas.draw_polyline(d, col, 2.0, true)
		_text(top + Vector2(-60, -14), "%s %dm" % [label, dist], 12, col, HORIZONTAL_ALIGNMENT_CENTER, 120)
	else:
		var center := vp * 0.5
		var dir := (sp - center).normalized()
		var edge := _clamp_to_rect(center, dir, screen)
		var ang := dir.angle()
		var tri := PackedVector2Array([edge + Vector2.from_angle(ang) * 14.0, edge + Vector2.from_angle(ang + 2.5) * 10.0, edge + Vector2.from_angle(ang - 2.5) * 10.0])
		_canvas.draw_colored_polygon(tri, col)
		_text(edge - dir * 26.0 + Vector2(-50, 4), "%s %dm" % [label, dist], 12, col, HORIZONTAL_ALIGNMENT_CENTER, 100)


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
			_text(Vector2(0, vp.y - 120), "EXTRACTING...", 22, Palette.GREEN, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		return
	var y := vp.y - 130
	var r := Rect2(vp.x * 0.5 - 220, y - 26, 440, 58)
	_panel(r, Palette.CYAN)
	_text(Vector2(r.position.x, y), f.prompt(), 20, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
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
		if not d.hacked_done:
			_canvas.draw_circle(to_map.call(d.global_position), 2.5, Palette.RED)
	if not game.has_data:
		_canvas.draw_circle(to_map.call(game.data_core.global_position), 3.5 + sin(_t * 5.0), Palette.YELLOW)
	var evac_col := Palette.GREEN if game.has_data else Palette.with_alpha(Palette.GREEN, 0.4)
	_canvas.draw_arc(to_map.call(game.extraction.global_position), 4.0, 0, TAU, 12, evac_col, 1.5)
	if game.alarm.level == AlarmSystem.Level.ALARM:
		_canvas.draw_arc(to_map.call(game.alarm.last_known), 6.0 + fmod(_t * 10.0, 6.0), 0, TAU, 12, Palette.RED, 1.0)
	var pp: Vector2 = to_map.call(game.player.global_position)
	_canvas.draw_circle(pp, 3.0, Palette.CYAN)
	_canvas.draw_line(pp, pp + Vector2.from_angle(game.player.aim_angle) * 7.0, Palette.CYAN, 1.5)


func _draw_controls_hint(vp: Vector2) -> void:
	if game.mission_time > 22.0 or int(game.def["index"]) > 2:
		return
	var a := clampf(22.0 - game.mission_time, 0.0, 1.0)
	var lines := [
		"WASD move  |  MOUSE aim  |  LMB fire  |  R reload",
		"SHIFT sneak (silent)  |  SPACE dash  |  RMB/F claw (takedown from behind)",
		"E hack  |  ESC pause  |  Find the DATA, then reach EVAC",
	]
	for i in lines.size():
		_text(Vector2(20, vp.y - 70 + i * 20), lines[i], 13, Palette.with_alpha(Palette.DIM, a))


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
