class_name EnemyHunter
extends Enemy
## Elite hunter: heavily armoured with a regenerating shield, long-range
## optics, shotgun blasts and gap-closing dashes. Searches relentlessly.

const SHIELD_MAX := 60.0
const SHIELD_REGEN_DELAY := 3.0

var shield := SHIELD_MAX
var shield_cooldown := 0.0
var dash_cooldown := 2.0
var dash_time := 0.0
var dash_dir := Vector2.ZERO


func _configure() -> void:
	kind = "hunter"
	display_name = "HUNTER"
	max_hp = 130.0
	patrol_speed = 85.0
	chase_speed = 200.0
	vision_range = 420.0
	vision_fov = deg_to_rad(96.0)
	vision_rays = 22
	detect_rate = 1.35
	turn_rate = 9.0
	fire_interval = 1.15
	burst_count = 1
	bullet_damage = 7.0
	bullet_speed = 560.0
	spread = deg_to_rad(14.0)
	pellets = 5
	attack_range = 300.0
	preferred_range = 150.0
	body_radius = 15.0
	color = Palette.PURPLE
	credit_drop = 60
	search_duration = 18.0
	radio_delay = 0.8
	reaction_time = 0.4


func _physics_process(delta: float) -> void:
	if state != State.DEAD:
		shield_cooldown -= delta
		if shield_cooldown <= 0.0 and shield < SHIELD_MAX:
			shield = minf(SHIELD_MAX, shield + 25.0 * delta)
		dash_cooldown -= delta
	super._physics_process(delta)


func _absorb(amount: float) -> float:
	shield_cooldown = SHIELD_REGEN_DELAY
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		FX.ring(game.fx_layer, global_position, Palette.PURPLE, body_radius + 10.0, 0.2, 2.0)
		if shield <= 0.0:
			FX.burst(game.fx_layer, global_position, Palette.PURPLE, 18, 260.0, 0.4, 3.0)
		return amount - absorbed
	return amount


func _combat_move(p: Player, delta: float) -> void:
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_dir * 520.0
		return
	var to := p.global_position - global_position
	var d := to.length()
	if dash_cooldown <= 0.0 and d > 170.0 and d < 380.0:
		dash_cooldown = randf_range(2.2, 3.4)
		dash_time = 0.22
		dash_dir = (to.normalized() + to.normalized().orthogonal() * strafe_dir * 0.6).normalized()
		Sfx.play_at("dash", global_position, -2.0, 0.7)
		FX.burst(game.fx_layer, global_position, Palette.PURPLE, 10, 160.0, 0.3, 3.0)
		return
	super._combat_move(p, delta)


func _draw_body() -> void:
	var line := _line_color()
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	var hull := PackedVector2Array([Vector2(16, 0), Vector2(2, -13), Vector2(-12, -10), Vector2(-8, 0), Vector2(-12, 10), Vector2(2, 13)])
	draw_colored_polygon(hull, Color(0.1, 0.06, 0.16))
	hull.append(hull[0])
	draw_polyline(hull, Palette.with_alpha(line, 0.35), 5.0, true)
	draw_polyline(hull, line, 2.0, true)
	# Twin shotgun barrels.
	draw_rect(Rect2(Vector2(6, 5), Vector2(18, 3)), Color(0.3, 0.25, 0.35))
	draw_rect(Rect2(Vector2(6, 9), Vector2(16, 3)), Color(0.3, 0.25, 0.35))
	# Mono-eye.
	draw_circle(Vector2(7, 0), 3.5, Palette.with_alpha(Palette.MAGENTA, 0.4))
	draw_circle(Vector2(7.5, 0), 2.0, Palette.MAGENTA if state != State.CHASE else Palette.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shield > 0.0:
		var k := shield / SHIELD_MAX
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0, TAU, 32, Palette.with_alpha(Palette.PURPLE, 0.15 + 0.35 * k), 2.0 + 2.0 * k, true)
