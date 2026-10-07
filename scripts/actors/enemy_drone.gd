class_name EnemyDrone
extends Enemy
## Patrol drone: fast, fragile, 360-degree short-range sensor, rapid pellets.


func _configure() -> void:
	kind = "drone"
	display_name = "DRONE"
	max_hp = 30.0
	patrol_speed = 95.0
	chase_speed = 180.0
	vision_range = 175.0
	vision_fov = TAU
	vision_rays = 28
	proximity_radius = 0.0
	detect_rate = 1.1
	turn_rate = 10.0
	fire_interval = 0.8
	burst_count = 2
	burst_gap = 0.08
	bullet_damage = 6.0
	bullet_speed = 720.0
	spread = deg_to_rad(4.0)
	attack_range = 300.0
	preferred_range = 170.0
	body_radius = 11.0
	color = Palette.MAGENTA
	credit_drop = 10
	search_duration = 8.0
	radio_delay = 0.9
	reaction_time = 0.35


func _draw_body() -> void:
	var line := _line_color()
	var bob := sin(anim_t * 6.0) * 1.5
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	# Rotors.
	for i in 4:
		var a := PI * 0.25 + PI * 0.5 * i
		var p := Vector2.from_angle(a) * 12.0
		draw_line(Vector2.ZERO, p, Palette.with_alpha(line, 0.6), 2.0)
		draw_arc(p, 5.0, anim_t * 30.0, anim_t * 30.0 + 2.2, 6, Palette.with_alpha(line, 0.8), 1.5, true)
		draw_arc(p, 5.0, anim_t * 30.0 + PI, anim_t * 30.0 + PI + 2.2, 6, Palette.with_alpha(line, 0.8), 1.5, true)
	# Hex hull.
	var hull := PackedVector2Array()
	for i in 6:
		hull.append(Vector2.from_angle(TAU * i / 6.0) * 8.0)
	draw_colored_polygon(hull, Color(0.14, 0.06, 0.12))
	hull.append(hull[0])
	draw_polyline(hull, line, 1.8, true)
	# Eye looks in facing direction.
	var eye := Vector2.from_angle(facing) * 3.5
	draw_circle(eye, 3.4, Palette.with_alpha(line, 0.35))
	draw_circle(eye, 1.8, Palette.WHITE if state == State.CHASE else line)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Drones orbit the player instead of strafing in straight lines.
func _combat_move(p: Player, delta: float) -> void:
	var to := p.global_position - global_position
	var d := to.length()
	if d > preferred_range * 1.3:
		_move_to(p.global_position, chase_speed, delta, false)
		return
	var tangent := to.normalized().orthogonal() * strafe_dir
	var radial := to.normalized() * (d - preferred_range) * 1.5
	velocity = velocity.move_toward(tangent * chase_speed * 0.8 + radial, 900.0 * delta)
	if get_slide_collision_count() > 0:
		strafe_dir = -strafe_dir
