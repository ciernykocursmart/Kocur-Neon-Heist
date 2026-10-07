class_name EnemyGuard
extends Enemy
## Security guard: balanced rifleman with a forward vision cone and 3-round bursts.


func _configure() -> void:
	kind = "guard"
	display_name = "GUARD"
	max_hp = 60.0
	patrol_speed = 72.0
	chase_speed = 150.0
	vision_range = 320.0
	vision_fov = deg_to_rad(78.0)
	fire_interval = 1.1
	burst_count = 3
	burst_gap = 0.11
	bullet_damage = 8.0
	bullet_speed = 600.0
	spread = deg_to_rad(6.0)
	attack_range = 380.0
	preferred_range = 230.0
	body_radius = 13.0
	color = Palette.ORANGE
	credit_drop = 15
	search_duration = 10.0


func _draw_body() -> void:
	var line := _line_color()
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	# Shoulders.
	draw_rect(Rect2(Vector2(-6, -15), Vector2(12, 30)), Color(0.13, 0.1, 0.12))
	draw_rect(Rect2(Vector2(-6, -15), Vector2(12, 30)), Palette.with_alpha(line, 0.8), false, 1.5)
	# Rifle.
	draw_rect(Rect2(Vector2(4, 4), Vector2(20, 4)), Color(0.25, 0.22, 0.25))
	draw_rect(Rect2(Vector2(21, 4), Vector2(3, 4)), line)
	# Helmet.
	draw_circle(Vector2.ZERO, 10.0, Color(0.16, 0.12, 0.14))
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 20, line, 2.0, true)
	# Visor.
	draw_arc(Vector2.ZERO, 7.0, -0.8, 0.8, 8, Palette.with_alpha(line, 0.4), 5.0, true)
	draw_arc(Vector2.ZERO, 7.0, -0.7, 0.7, 8, Palette.WHITE.lerp(line, 0.4), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
