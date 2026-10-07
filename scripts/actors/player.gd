class_name Player
extends CharacterBody2D
## The cybernetic cat. Handles movement (walk / sneak / dash), mouse aiming,
## the plasma pistol (fire, reload, ammo), claw melee with silent takedowns,
## health, damage feedback and its own procedural drawing.

signal health_changed(hp: float, max_hp: float)
signal ammo_changed(mag: int, reserve: int)
signal died

const LAYER := 2
const RADIUS := 12.0
const FIRE_INTERVAL := 0.15
const MELEE_RANGE := 50.0
const MELEE_ARC := deg_to_rad(80.0)
const MAX_RESERVE := 120

var game: Game

var max_hp := 100.0
var hp := 100.0
var speed := 225.0
var mag_size := 12
var mag := 12
var reserve := 48
var damage := 20.0
var reload_time := 1.15
var dash_cooldown := 1.0

var aim_angle := 0.0
var locked := false
var dead := false
var sneaking := false
var reloading := false
var reload_timer := 0.0
var fire_timer := 0.0
var melee_timer := 0.0
var dash_timer := 0.0
var dash_time := 0.0
var dash_dir := Vector2.ZERO
var invuln := 0.0
var hurt_flash := 0.0
var step_timer := 0.0
var walk_phase := 0.0
var recoil := 0.0
var claw_anim := 0.0
var _light: Sprite2D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	cs.shape = shape
	add_child(cs)
	_light = FX.make_light(Palette.CYAN, 190.0, 0.22)
	_light.z_index = -1
	add_child(_light)
	apply_upgrades()


func apply_upgrades() -> void:
	max_hp = GameState.player_max_hp()
	hp = max_hp
	speed = GameState.player_speed()
	mag_size = GameState.mag_size()
	mag = mag_size
	reserve = mag_size * 4
	damage = GameState.weapon_damage()
	reload_time = GameState.reload_time()
	dash_cooldown = GameState.dash_cooldown()
	health_changed.emit(hp, max_hp)
	ammo_changed.emit(mag, reserve)


## 0..1+ multiplier applied to how fast enemies/cameras notice the cat.
func visibility() -> float:
	var v := GameState.detection_multiplier()
	if sneaking:
		v *= 0.55
	elif velocity.length() < 20.0:
		v *= 0.8
	return v


func _physics_process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 3.0)
	invuln = maxf(0.0, invuln - delta)
	recoil = maxf(0.0, recoil - delta * 10.0)
	claw_anim = maxf(0.0, claw_anim - delta * 5.0)
	fire_timer -= delta
	melee_timer -= delta
	dash_timer -= delta
	if dead:
		return

	aim_angle = (get_global_mouse_position() - global_position).angle()

	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	if locked:
		velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	sneaking = Input.is_action_pressed("sneak")

	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_dir * 640.0
		if Engine.get_physics_frames() % 2 == 0:
			FX.burst(game.fx_layer, global_position, Palette.with_alpha(Palette.CYAN, 0.6), 3, 40.0, 0.25, 3.0)
	else:
		var target_speed := speed * (0.5 if sneaking else 1.0)
		var target := input * target_speed
		var accel := 2600.0 if input != Vector2.ZERO else 3000.0
		velocity = velocity.move_toward(target, accel * delta)
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
			_dash(input)

	move_and_slide()

	# Footstep noise while running (sneaking is silent).
	if velocity.length() > 60.0:
		walk_phase += delta * velocity.length() * 0.06
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.32
			if not sneaking and dash_time <= 0.0:
				game.emit_noise(global_position, 115.0, false)
				Sfx.play_at("footstep", global_position, -14.0, 1.0, 0.2)

	if Input.is_action_pressed("fire"):
		_try_fire()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("melee"):
		_melee()
	if Input.is_action_just_pressed("interact"):
		game.request_interact()

	queue_redraw()


func _dash(input: Vector2) -> void:
	dash_dir = input.normalized() if input != Vector2.ZERO else Vector2.from_angle(aim_angle)
	dash_time = 0.16
	dash_timer = dash_cooldown
	invuln = maxf(invuln, 0.2)
	Sfx.play_at("dash", global_position, -4.0)
	game.emit_noise(global_position, 150.0, false)


func _try_fire() -> void:
	if fire_timer > 0.0 or reloading:
		return
	if mag <= 0:
		fire_timer = 0.3
		Sfx.play("empty")
		start_reload()
		return
	fire_timer = FIRE_INTERVAL
	mag -= 1
	recoil = 1.0
	var dir := Vector2.from_angle(aim_angle + randf_range(-0.03, 0.03))
	var muzzle := global_position + Vector2.from_angle(aim_angle) * 24.0 + Vector2.from_angle(aim_angle + PI * 0.5) * 7.0
	game.spawn_bullet(muzzle, dir * 1150.0, damage, true, Palette.CYAN)
	FX.flash(game.fx_layer, muzzle, Palette.CYAN, 70.0, 0.08, 0.9)
	FX.burst(game.fx_layer, muzzle, Palette.CYAN, 5, 260.0, 0.12, 2.5, dir, 25.0)
	Sfx.play_at("shoot", global_position, -3.0)
	game.camera.shake(0.12)
	game.camera.kick(-dir * 4.0)
	game.emit_noise(global_position, GameState.gun_noise_radius(), true)
	ammo_changed.emit(mag, reserve)
	if mag == 0:
		start_reload()


func start_reload() -> void:
	if reloading or mag >= mag_size or reserve <= 0:
		return
	reloading = true
	reload_timer = reload_time
	Sfx.play_at("reload", global_position, -2.0)


func _finish_reload() -> void:
	reloading = false
	var needed := mag_size - mag
	var taken := mini(needed, reserve)
	mag += taken
	reserve -= taken
	ammo_changed.emit(mag, reserve)


func reload_progress() -> float:
	return 1.0 - reload_timer / reload_time if reloading else 0.0


func _melee() -> void:
	if melee_timer > 0.0:
		return
	melee_timer = 0.45
	claw_anim = 1.0
	Sfx.play_at("claw", global_position, -2.0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to := enemy.global_position - global_position
		if to.length() > MELEE_RANGE + enemy.body_radius:
			continue
		if absf(angle_difference(aim_angle, to.angle())) > MELEE_ARC:
			continue
		hit_any = true
		if enemy.is_unaware():
			enemy.take_damage(9999.0, global_position, true)
			FX.float_text(game.fx_layer, enemy.global_position + Vector2(0, -30), "TAKEDOWN", Palette.MAGENTA, 15)
		else:
			enemy.take_damage(damage * 1.75, global_position, false)
	var tip := global_position + Vector2.from_angle(aim_angle) * 30.0
	FX.burst(game.fx_layer, tip, Palette.MAGENTA, 8 if hit_any else 4, 200.0, 0.2, 2.5, Vector2.from_angle(aim_angle), 50.0)
	if hit_any:
		game.camera.shake(0.2)


func add_ammo(amount: int) -> void:
	reserve = mini(reserve + amount, MAX_RESERVE)
	ammo_changed.emit(mag, reserve)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func take_damage(amount: float, from_pos: Vector2, _silent := false) -> void:
	if dead or invuln > 0.0:
		return
	hp -= amount
	hurt_flash = 1.0
	invuln = 0.08
	velocity += (global_position - from_pos).normalized() * 160.0
	health_changed.emit(hp, max_hp)
	Sfx.play("player_hurt", -2.0)
	FX.burst(game.fx_layer, global_position, Palette.RED, 10, 220.0, 0.3, 3.0)
	game.camera.shake(0.35)
	game.on_player_damaged(amount)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	hp = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	health_changed.emit(hp, max_hp)
	FX.burst(game.fx_layer, global_position, Palette.CYAN, 40, 380.0, 0.9, 4.0)
	FX.burst(game.fx_layer, global_position, Palette.MAGENTA, 24, 260.0, 0.7, 3.0)
	FX.flash(game.fx_layer, global_position, Palette.CYAN, 260.0, 0.6, 1.0)
	Sfx.play("game_over")
	game.camera.shake(0.8)
	queue_redraw()
	died.emit()


# --------------------------------------------------------------------------
# Drawing — a top-down neon cat facing its aim direction.
# --------------------------------------------------------------------------

func _ellipse(center: Vector2, rx: float, ry: float, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	if dead:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var blink := invuln > 0.0 and hurt_flash > 0.0 and int(t * 30.0) % 2 == 0
	var body_col := Color(0.11, 0.11, 0.2)
	var line_col := Palette.CYAN
	if hurt_flash > 0.0:
		body_col = body_col.lerp(Palette.RED, hurt_flash * 0.8)
		line_col = line_col.lerp(Palette.WHITE, hurt_flash)
	if sneaking:
		line_col = line_col.lerp(Palette.PURPLE, 0.6)
		body_col.a = 0.75
	if blink:
		line_col = Palette.WHITE

	# Shadow / glow disc.
	draw_circle(Vector2(0, 3), 15.0, Color(0, 0, 0, 0.35))

	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	var moving := velocity.length() > 30.0
	var stride := sin(walk_phase) * 4.0 if moving else 0.0

	# Tail (wavy polyline).
	var tail := PackedVector2Array()
	for i in 8:
		var k := i / 7.0
		tail.append(Vector2(-12.0 - k * 18.0, sin(t * 5.0 + k * 3.0) * (2.0 + k * 6.0)))
	draw_polyline(tail, Palette.with_alpha(Palette.MAGENTA, 0.3), 7.0, true)
	draw_polyline(tail, Palette.MAGENTA, 3.0, true)

	# Paws.
	var paw_col := Palette.with_alpha(line_col, 0.85)
	draw_circle(Vector2(6 + stride, -8), 2.6, paw_col)
	draw_circle(Vector2(6 - stride, 8), 2.6, paw_col)
	draw_circle(Vector2(-8 - stride, -8), 2.6, paw_col)
	draw_circle(Vector2(-8 + stride, 8), 2.6, paw_col)

	# Body.
	var body := _ellipse(Vector2(-2, 0), 13.0, 9.0)
	draw_colored_polygon(body, body_col)
	body.append(body[0])
	draw_polyline(body, Palette.with_alpha(line_col, 0.35), 5.0, true)
	draw_polyline(body, line_col, 1.8, true)
	# Cybernetic spine light.
	draw_line(Vector2(-10, 0), Vector2(4, 0), Palette.with_alpha(Palette.MAGENTA, 0.9), 2.0, true)

	# Gun (right side), with recoil.
	var gx := -recoil * 4.0
	draw_rect(Rect2(Vector2(4 + gx, 5), Vector2(20, 4)), Color(0.2, 0.22, 0.35))
	draw_rect(Rect2(Vector2(20 + gx, 5), Vector2(4, 4)), Palette.CYAN)

	# Head + ears.
	var head_c := Vector2(11, 0)
	draw_circle(head_c, 8.0, body_col)
	draw_arc(head_c, 8.0, 0, TAU, 20, line_col, 1.8, true)
	var ear_l := PackedVector2Array([head_c + Vector2(-3, -6), head_c + Vector2(2, -13), head_c + Vector2(5, -5)])
	var ear_r := PackedVector2Array([head_c + Vector2(-3, 6), head_c + Vector2(2, 13), head_c + Vector2(5, 5)])
	draw_colored_polygon(ear_l, body_col)
	draw_colored_polygon(ear_r, body_col)
	ear_l.append(ear_l[0])
	ear_r.append(ear_r[0])
	draw_polyline(ear_l, line_col, 1.5, true)
	draw_polyline(ear_r, line_col, 1.5, true)
	# Glowing eyes.
	var eye_col := Palette.YELLOW if game != null and game.alarm != null and game.alarm.level == AlarmSystem.Level.ALARM else Palette.CYAN
	draw_circle(head_c + Vector2(4, -3), 2.6, Palette.with_alpha(eye_col, 0.35))
	draw_circle(head_c + Vector2(4, 3), 2.6, Palette.with_alpha(eye_col, 0.35))
	draw_circle(head_c + Vector2(4.5, -3), 1.3, eye_col)
	draw_circle(head_c + Vector2(4.5, 3), 1.3, eye_col)

	# Claw swipe arc.
	if claw_anim > 0.0:
		var a0 := -MELEE_ARC * (1.0 - claw_anim)
		draw_arc(Vector2.ZERO, MELEE_RANGE - 8.0, a0 - 0.6, a0 + 0.6, 12, Palette.with_alpha(Palette.MAGENTA, claw_anim), 4.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Reload ring.
	if reloading:
		draw_arc(Vector2.ZERO, 20.0, -PI * 0.5, -PI * 0.5 + TAU * reload_progress(), 24, Palette.YELLOW, 2.0, true)
	# Dash ready pip.
	if dash_timer > 0.0:
		var k := 1.0 - dash_timer / dash_cooldown
		draw_arc(Vector2.ZERO, 24.0, PI * 0.5 - 0.5, PI * 0.5 - 0.5 + k, 8, Palette.with_alpha(Palette.CYAN, 0.5), 2.0, true)
