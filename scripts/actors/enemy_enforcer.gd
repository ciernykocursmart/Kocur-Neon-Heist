class_name EnemyEnforcer
extends Enemy
## Enforcer: slow, heavily armoured sentinel. Its front plate blocks 70% of
## incoming damage, it turns slowly and fires a telegraphed, high-damage
## laser bolt along its aim line. Rewards flanking, takedowns and dodging.

const CHARGE_TIME := 0.85
const FRONT_ARC := deg_to_rad(65.0)

var charging := false
var charge := 0.0
var laser_end := Vector2.ZERO
var _block_text_timer := 0.0


func _configure() -> void:
	kind = "enforcer"
	display_name = "ENFORCER"
	max_hp = 170.0
	patrol_speed = 55.0
	chase_speed = 100.0
	vision_range = 470.0
	vision_fov = deg_to_rad(42.0)
	vision_rays = 16
	proximity_radius = 44.0
	detect_rate = 0.9
	turn_rate = 3.0
	fire_interval = 2.1
	burst_count = 1
	bullet_damage = 30.0
	bullet_speed = 1500.0
	spread = 0.0
	attack_range = 520.0
	preferred_range = 330.0
	body_radius = 16.0
	color = Color(0.7, 1.0, 0.25)
	credit_drop = 45
	search_duration = 12.0
	radio_delay = 1.6
	reaction_time = 0.6
	knockback_scale = 0.25


func _physics_process(delta: float) -> void:
	_block_text_timer -= delta
	super._physics_process(delta)
	if charging and state != State.DEAD:
		var dir := Vector2.from_angle(facing)
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * attack_range, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		laser_end = to_local(hit["position"] if not hit.is_empty() else global_position + dir * attack_range)


func _absorb(amount: float, from_pos: Vector2) -> float:
	var to_source := (from_pos - global_position).angle()
	if absf(angle_difference(facing, to_source)) < FRONT_ARC:
		FX.burst(game.fx_layer, global_position + Vector2.from_angle(to_source) * body_radius, Palette.YELLOW, 6, 220.0, 0.2, 2.0, Vector2.from_angle(to_source), 50.0)
		Sfx.play_at("armor_ping", global_position, -6.0)
		if _block_text_timer <= 0.0:
			_block_text_timer = 0.8
			FX.float_text(game.fx_layer, global_position + Vector2(0, -30), "ARMOR", Palette.YELLOW, 12)
		return amount * 0.3
	return amount


func _try_fire(p: Player, delta: float) -> void:
	if charging:
		charge += delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		if not sees_player:
			charging = false
			fire_timer = 0.6
			return
		if charge >= CHARGE_TIME:
			charging = false
			fire_timer = fire_interval
			var dir := Vector2.from_angle(facing)
			var muzzle := global_position + dir * (body_radius + 10.0)
			game.spawn_bullet(muzzle, dir * bullet_speed, bullet_damage, false, color, {"heavy": true, "life": 0.6})
			FX.flash(game.fx_layer, muzzle, color, 110.0, 0.15, 1.0)
			FX.burst(game.fx_layer, muzzle, color, 12, 300.0, 0.2, 3.0, dir, 20.0)
			Sfx.play_at("laser_fire", global_position, 0.0)
			velocity -= dir * 80.0
		return
	var d := global_position.distance_to(p.global_position)
	if fire_timer <= 0.0 and d <= attack_range:
		var aim_err := absf(angle_difference(facing, (p.global_position - global_position).angle()))
		if aim_err < 0.25:
			charging = true
			charge = 0.0
			Sfx.play_at("laser_charge", global_position, -2.0)


func _combat_move(p: Player, delta: float) -> void:
	if charging:
		return
	var to := p.global_position - global_position
	var d := to.length()
	if d > attack_range * 0.9:
		_move_to(p.global_position, chase_speed, delta, false)
	elif d < preferred_range * 0.6:
		velocity = velocity.move_toward(-to.normalized() * chase_speed * 0.6, 500.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)


func take_damage(amount: float, from_pos: Vector2, silent := false, knockback := 110.0) -> void:
	super.take_damage(amount, from_pos, silent, knockback)
	# Hits from behind interrupt the laser charge.
	if charging and absf(angle_difference(facing, (from_pos - global_position).angle())) > FRONT_ARC:
		charging = false
		fire_timer = 0.8


func _draw_body() -> void:
	var line := _line_color()
	if charging:
		var k := charge / CHARGE_TIME
		draw_line(Vector2.ZERO, laser_end, Palette.with_alpha(Palette.RED, 0.15 + 0.55 * k), 1.0 + 3.0 * k, true)
		draw_line(Vector2.ZERO, laser_end, Palette.with_alpha(Palette.WHITE, 0.3 * k), 1.0, true)
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	var hull := PackedVector2Array()
	for i in 8:
		hull.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * 14.0)
	draw_colored_polygon(hull, Color(0.1, 0.12, 0.06))
	hull.append(hull[0])
	draw_polyline(hull, line, 2.0, true)
	# Front armour plate.
	draw_arc(Vector2.ZERO, 18.0, -FRONT_ARC, FRONT_ARC, 14, Palette.with_alpha(Palette.YELLOW, 0.35), 7.0, true)
	draw_arc(Vector2.ZERO, 18.0, -FRONT_ARC, FRONT_ARC, 14, Palette.YELLOW, 2.5, true)
	# Long rifle.
	draw_rect(Rect2(Vector2(8, -2), Vector2(26, 4)), Color(0.25, 0.28, 0.2))
	draw_rect(Rect2(Vector2(31, -2), Vector2(4, 4)), line)
	# Visor slit.
	draw_line(Vector2(4, -6), Vector2(4, 6), Palette.RED if state == State.CHASE else line, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
