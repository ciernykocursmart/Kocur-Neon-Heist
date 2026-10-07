class_name Player
extends CharacterBody2D
## The cybernetic cat. Handles movement (walk / sneak / dash), mouse aiming,
## the weapon loadout (fire, reload, switching, per-weapon ammo), claw melee
## with silent takedowns, the yarn-ball decoy, health/regeneration, damage
## feedback and its own procedural drawing.

signal health_changed(hp: float, max_hp: float)
signal ammo_changed(mag: int, reserve: int)
signal weapon_changed(id: String)
signal died

const LAYER := 2
const RADIUS := 12.0
const MELEE_ARC := deg_to_rad(80.0)
const DECOY_CHARGES := 3
const DECOY_RANGE := 320.0
const REGEN_DELAY := 4.0

var game: Game

var max_hp := 100.0
var hp := 100.0
var speed := 225.0
var dash_cooldown := 1.0

## Loadout: owned weapon ids, current weapon and per-weapon ammo state.
var weapons: Array = ["pistol"]
var weapon_id := "pistol"
var last_weapon_id := "pistol"
var ammo := {}
var mag := 0
var reserve := 0
var mag_size := 10
var decoys := DECOY_CHARGES

var aim_angle := 0.0
var locked := false
var dead := false
var sneaking := false
var concealed := false
var reloading := false
var reload_timer := 0.0
var reload_total := 1.0
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
var since_damage := 99.0
var swap_flash := 0.0
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
	dash_cooldown = GameState.dash_cooldown()
	weapons = GameState.owned_weapons()
	ammo = {}
	for id in weapons:
		var data := Weapons.get_data(id)
		ammo[id] = {"mag": GameState.weapon_mag(id), "reserve": int(data["reserve"])}
	weapon_id = ""
	_select_weapon(weapons[0], true)
	last_weapon_id = weapon_id
	health_changed.emit(hp, max_hp)


func weapon() -> Dictionary:
	return Weapons.get_data(weapon_id)


## 0..1+ multiplier applied to how fast enemies/cameras notice the cat.
func visibility() -> float:
	var v := GameState.detection_multiplier()
	var still := velocity.length() < 20.0
	if sneaking:
		v *= GameState.sneak_visibility_multiplier()
	elif still:
		v *= 0.8
	if game != null and game.facility.is_shadow(global_position) and (sneaking or still):
		v *= 0.35
	return v


func _physics_process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 3.0)
	invuln = maxf(0.0, invuln - delta)
	recoil = maxf(0.0, recoil - delta * 10.0)
	claw_anim = maxf(0.0, claw_anim - delta * 5.0)
	swap_flash = maxf(0.0, swap_flash - delta * 3.0)
	fire_timer -= delta
	melee_timer -= delta
	dash_timer -= delta
	since_damage += delta
	if dead:
		return

	aim_angle = (get_global_mouse_position() - global_position).angle()
	concealed = visibility() < 0.3

	var regen := GameState.regen_rate()
	if regen > 0.0 and since_damage > REGEN_DELAY and hp < max_hp:
		heal(regen * delta)

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
		var target_speed := speed * (GameState.sneak_speed_multiplier() if sneaking else 1.0)
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

	if weapon_id == "smg" or weapon_id == "pistol":
		if Input.is_action_pressed("fire"):
			_try_fire()
	elif Input.is_action_just_pressed("fire") or (Input.is_action_pressed("fire") and fire_timer <= -0.05):
		_try_fire()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("melee"):
		_melee()
	if Input.is_action_just_pressed("interact"):
		game.request_interact()
	if Input.is_action_just_pressed("decoy"):
		throw_decoy(get_global_mouse_position())
	_handle_weapon_input()

	queue_redraw()


# --------------------------------------------------------------------------
# Weapons
# --------------------------------------------------------------------------

func _handle_weapon_input() -> void:
	for i in 3:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)) and i < Weapons.ORDER.size():
			switch_weapon(Weapons.ORDER[i])
	if Input.is_action_just_pressed("weapon_next"):
		cycle_weapon(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		cycle_weapon(-1)
	elif Input.is_action_just_pressed("weapon_swap"):
		switch_weapon(last_weapon_id)


func cycle_weapon(step: int) -> void:
	if weapons.size() < 2:
		return
	var i := weapons.find(weapon_id)
	switch_weapon(weapons[(i + step + weapons.size()) % weapons.size()])


func switch_weapon(id: String) -> void:
	if id == weapon_id or not (id in weapons):
		return
	last_weapon_id = weapon_id
	_select_weapon(id, false)
	Sfx.play("weapon_swap", -4.0)
	swap_flash = 1.0


func _select_weapon(id: String, _silent: bool) -> void:
	if ammo.has(weapon_id):
		ammo[weapon_id]["mag"] = mag
		ammo[weapon_id]["reserve"] = reserve
	weapon_id = id
	reloading = false
	mag = int(ammo[id]["mag"])
	reserve = int(ammo[id]["reserve"])
	mag_size = GameState.weapon_mag(id)
	fire_timer = maxf(fire_timer, 0.12)
	weapon_changed.emit(id)
	ammo_changed.emit(mag, reserve)


func _store_ammo() -> void:
	ammo[weapon_id]["mag"] = mag
	ammo[weapon_id]["reserve"] = reserve


func _dash(input: Vector2) -> void:
	dash_dir = input.normalized() if input != Vector2.ZERO else Vector2.from_angle(aim_angle)
	dash_time = 0.16
	dash_timer = dash_cooldown
	invuln = maxf(invuln, 0.22)
	Sfx.play_at("dash", global_position, -4.0)
	if not GameState.silent_dash():
		game.emit_noise(global_position, 150.0, false)


func _try_fire() -> void:
	if fire_timer > 0.0 or reloading:
		return
	if mag <= 0:
		fire_timer = 0.3
		Sfx.play("empty")
		start_reload()
		return
	var w := weapon()
	fire_timer = float(w["interval"])
	mag -= 1
	recoil = 1.0
	var color: Color = w["color"]
	var aim_dir := Vector2.from_angle(aim_angle)
	var muzzle := global_position + aim_dir * (24.0 + (6.0 if weapon_id != "pistol" else 0.0)) + aim_dir.orthogonal() * 7.0
	var dmg := float(w["damage"]) * GameState.damage_multiplier()
	var pellets := int(w["pellets"])
	for i in pellets:
		var spread := float(w["spread"])
		var a := aim_angle + randf_range(-spread, spread)
		if pellets > 1:
			a = aim_angle + lerpf(-spread, spread, (i + randf()) / pellets)
		var speed_jitter := randf_range(0.9, 1.1) if pellets > 1 else 1.0
		game.spawn_bullet(muzzle, Vector2.from_angle(a) * float(w["speed"]) * speed_jitter, dmg, true, color, {
			"life": float(w["range_time"]),
			"sneak_bonus": float(w["sneak_bonus"]),
			"knockback": float(w["knockback"]) / pellets,
			"weapon": weapon_id,
		})
	var flash_size := 70.0 if pellets == 1 else 120.0
	FX.flash(game.fx_layer, muzzle, color, flash_size, 0.08, 0.95)
	FX.burst(game.fx_layer, muzzle, color, 5 + pellets, 260.0, 0.12, 2.5, aim_dir, 25.0 + pellets * 3.0)
	FX.shell(game.fx_layer, global_position + aim_dir * 8.0, aim_dir.orthogonal(), Palette.YELLOW if weapon_id != "shotgun" else Palette.RED)
	Sfx.play_at(String(w["sound"]), global_position, -3.0, float(w["pitch"]))
	game.camera.shake(float(w["shake"]))
	game.camera.kick(-aim_dir * float(w["kick"]))
	if pellets > 1:
		velocity -= aim_dir * 120.0
	game.emit_noise(global_position, GameState.gun_noise_radius() * float(w["noise"]), true)
	_store_ammo()
	ammo_changed.emit(mag, reserve)
	if mag == 0:
		start_reload()


func start_reload() -> void:
	if reloading or mag >= mag_size or reserve <= 0:
		return
	reloading = true
	reload_total = float(weapon()["reload"]) * GameState.reload_multiplier()
	reload_timer = reload_total
	Sfx.play_at("reload", global_position, -2.0, 1.15 if weapon_id == "smg" else (0.8 if weapon_id == "shotgun" else 1.0))


func _finish_reload() -> void:
	reloading = false
	var needed := mag_size - mag
	var taken := mini(needed, reserve)
	mag += taken
	reserve -= taken
	_store_ammo()
	Sfx.play_at("reload_done", global_position, -6.0)
	ammo_changed.emit(mag, reserve)


func reload_progress() -> float:
	return 1.0 - reload_timer / reload_total if reloading else 0.0


## Ammo pickups feed every owned weapon.
func add_ammo_pack(multiplier := 1.0) -> bool:
	var gained := false
	for id in weapons:
		var data := Weapons.get_data(id)
		var cur: int = int(ammo[id]["reserve"]) if id != weapon_id else reserve
		var max_r := int(data["max_reserve"])
		if cur < max_r:
			var add := int(ceil(int(data["ammo_pickup"]) * multiplier))
			cur = mini(cur + add, max_r)
			gained = true
		if id == weapon_id:
			reserve = cur
		ammo[id]["reserve"] = cur
	_store_ammo()
	ammo_changed.emit(mag, reserve)
	return gained


func add_ammo(amount: int) -> void:
	add_ammo_pack(float(amount) / 10.0)


func total_reserve_full() -> bool:
	for id in weapons:
		var cur: int = int(ammo[id]["reserve"]) if id != weapon_id else reserve
		if cur < int(Weapons.get_data(id)["max_reserve"]):
			return false
	return true


# --------------------------------------------------------------------------
# Melee, decoy, health
# --------------------------------------------------------------------------

func _melee() -> void:
	if melee_timer > 0.0:
		return
	melee_timer = 0.45
	claw_anim = 1.0
	Sfx.play_at("claw", global_position, -2.0)
	var hit_any := false
	var reach := GameState.melee_range()
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to := enemy.global_position - global_position
		if to.length() > reach + enemy.body_radius:
			continue
		if absf(angle_difference(aim_angle, to.angle())) > MELEE_ARC:
			continue
		hit_any = true
		if enemy.is_unaware() and enemy.can_be_taken_down():
			enemy.take_damage(9999.0, global_position, true)
			FX.float_text(game.fx_layer, enemy.global_position + Vector2(0, -30), "TAKEDOWN", Palette.MAGENTA, 15)
			Sfx.play_at("takedown", enemy.global_position, -2.0)
		else:
			enemy.take_damage(GameState.melee_damage(), global_position, false)
	var tip := global_position + Vector2.from_angle(aim_angle) * 30.0
	FX.burst(game.fx_layer, tip, Palette.MAGENTA, 8 if hit_any else 4, 200.0, 0.2, 2.5, Vector2.from_angle(aim_angle), 50.0)
	if hit_any:
		game.camera.shake(0.2)
		game.hitstop(0.04)


func throw_decoy(target: Vector2) -> void:
	if decoys <= 0:
		Sfx.play("denied", -6.0)
		return
	decoys -= 1
	var to := target - global_position
	if to.length() > DECOY_RANGE:
		to = to.normalized() * DECOY_RANGE
	game.spawn_decoy(global_position, global_position + to)
	Sfx.play_at("decoy_throw", global_position, -4.0)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func take_damage(amount: float, from_pos: Vector2, _silent := false) -> void:
	if dead or invuln > 0.0:
		return
	hp -= amount
	since_damage = 0.0
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
	if concealed:
		line_col.a = 0.55
		body_col.a = 0.5
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
	var gx := -recoil * (4.0 if weapon_id != "shotgun" else 7.0)
	var wcol: Color = weapon()["color"]
	match weapon_id:
		"smg":
			draw_rect(Rect2(Vector2(2 + gx, 4), Vector2(22, 5)), Color(0.2, 0.22, 0.3))
			draw_rect(Rect2(Vector2(8 + gx, 9), Vector2(4, 5)), Color(0.25, 0.25, 0.3))
			draw_rect(Rect2(Vector2(22 + gx, 5), Vector2(4, 3)), wcol)
		"shotgun":
			draw_rect(Rect2(Vector2(0 + gx, 3), Vector2(28, 7)), Color(0.22, 0.18, 0.26))
			draw_line(Vector2(2 + gx, 6.5), Vector2(26 + gx, 6.5), Palette.with_alpha(wcol, 0.6), 1.0)
			draw_rect(Rect2(Vector2(26 + gx, 3), Vector2(4, 7)), wcol)
		_:
			draw_rect(Rect2(Vector2(4 + gx, 5), Vector2(20, 4)), Color(0.2, 0.22, 0.35))
			draw_rect(Rect2(Vector2(20 + gx, 5), Vector2(4, 4)), wcol)

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
		draw_arc(Vector2.ZERO, GameState.melee_range() - 8.0, a0 - 0.6, a0 + 0.6, 12, Palette.with_alpha(Palette.MAGENTA, claw_anim), 4.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Reload ring.
	if reloading:
		draw_arc(Vector2.ZERO, 20.0, -PI * 0.5, -PI * 0.5 + TAU * reload_progress(), 24, Palette.YELLOW, 2.0, true)
	# Dash ready pip.
	if dash_timer > 0.0:
		var k := 1.0 - dash_timer / dash_cooldown
		draw_arc(Vector2.ZERO, 24.0, PI * 0.5 - 0.5, PI * 0.5 - 0.5 + k, 8, Palette.with_alpha(Palette.CYAN, 0.5), 2.0, true)
