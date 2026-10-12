extends CharacterBody2D
## Shared enemy behaviour: physics, health, damage feedback, contact damage,
## ledge/wall awareness, line of sight and a small state machine.
## Variants override _think() and the tuning variables in _configure().

signal defeated(enemy: Node)

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const ProjectileScript := preload("res://scripts/enemies/projectile.gd")

enum S { PATROL, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD, STUNNED, RETREAT }

var level: Node
var sheet := "scout"
var display_name := "White Scout"
var max_hp := 4
var hp := 4
var speed := 35.0
var chase_speed := 70.0
var contact_damage := 2
var attack_damage := 2
var gravity := 900.0
var facing := -1
var state: S = S.PATROL
var state_t := 0.0
var detect_range := 150.0
var knockback := 140.0
var knock_resist := 0.0
var hurt_stun := 0.25
var poise := false
var body_size := Vector2(12, 20)
var sprite_offset := Vector2(0, -14)
var spawn_position := Vector2.ZERO
var attack_box_size := Vector2(26, 16)
var attack_box_offset := Vector2(16, -10)
var attack_active := false
var _attack_hit := false
var _flash := 0.0
var _contact_cd := 0.0
var sprite: AnimatedSprite2D
var hitbox: Area2D
var attack_area: Area2D
var _attack_shape: CollisionShape2D
var rng := RandomNumberGenerator.new()


func _configure() -> void:
	pass


func _ready() -> void:
	add_to_group("enemies")
	rng.randomize()
	_configure()
	hp = max_hp
	collision_layer = 4
	collision_mask = 1 | 64
	floor_snap_length = 4.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body_size
	cs.shape = r
	cs.position = Vector2(0, -body_size.y / 2)
	add_child(cs)
	sprite = Sprites.make_sprite(sheet, "idle")
	sprite.position = sprite_offset
	add_child(sprite)
	hitbox = _area(body_size - Vector2(2, 2), Vector2(0, -body_size.y / 2))
	attack_area = _area(attack_box_size, Vector2.ZERO)
	_attack_shape = attack_area.get_child(0)
	spawn_position = global_position


func _area(size: Vector2, offset: Vector2) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	a.add_child(cs)
	add_child(a)
	return a


func _physics_process(delta: float) -> void:
	state_t += delta
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if state == S.DEAD:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		velocity.y = minf(velocity.y + gravity * delta, 400)
		move_and_slide()
		return
	if state == S.HURT:
		velocity.x = move_toward(velocity.x, 0, 500 * delta)
		if state_t >= hurt_stun:
			_set_state(S.CHASE)
	else:
		_think(delta)
	velocity.y = minf(velocity.y + gravity * delta, 400)
	move_and_slide()
	_attack_shape.position = Vector2(attack_box_offset.x * facing, attack_box_offset.y)
	if attack_active and not _attack_hit:
		for b in attack_area.get_overlapping_bodies():
			if b.is_in_group("player") and b.hurt(attack_damage, global_position):
				_attack_hit = true
	if _contact_cd <= 0.0:
		for b in hitbox.get_overlapping_bodies():
			if b.is_in_group("player"):
				if b.hurt(current_contact_damage(), global_position):
					_contact_cd = 0.5
	_update_visual(delta)
	if level and global_position.y > level.grid.pixel_size().y + 48:
		_fell_out()


func current_contact_damage() -> int:
	return contact_damage


## Override in variants.
func _think(_delta: float) -> void:
	_patrol()
	if can_see_player():
		_set_state(S.CHASE)


func _set_state(s: S) -> void:
	state = s
	state_t = 0.0
	attack_active = false
	_on_state(s)


func _on_state(_s: S) -> void:
	pass


# --------------------------------------------------------------------------
# Senses and movement helpers
# --------------------------------------------------------------------------

func player() -> Node2D:
	return level.player if level else null


func player_alive() -> bool:
	var p := player()
	return p != null and not p.is_dead()


func dx_to_player() -> float:
	var p := player()
	return p.global_position.x - global_position.x if p else 9999.0


func dy_to_player() -> float:
	var p := player()
	return p.global_position.y - global_position.y if p else 9999.0


func face_player() -> void:
	var d := dx_to_player()
	if absf(d) > 2.0:
		facing = 1 if d > 0 else -1


func can_see_player(range_mult := 1.0) -> bool:
	if not player_alive():
		return false
	var dx := dx_to_player()
	var dy := dy_to_player()
	if absf(dx) > detect_range * range_mult or absf(dy) > 56.0:
		return false
	return line_clear(global_position + Vector2(0, -12), player().global_position + Vector2(0, -8))


func line_clear(a: Vector2, b: Vector2) -> bool:
	if level == null:
		return true
	var steps := int(a.distance_to(b) / 8.0) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		var c: Vector2i = level.grid.cell_of(p)
		if level.grid.is_solid(c.x, c.y):
			return false
	return true


func ground_ahead(dir: int, dist := 0.0) -> bool:
	if level == null:
		return true
	var x := global_position.x + dir * (body_size.x * 0.5 + 3.0 + dist)
	var c: Vector2i = level.grid.cell_of(Vector2(x, global_position.y + 4))
	return level.grid.is_solid(c.x, c.y) or level.grid.is_oneway(c.x, c.y)


func wall_ahead(dir: int) -> bool:
	if level == null:
		return false
	var x := global_position.x + dir * (body_size.x * 0.5 + 3.0)
	var c: Vector2i = level.grid.cell_of(Vector2(x, global_position.y - 6))
	var c2: Vector2i = level.grid.cell_of(Vector2(x, global_position.y - body_size.y + 2))
	return level.grid.is_solid(c.x, c.y) or level.grid.is_solid(c2.x, c2.y)


func can_move(dir: int) -> bool:
	return is_on_floor() == false or (ground_ahead(dir) and not wall_ahead(dir))


func _patrol() -> void:
	if not can_move(facing):
		facing = -facing
	velocity.x = facing * speed if can_move(facing) else 0.0


func _chase(stop_dist := 20.0) -> void:
	face_player()
	if absf(dx_to_player()) > stop_dist and can_move(facing):
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0, 20)


# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

## Returns the damage actually taken (variants may block or amplify).
func _modify_damage(amount: int, _from: Vector2, _kind: String) -> int:
	return amount


func take_hit(amount: int, from: Vector2, kind := "claw") -> bool:
	if state == S.DEAD:
		return false
	var dmg := _modify_damage(amount, from, kind)
	if dmg <= 0:
		return false
	hp -= dmg
	_flash = 0.12
	Fx.float_text(level, global_position + Vector2(0, -body_size.y - 6), str(dmg), Color(1, 0.9, 0.5))
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = 1.0
	velocity.x = dir * knockback * (1.0 - knock_resist)
	if hp <= 0:
		die()
		return true
	Audio.play("enemy_hurt", -4.0)
	if not (poise and state in [S.WINDUP, S.ATTACK]):
		_set_state(S.HURT)
		facing = -int(dir)
	return true


func die() -> void:
	if state == S.DEAD:
		return
	_set_state(S.DEAD)
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	sprite.play("death")
	Audio.play("enemy_die", -2.0)
	Progress.add_stat("enemies")
	defeated.emit(self)
	if level:
		Fx.poof(level, global_position + Vector2(0, -body_size.y / 2))
		if level.has_method("on_enemy_defeated"):
			level.on_enemy_defeated(self)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _fell_out() -> void:
	if state != S.DEAD:
		_set_state(S.DEAD)
		defeated.emit(self)
		queue_free()


func reset_to_spawn() -> void:
	if state == S.DEAD:
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp = max_hp
	_set_state(S.PATROL)


# --------------------------------------------------------------------------
# Attacks
# --------------------------------------------------------------------------

func begin_attack() -> void:
	attack_active = true
	_attack_hit = false


func shoot(kind: String, from: Vector2, vel: Vector2, dmg := 2, life := 4.0, grav := 0.0, ground := false) -> Node:
	if level == null:
		return null
	var p := ProjectileScript.new()
	p.level = level
	p.kind = kind
	p.velocity = vel
	p.damage = dmg
	p.lifetime = life
	p.grav = grav
	p.ground_wave = ground
	p.position = from
	level.add_projectile(p)
	return p


# --------------------------------------------------------------------------
# Visuals
# --------------------------------------------------------------------------

func _anim_for_state() -> String:
	match state:
		S.DEAD: return "death"
		S.HURT: return "hurt"
		S.WINDUP: return "windup"
		S.ATTACK: return "attack"
		S.STUNNED: return "hurt"
		S.RECOVER: return "idle"
	return "walk" if absf(velocity.x) > 5.0 else "idle"


func _update_visual(delta: float) -> void:
	sprite.flip_h = facing < 0
	var a := _anim_for_state()
	if sprite.animation != a and sprite.sprite_frames.has_animation(a):
		sprite.play(a)
	_flash = maxf(_flash - delta, 0.0)
	if _flash > 0.0:
		sprite.modulate = Color(3, 3, 3)
	elif state == S.WINDUP:
		var k := 0.5 + 0.5 * sin(state_t * 30.0)
		sprite.modulate = Color(1.0 + k * 0.8, 1.0, 1.0)
	elif state == S.STUNNED:
		sprite.modulate = Color(0.8, 0.8, 1.2)
	else:
		sprite.modulate = Color.WHITE
