extends Node2D
## Player combat: claw swipes and the feline pounce.
## Each swing/pounce keeps a set of already-hit targets, so one attack can
## never damage the same enemy more than once.

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")

const ATTACK_TIME := 0.26
const ACTIVE_START := 0.03
const ACTIVE_END := 0.15
const ATTACK_COOLDOWN := 0.30
const ATTACK_BUFFER := 0.12
const CLAW_SIZE := Vector2(26, 20)
const CLAW_OFFSET := Vector2(14, -8)
const POUNCE_TIME := 0.2
const POUNCE_SPEED := 330.0
const POUNCE_INVULN := 0.15
const ENEMY_MASK := 4      # physics layer 3
const PROJECTILE_MASK := 16  # physics layer 5

var player: CharacterBody2D
var attack_timer := 0.0
var attack_cd := 0.0
var attack_buffer := 0.0
var pounce_timer := 0.0
var pounce_cd := 0.0
var pounce_dir := Vector2.RIGHT
var _hit_this_swing: Dictionary = {}
var _hit_this_pounce: Dictionary = {}
var claw_area: Area2D
var claw_shape: CollisionShape2D
var pounce_area: Area2D
var slash: AnimatedSprite2D
var total_hits := 0


func setup(p: CharacterBody2D) -> void:
	player = p
	claw_area = _make_area(CLAW_SIZE)
	claw_shape = claw_area.get_child(0)
	pounce_area = _make_area(Vector2(18, 16))
	(pounce_area.get_child(0) as CollisionShape2D).position = Vector2(0, -8)
	slash = Sprites.make_sprite("slash")
	slash.visible = false
	slash.z_index = 5
	add_child(slash)


func _make_area(size: Vector2) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = ENEMY_MASK | PROJECTILE_MASK
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	a.add_child(cs)
	add_child(a)
	return a


func _physics_process(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	pounce_cd = maxf(pounce_cd - delta, 0.0)
	attack_buffer = maxf(attack_buffer - delta, 0.0)
	if player.input_enabled and Input.is_action_just_pressed("attack"):
		attack_buffer = ATTACK_BUFFER
	if attack_buffer > 0.0 and attack_cd <= 0.0 and player.is_controllable():
		_start_attack()
	if attack_timer > 0.0:
		attack_timer -= delta
		var elapsed := ATTACK_TIME - attack_timer
		claw_shape.position = Vector2(CLAW_OFFSET.x * player.facing, CLAW_OFFSET.y)
		slash.position = Vector2(12 * player.facing, -10)
		slash.flip_h = player.facing < 0
		if elapsed >= ACTIVE_START and elapsed <= ACTIVE_END:
			_apply_claw_hits()
		if attack_timer <= 0.0:
			slash.visible = false


func _start_attack() -> void:
	attack_buffer = 0.0
	attack_timer = ATTACK_TIME
	attack_cd = ATTACK_COOLDOWN
	_hit_this_swing.clear()
	slash.visible = true
	slash.frame = 0
	slash.play("default")
	player.stats["attacks"] += 1
	Audio.play("claw", -3.0)


func _apply_claw_hits() -> void:
	var dmg: int = Progress.claw_damage()
	for body in claw_area.get_overlapping_bodies():
		if _hit_this_swing.has(body.get_instance_id()):
			continue
		if body.has_method("take_hit"):
			_hit_this_swing[body.get_instance_id()] = true
			var landed: bool = body.take_hit(dmg, player.global_position, "claw")
			if landed:
				total_hits += 1
				_on_hit_feedback(body)
	for area in claw_area.get_overlapping_areas():
		if _hit_this_swing.has(area.get_instance_id()):
			continue
		if area.has_method("deflect"):
			_hit_this_swing[area.get_instance_id()] = true
			area.deflect()


func _on_hit_feedback(body: Node) -> void:
	var lvl: Node = player.level
	if lvl:
		Fx.spark(lvl, (body as Node2D).global_position + Vector2(0, -10))
		if lvl.has_method("hitstop"):
			lvl.hitstop(0.045)
	Audio.play("hit")


func is_attacking() -> bool:
	return attack_timer > 0.0


# --------------------------------------------------------------------------
# Pounce
# --------------------------------------------------------------------------

func pounce_ready() -> bool:
	return pounce_cd <= 0.0 and pounce_timer <= 0.0


func pounce_cooldown_ratio() -> float:
	var full: float = Progress.pounce_cooldown()
	return clampf(pounce_cd / full, 0.0, 1.0) if full > 0 else 0.0


func start_pounce(dir: Vector2) -> void:
	pounce_dir = dir
	pounce_timer = POUNCE_TIME
	pounce_cd = Progress.pounce_cooldown()
	attack_timer = 0.0
	slash.visible = false
	_hit_this_pounce.clear()
	player.velocity = dir * POUNCE_SPEED
	Audio.play("pounce")
	if player.level:
		Fx.dust(player.level, player.global_position)


## Returns false when the pounce has finished.
func update_pounce(delta: float) -> bool:
	pounce_timer -= delta
	player.velocity = pounce_dir * POUNCE_SPEED
	(pounce_area.get_child(0) as CollisionShape2D).position = Vector2(6 * player.facing, -8)
	var dmg: int = Progress.pounce_damage()
	for body in pounce_area.get_overlapping_bodies():
		if _hit_this_pounce.has(body.get_instance_id()) or not body.has_method("take_hit"):
			continue
		_hit_this_pounce[body.get_instance_id()] = true
		if body.take_hit(dmg, player.global_position, "pounce"):
			total_hits += 1
			_on_hit_feedback(body)
			pounce_timer = 0.0
			player.pounce_bounce()
			return true
	for area in pounce_area.get_overlapping_areas():
		if area.has_method("deflect"):
			area.deflect()
	if player.level and Engine.get_physics_frames() % 3 == 0:
		Fx.afterimage(player.level, player.sprite)
	return pounce_timer > 0.0


func end_pounce() -> void:
	pounce_timer = 0.0


func pounce_invulnerable() -> bool:
	return pounce_timer > POUNCE_TIME - POUNCE_INVULN


func cancel() -> void:
	attack_timer = 0.0
	attack_buffer = 0.0
	pounce_timer = 0.0
	slash.visible = false


func reset_cooldowns() -> void:
	attack_cd = 0.0
	pounce_cd = 0.0
