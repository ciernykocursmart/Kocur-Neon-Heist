extends CharacterBody2D
## The black-cat hero: movement controller and health/state machine.
## Combat (claw + pounce hitboxes) lives in player_combat.gd as a child.
##
## States are exclusive: NORMAL covers idle/run/air (attacks overlay it),
## POUNCE, HURT and DEAD lock normal movement for a bounded time.

signal hp_changed(hp: int, max_hp: int)
signal shield_changed(charges: int)
signal died
signal respawned
signal healed(amount: int)

enum State { NORMAL, POUNCE, HURT, DEAD }

const Sprites := preload("res://scripts/fx/sprites.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const CombatScript := preload("res://scripts/player/player_combat.gd")

# Movement tuning (pixels, seconds). Mirrored by tests/level_reach.gd.
const RUN_SPEED := 125.0
const ACCEL := 1100.0
const DECEL := 1500.0
const AIR_ACCEL := 850.0
const AIR_DECEL := 600.0
const ICE_ACCEL := 260.0
const ICE_DECEL := 90.0
const JUMP_VELOCITY := 335.0
const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1300.0
const GRAVITY_CUT := 2600.0
const APEX_THRESHOLD := 40.0
const APEX_GRAVITY_MULT := 0.6
const MAX_FALL := 400.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.13
const SPRING_VELOCITY := 520.0
const INVULN_TIME := 1.0
const HURT_TIME := 0.25
const KNOCKBACK := Vector2(170, -170)
const BODY_SIZE := Vector2(10, 14)

var state: State = State.NORMAL
var facing := 1
var hp := 10
var max_hp := 10
var shield := 0
var level: Node = null  ## The Level node (grid queries, hazards); optional in tests.
var input_enabled := true
var invuln := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var jump_held := false
var hurt_timer := 0.0
var air_pounce_available := true
var safe_position := Vector2.ZERO
var _safe_timer := 0.0
var _was_on_floor := true
var ninth_life_used := false
var on_ice := false
var interactables: Array[Node] = []
var stats := {"jumps": 0, "pounces": 0, "attacks": 0}

var sprite: AnimatedSprite2D
var combat: Node2D
var light: PointLight2D
var _prompt: Label
var _flash_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.06
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y / 2)
	add_child(shape)
	sprite = Sprites.make_sprite("hero", "idle")
	sprite.position = Vector2(0, -14)
	add_child(sprite)
	combat = CombatScript.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)
	_prompt = Label.new()
	_prompt.text = "E"
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.position = Vector2(-3, -40)
	_prompt.visible = false
	add_child(_prompt)
	refresh_stats(true)
	safe_position = global_position


## Pull derived values (max health, etc.) from Progress. Called on spawn
## and whenever upgrades/blessings change.
func refresh_stats(full_heal := false) -> void:
	max_hp = Progress.max_hp()
	if full_heal:
		hp = max_hp
		shield = Progress.start_shields()
	hp = mini(hp, max_hp)
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield)


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.POUNCE:
			_process_pounce(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0, DECEL * delta)
			velocity.y = minf(velocity.y + GRAVITY_DOWN * delta, MAX_FALL)
			move_and_slide()
	_update_safe_position(delta)
	_update_visuals(delta)
	_check_fall_out()


func _input_dir() -> float:
	if not input_enabled:
		return 0.0
	return Input.get_axis("move_left", "move_right")


func _process_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_pounce_available = true
		if not _was_on_floor:
			Audio.play("land", -8.0)
			if level:
				Fx.dust(level, global_position)
	else:
		coyote = maxf(coyote - delta, 0.0)
	_was_on_floor = on_floor
	on_ice = on_floor and level != null and level.has_method("is_ice_below") and level.is_ice_below(global_position)

	if input_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	jump_held = input_enabled and Input.is_action_pressed("jump")

	# Horizontal movement with acceleration / deceleration.
	var dir := _input_dir()
	var speed := RUN_SPEED * Progress.speed_multiplier()
	if combat.is_attacking() and on_floor:
		speed *= 0.55
	var target := dir * speed
	var accel: float
	if on_floor:
		if on_ice:
			accel = ICE_ACCEL if absf(dir) > 0.01 else ICE_DECEL
		else:
			accel = ACCEL if absf(dir) > 0.01 else DECEL
	else:
		accel = AIR_ACCEL if absf(dir) > 0.01 else AIR_DECEL
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if absf(dir) > 0.01 and not combat.is_attacking():
		facing = 1 if dir > 0 else -1

	# Jump (buffered + coyote time). Never more than one jump per take-off.
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = -JUMP_VELOCITY * Progress.jump_multiplier()
		jump_buffer = 0.0
		coyote = 0.0
		stats["jumps"] += 1
		Audio.play("jump", -6.0)

	_apply_gravity(delta)
	_move()

	if input_enabled:
		if Input.is_action_just_pressed("pounce"):
			try_pounce()
		elif Input.is_action_just_pressed("interact"):
			_interact()


func _apply_gravity(delta: float) -> void:
	var g := GRAVITY_DOWN
	if velocity.y < 0.0:
		g = GRAVITY_UP if jump_held else GRAVITY_CUT
		if jump_held and absf(velocity.y) < APEX_THRESHOLD:
			g *= APEX_GRAVITY_MULT
	elif jump_held and velocity.y < APEX_THRESHOLD:
		g *= APEX_GRAVITY_MULT
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)


func _move() -> void:
	move_and_slide()


# --------------------------------------------------------------------------
# Pounce
# --------------------------------------------------------------------------

func try_pounce() -> bool:
	if state != State.NORMAL or not combat.pounce_ready():
		return false
	if not is_on_floor() and not air_pounce_available and coyote <= 0.0:
		return false
	if not is_on_floor():
		air_pounce_available = false
	var dir := Vector2(facing, 0)
	if input_enabled and Input.is_action_pressed("move_up"):
		dir = Vector2(facing * 0.8, -0.6).normalized()
	state = State.POUNCE
	combat.start_pounce(dir)
	stats["pounces"] += 1
	return true


func _process_pounce(delta: float) -> void:
	if not combat.update_pounce(delta):
		state = State.NORMAL
		velocity.x *= 0.55
		velocity.y = minf(velocity.y * 0.4, 0.0)
		return
	move_and_slide()
	if is_on_wall():
		combat.end_pounce()
		state = State.NORMAL
		velocity.x = 0.0


## Called by combat when the pounce connects with an enemy: hop back a little.
func pounce_bounce() -> void:
	state = State.NORMAL
	velocity = Vector2(-facing * 70.0, -200.0)
	air_pounce_available = true


# --------------------------------------------------------------------------
# Damage, healing, death
# --------------------------------------------------------------------------

func is_invulnerable() -> bool:
	return invuln > 0.0 or state == State.DEAD or combat.pounce_invulnerable()


## Damage in half-hearts. Returns true if the hit landed.
func hurt(amount: int, source_pos: Vector2, ignore_difficulty := false) -> bool:
	if state == State.DEAD or invuln > 0.0:
		return false
	if combat.pounce_invulnerable():
		return false
	var dmg := amount if ignore_difficulty else Settings.incoming_damage(amount)
	var dir := signf(global_position.x - source_pos.x)
	if dir == 0.0:
		dir = -facing
	if shield > 0:
		shield -= 1
		shield_changed.emit(shield)
		invuln = 0.6
		Audio.play("shield")
		if level:
			Fx.burst(level, global_position + Vector2(0, -8), Color(0.6, 0.8, 1.0))
		velocity = Vector2(dir * KNOCKBACK.x * 0.6, -120)
		return true
	hp = maxi(hp - dmg, 0)
	hp_changed.emit(hp, max_hp)
	Audio.play("hurt")
	if level and level.has_method("shake"):
		level.shake(4.0, 0.2)
	if hp <= 0 and Progress.has_blessing("ninth") and not ninth_life_used:
		ninth_life_used = true
		hp = 4
		hp_changed.emit(hp, max_hp)
		if level and level.has_method("toast"):
			level.toast("Ninth Life saved you!")
	if hp <= 0:
		die()
		return true
	combat.cancel()
	state = State.HURT
	hurt_timer = HURT_TIME
	invuln = INVULN_TIME
	velocity = Vector2(dir * KNOCKBACK.x, KNOCKBACK.y)
	return true


func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 300 * delta)
	velocity.y = minf(velocity.y + GRAVITY_DOWN * delta, MAX_FALL)
	move_and_slide()
	if hurt_timer <= 0.0:
		state = State.NORMAL


## Spikes, lava and pits: lose health, then return to the last safe ground.
func hazard_hit() -> void:
	if state == State.DEAD:
		return
	if invuln > 0.0 and state == State.HURT:
		return
	var dmg := Settings.incoming_damage(Progress.hazard_damage())
	invuln = 0.0
	if shield > 0:
		shield -= 1
		shield_changed.emit(shield)
		Audio.play("shield")
	else:
		hp = maxi(hp - dmg, 0)
		hp_changed.emit(hp, max_hp)
		Audio.play("hurt")
	if hp <= 0:
		die()
		return
	combat.cancel()
	global_position = safe_position
	velocity = Vector2.ZERO
	state = State.HURT
	hurt_timer = 0.35
	invuln = INVULN_TIME
	if level and level.has_method("on_player_hazard_reset"):
		level.on_player_hazard_reset()


func heal(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
	healed.emit(amount)


func is_dead() -> bool:
	return state == State.DEAD


func is_controllable() -> bool:
	return state == State.NORMAL


func spring_launch() -> void:
	velocity.y = -SPRING_VELOCITY
	air_pounce_available = true
	coyote = 0.0


func add_shield(n := 1) -> void:
	shield += n
	shield_changed.emit(shield)


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	combat.cancel()
	hp = 0
	velocity = Vector2(0, -120)
	hp_changed.emit(hp, max_hp)
	Audio.play("death")
	died.emit()


func respawn_at(pos: Vector2) -> void:
	global_position = pos
	safe_position = pos
	velocity = Vector2.ZERO
	state = State.NORMAL
	combat.cancel()
	combat.reset_cooldowns()
	hurt_timer = 0.0
	jump_buffer = 0.0
	coyote = 0.0
	air_pounce_available = true
	invuln = INVULN_TIME
	input_enabled = true
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield)
	sprite.modulate = Color.WHITE
	respawned.emit()


func _check_fall_out() -> void:
	if level and level.has_method("is_below_map") and level.is_below_map(global_position):
		if state == State.DEAD:
			velocity = Vector2.ZERO
			return
		hazard_hit()


func _update_safe_position(delta: float) -> void:
	if state != State.NORMAL or not is_on_floor():
		_safe_timer = 0.0
		return
	if level == null or not level.has_method("is_safe_ground"):
		safe_position = global_position
		return
	if level.is_safe_ground(global_position):
		_safe_timer += delta
		if _safe_timer > 0.15:
			safe_position = global_position
	else:
		_safe_timer = 0.0


# --------------------------------------------------------------------------
# Interaction
# --------------------------------------------------------------------------

func add_interactable(n: Node) -> void:
	if not interactables.has(n):
		interactables.append(n)


func remove_interactable(n: Node) -> void:
	interactables.erase(n)


func _interact() -> void:
	var best: Node = null
	var best_d := INF
	for n in interactables:
		if not is_instance_valid(n) or not n.has_method("interact"):
			continue
		if n.has_method("can_interact") and not n.can_interact():
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	if best:
		best.interact(self)


# --------------------------------------------------------------------------
# Visuals
# --------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	sprite.flip_h = facing < 0
	var anim := "idle"
	match state:
		State.DEAD:
			anim = "death"
		State.HURT:
			anim = "hurt"
		State.POUNCE:
			anim = "pounce"
		_:
			if combat.is_attacking():
				anim = "attack"
			elif not is_on_floor():
				anim = "jump" if velocity.y < 0 else "fall"
			elif absf(velocity.x) > 12.0:
				anim = "run"
	if sprite.animation != anim:
		sprite.play(anim)
	if anim == "run":
		sprite.speed_scale = clampf(absf(velocity.x) / RUN_SPEED, 0.5, 1.4)
	else:
		sprite.speed_scale = 1.0
	# Invulnerability blink.
	if invuln > 0.0 and state != State.DEAD:
		_flash_timer += delta
		sprite.modulate.a = 0.35 if int(_flash_timer * 15) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	var show_prompt := false
	for n in interactables:
		if is_instance_valid(n) and (not n.has_method("can_interact") or n.can_interact()):
			show_prompt = true
	_prompt.visible = show_prompt and state == State.NORMAL
