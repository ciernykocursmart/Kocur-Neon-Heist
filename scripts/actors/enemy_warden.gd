class_name EnemyWarden
extends Enemy
## WARDEN: the final guardian - a physical avatar of the security AI.
## Dormant until the cat enters its vault, then fights in three phases:
##   1. aimed volleys and bullet rings
##   2. + summons drone escorts, denser rings
##   3. + telegraphed ramming charges, double rings
## Immune to takedowns and to noise/alarm logic.

signal phase_changed(phase: int)

var active := false
var phase := 1
var attack_timer := 2.2
var attack_step := 0
var volley_left := 0
var volley_timer := 0.0
var charge_windup := 0.0
var charge_time := 0.0
var charge_dir := Vector2.ZERO
var contact_timer := 0.0
var ring_spin := 0.0


func _configure() -> void:
	kind = "warden"
	display_name = "WARDEN"
	max_hp = 1300.0
	patrol_speed = 0.0
	chase_speed = 85.0
	vision_range = 900.0
	vision_fov = TAU
	vision_rays = 4
	proximity_radius = 0.0
	bullet_damage = 9.0
	bullet_speed = 380.0
	body_radius = 30.0
	color = Palette.RED
	credit_drop = 0
	knockback_scale = 0.02
	radio_delay = 0.0


func can_be_taken_down() -> bool:
	return false


func is_unaware() -> bool:
	return false


func hear_noise(_pos: Vector2, _loud: bool) -> void:
	pass


func on_alarm(_pos: Vector2) -> void:
	pass


func activate() -> void:
	if active:
		return
	active = true
	state = State.CHASE
	awareness = 1.0
	attack_timer = 1.6
	Sfx.play("boss_roar", 2.0)
	FX.ring(game.fx_layer, global_position, Palette.RED, 420.0, 1.0, 5.0)
	game.camera.shake(0.6)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	anim_t += delta
	ring_spin += delta * (0.6 + phase * 0.4)
	hit_flash = maxf(0.0, hit_flash - delta * 5.0)
	contact_timer -= delta
	queue_redraw()
	if not active:
		return
	var p := game.player
	if p == null or p.dead:
		velocity = Vector2.ZERO
		return
	var to := p.global_position - global_position
	var d := to.length()

	if charge_windup > 0.0:
		charge_windup -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		if charge_windup <= 0.0:
			charge_time = 0.5
			Sfx.play_at("dash", global_position, 2.0, 0.6)
	elif charge_time > 0.0:
		charge_time -= delta
		velocity = charge_dir * 560.0
		if Engine.get_physics_frames() % 2 == 0:
			FX.burst(game.fx_layer, global_position, Palette.RED, 4, 60.0, 0.3, 4.0)
	else:
		facing = lerp_angle(facing, to.angle(), minf(1.0, delta * 4.0))
		var desired := Vector2.ZERO
		if d > 330.0:
			desired = to.normalized() * chase_speed
		elif d < 170.0:
			desired = -to.normalized() * chase_speed
		else:
			desired = to.normalized().orthogonal() * chase_speed * 0.7 * strafe_dir
		velocity = velocity.move_toward(desired, 300.0 * delta)
		_run_attacks(p, delta)

	move_and_slide()
	if get_slide_collision_count() > 0:
		strafe_dir = -strafe_dir
		if charge_time > 0.0:
			charge_time = 0.0
			game.camera.shake(0.4)
			Sfx.play_at("explode", global_position, -6.0, 1.4)
	# Contact damage.
	if d < body_radius + Player.RADIUS + 4.0 and contact_timer <= 0.0:
		contact_timer = 0.7
		p.take_damage(22.0 if charge_time > 0.0 else 12.0, global_position)


func _run_attacks(p: Player, delta: float) -> void:
	if volley_left > 0:
		volley_timer -= delta
		if volley_timer <= 0.0:
			volley_left -= 1
			volley_timer = 0.22
			_volley(p.global_position)
		return
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	var pattern := ["volley", "ring", "volley", "ring"]
	if phase >= 2:
		pattern = ["volley", "ring", "summon", "volley", "ring"]
	if phase >= 3:
		pattern = ["charge", "ring", "volley", "charge", "double_ring", "summon"]
	var attack: String = pattern[attack_step % pattern.size()]
	attack_step += 1
	attack_timer = 2.0 - 0.3 * (phase - 1)
	match attack:
		"volley":
			volley_left = 3 + phase
			volley_timer = 0.0
		"ring":
			_ring(14 + phase * 4, ring_spin)
		"double_ring":
			_ring(22, ring_spin)
			get_tree().create_timer(0.35, false).timeout.connect(func():
				if state != State.DEAD:
					_ring(22, ring_spin + PI / 22.0))
		"summon":
			game.spawn_boss_escort(global_position, 2)
			Sfx.play_at("warp", global_position, 0.0, 0.7)
		"charge":
			charge_dir = (p.global_position - global_position).normalized()
			charge_windup = 0.55
			Sfx.play_at("laser_charge", global_position, 0.0, 0.6)


func _volley(target: Vector2) -> void:
	var base := (target - global_position).angle()
	for i in 5:
		var a := base + (i - 2) * 0.12
		game.spawn_bullet(global_position + Vector2.from_angle(a) * (body_radius + 6.0), Vector2.from_angle(a) * (bullet_speed + 120.0), bullet_damage, false, Palette.MAGENTA)
	Sfx.play_at("boss_shot", global_position, -3.0)
	FX.flash(game.fx_layer, global_position + Vector2.from_angle(base) * body_radius, Palette.MAGENTA, 70.0, 0.1, 0.8)


func _ring(count: int, offset: float) -> void:
	for i in count:
		var a := offset + TAU * i / count
		game.spawn_bullet(global_position + Vector2.from_angle(a) * (body_radius + 6.0), Vector2.from_angle(a) * bullet_speed, bullet_damage, false, Palette.RED, {"life": 2.4})
	Sfx.play_at("boss_shot", global_position, -1.0, 0.7)
	FX.ring(game.fx_layer, global_position, Palette.RED, 90.0, 0.3, 3.0)


func take_damage(amount: float, from_pos: Vector2, silent := false, knockback := 110.0) -> void:
	if not active or state == State.DEAD:
		if not active and amount > 0.0:
			activate()
		return
	super.take_damage(amount, from_pos, silent, knockback)
	var ratio := hp / max_hp
	var new_phase := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if new_phase > phase and state != State.DEAD:
		phase = new_phase
		attack_timer = 1.2
		Sfx.play("boss_roar", 0.0, 1.1 + 0.1 * phase)
		FX.ring(game.fx_layer, global_position, Palette.MAGENTA, 300.0, 0.8, 5.0)
		game.camera.shake(0.5)
		_ring(30, 0.0)
		phase_changed.emit(phase)
		game.notify("WARDEN - PHASE %d" % phase, Palette.RED)


func _die(silent: bool) -> void:
	super._die(silent)
	remove_from_group("corpses")
	FX.burst(game.fx_layer, global_position, Palette.RED, 80, 520.0, 1.2, 5.0)
	FX.burst(game.fx_layer, global_position, Palette.WHITE, 40, 380.0, 0.8, 3.0)
	FX.ring(game.fx_layer, global_position, Palette.WHITE, 500.0, 1.2, 6.0)
	Sfx.play("boss_death", 2.0)
	game.on_boss_defeated(self)


func _draw_body() -> void:
	var line := _line_color()
	var k := hp / max_hp
	var core_col := Palette.RED.lerp(Palette.MAGENTA, 1.0 - k)
	if not active:
		core_col = Palette.DIM
	# Outer rotating rings.
	for i in 3:
		var r := body_radius + 8.0 + i * 7.0
		var a0 := ring_spin * (1.0 if i % 2 == 0 else -1.3) + i
		draw_arc(Vector2.ZERO, r, a0, a0 + PI * 0.8, 20, Palette.with_alpha(core_col, 0.55 - i * 0.12), 3.0, true)
		draw_arc(Vector2.ZERO, r, a0 + PI, a0 + PI * 1.8, 20, Palette.with_alpha(core_col, 0.55 - i * 0.12), 3.0, true)
	# Hull.
	var hull := PackedVector2Array()
	for i in 6:
		hull.append(Vector2.from_angle(TAU * i / 6.0 + ring_spin * 0.2) * body_radius)
	draw_colored_polygon(hull, Color(0.1, 0.03, 0.06))
	hull.append(hull[0])
	draw_polyline(hull, Palette.with_alpha(line, 0.4), 7.0, true)
	draw_polyline(hull, line, 2.5, true)
	# Eye tracking the cat.
	var eye := Vector2.from_angle(facing) * 9.0
	draw_circle(eye, 11.0, Palette.with_alpha(core_col, 0.3))
	draw_circle(eye, 6.0, core_col)
	draw_circle(eye + Vector2.from_angle(facing) * 2.0, 2.5, Palette.WHITE)
	if charge_windup > 0.0:
		draw_line(Vector2.ZERO, charge_dir * 400.0, Palette.with_alpha(Palette.RED, 0.5), 3.0, true)


func _draw_indicator() -> void:
	if not active:
		var f := FX.font()
		draw_string(f, Vector2(-40, -body_radius - 26), "DORMANT", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Palette.DIM)
