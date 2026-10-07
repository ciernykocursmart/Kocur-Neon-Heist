class_name SecurityCamera
extends Hackable
## Wall-mounted sweeping camera. Fills its own awareness meter while it sees
## the cat, then trips the alarm. Hacking shuts it down permanently; terminal
## "camera loop" programs disable it temporarily.

const RANGE := 300.0
const FOV := deg_to_rad(54.0)

var base_angle := 0.0
var sweep := deg_to_rad(55.0)
var sweep_speed := 0.55
var angle := 0.0
var awareness := 0.0
var sees_player := false
var cone := PackedVector2Array()
var _cone_timer := 0.0
var _phase := 0.0
var _tracking := false


func _ready() -> void:
	super._ready()
	display_name = "CAMERA"
	difficulty = 2
	interact_radius = 60.0
	_phase = randf() * TAU
	angle = base_angle
	add_to_group("cameras")


func is_active() -> bool:
	return not hacked_done and game.cameras_loop_timer <= 0.0


func describe() -> String:
	return "Shuts the camera down"


func _physics_process(delta: float) -> void:
	if not is_active():
		awareness = maxf(0.0, awareness - delta)
		sees_player = false
		cone = PackedVector2Array()
		return
	var p := game.player
	sees_player = false
	if p != null and not p.dead:
		var to := p.global_position - global_position
		if to.length() < RANGE and VisionCone.angle_within(angle, to.angle(), FOV) and game.facility.has_los(global_position, p.global_position):
			sees_player = true
	if sees_player:
		_tracking = true
		angle = lerp_angle(angle, (p.global_position - global_position).angle(), delta * 3.0)
		var mult := 4.0 if game.alarm.level == AlarmSystem.Level.ALARM else 1.0
		var prev := awareness
		awareness = minf(1.0, awareness + delta * 0.85 * p.visibility() * mult)
		if prev < 0.05 and awareness >= 0.05:
			Sfx.play_at("suspicious", global_position, -8.0, 1.4)
		if awareness >= 1.0:
			if game.alarm.level != AlarmSystem.Level.ALARM:
				game.alarm.raise_alarm(p.global_position, "CAMERA")
			else:
				game.alarm.report_sighting(p.global_position)
	else:
		awareness = maxf(0.0, awareness - delta * 0.25)
		if _tracking and awareness <= 0.0:
			_tracking = false
		if not _tracking:
			_phase += delta * sweep_speed
			angle = lerp_angle(angle, base_angle + sin(_phase) * sweep, delta * 4.0)
	_cone_timer -= delta
	if _cone_timer <= 0.0:
		_cone_timer = 0.05
		cone = VisionCone.compute(get_world_2d().direct_space_state, global_position, angle, FOV, RANGE, 14)


func on_hacked() -> void:
	cone = PackedVector2Array()
	FX.burst(game.fx_layer, global_position, Palette.CYAN, 12, 140.0, 0.4, 2.5)
	game.notify("CAMERA OFFLINE", Palette.CYAN)


func _draw() -> void:
	var active := is_active()
	if active and cone.size() >= 3:
		var c := Palette.RED if awareness > 0.5 else Palette.YELLOW.lerp(Palette.RED, awareness * 2.0) if awareness > 0.0 else Color(0.6, 0.9, 1.0)
		draw_colored_polygon(cone, Palette.with_alpha(c, 0.06 + 0.1 * awareness))
		var outline := cone.duplicate()
		outline.append(cone[0])
		draw_polyline(outline, Palette.with_alpha(c, 0.25), 1.0, true)
	# Mount + head.
	draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.1, 0.16))
	var col := Palette.RED if active else (Palette.CYAN if hacked_done else Palette.DIM)
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, col, 1.5, true)
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-2, -5), Vector2(14, 10)), Color(0.16, 0.16, 0.24))
	draw_rect(Rect2(Vector2(-2, -5), Vector2(14, 10)), col, false, 1.5)
	var blink := active and int(_t * 2.0) % 2 == 0
	draw_circle(Vector2(12, 0), 2.5, col if blink or not active else Palette.with_alpha(col, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if active and awareness > 0.0:
		draw_arc(Vector2(0, -18), 8.0, -PI * 0.5, -PI * 0.5 + TAU * awareness, 16, Palette.RED, 2.0, true)
	draw_focus_ring(22.0)
