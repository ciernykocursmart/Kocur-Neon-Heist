extends "res://scripts/enemies/enemy_base.gd"
## Shared guardian logic: arena bounds, phases with invulnerable transitions,
## action scheduling, vulnerability windows and fight reset on retry.
## Every dangerous move is announced by a warning icon, a flash and a sound.

signal boss_defeated
signal phase_changed(phase: int)

const RuneScript := preload("res://scripts/enemies/rune.gd")

var phase := 1
var phase_thresholds: Array[float] = [0.5]  ## hp ratios where the next phase begins
var fighting := false
var action := "idle"
var _transition_t := 0.0
var vulnerable := false
var armor := 1.0  ## damage multiplier while not vulnerable
var vulnerable_mult := 1.5
var arena_left := 0.0
var arena_right := 640.0
var floor_y := 0.0
var ceiling_y := 0.0
var speed_mult := 1.0
var boss_anim := ""  ## Animation chosen by the current action ("" = walk/idle).
var _minions: Array[Node] = []
var telegraphs := 0  ## How many attacks were announced with a warning (tests).


func _ready() -> void:
	super._ready()
	hitbox.collision_mask = 2
	_compute_arena()
	if level:
		var c: Vector2i = level.grid.cell_of(global_position + Vector2(0, -4))
		floor_y = (c.y + 1) * 16.0
		var y := c.y
		while y > 0 and not level.grid.is_solid(c.x, y):
			y -= 1
		ceiling_y = (y + 1) * 16.0


func _compute_arena() -> void:
	if level == null:
		return
	var c: Vector2i = level.grid.cell_of(global_position + Vector2(0, -8))
	var x := c.x
	while x > 0 and not level.grid.is_solid(x - 1, c.y) and not level.grid.ch(x - 1, c.y) == "]":
		x -= 1
	arena_left = x * 16.0 + 4.0
	x = c.x
	while x < level.grid.width - 1 and not level.grid.is_solid(x + 1, c.y) and not level.grid.ch(x + 1, c.y) == "]":
		x += 1
	arena_right = (x + 1) * 16.0 - 4.0


func start_fight() -> void:
	fighting = true
	_set_action("intro")


func phase_name() -> String:
	return "" if phase_thresholds.is_empty() else "Phase %d" % phase


func _set_action(a: String, anim := "") -> void:
	action = a
	state_t = 0.0
	attack_active = false
	vulnerable = false
	boss_anim = anim
	state = S.WINDUP if anim == "windup" else (S.STUNNED if anim == "stunned" else S.PATROL)


func _anim_for_state() -> String:
	if state == S.DEAD:
		return "death"
	if boss_anim != "":
		return boss_anim
	return "walk" if absf(velocity.x) > 5.0 else "idle"


## Override: choose the next move.
func _choose_action() -> void:
	_set_action("idle")


func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		super._physics_process(delta)
		return
	if not fighting:
		velocity.x = 0.0
		face_player()
		velocity.y = minf(velocity.y + gravity * delta, 400)
		move_and_slide()
		_update_visual(delta)
		return
	if _transition_t > 0.0:
		_transition_t -= delta
		velocity.x = 0.0
		velocity.y = minf(velocity.y + gravity * delta, 400)
		move_and_slide()
		state_t += delta
		_update_visual(delta)
		sprite.modulate = Color(1.6, 1.6, 2.0) if int(_transition_t * 12) % 2 == 0 else phase_tint()
		return
	super._physics_process(delta)
	global_position.x = clampf(global_position.x, arena_left + body_size.x / 2, arena_right - body_size.x / 2)


func _think(delta: float) -> void:
	if action == "intro":
		velocity.x = 0.0
		face_player()
		if state_t > 1.0:
			_choose_action()
		return
	_run_action(delta)


## Override in bosses.
func _run_action(_delta: float) -> void:
	if state_t > 1.0:
		_choose_action()


func phase_tint() -> Color:
	return Color.WHITE


func _modify_damage(amount: int, _from: Vector2, _kind: String) -> int:
	if not fighting or _transition_t > 0.0:
		return 0
	if vulnerable:
		return int(ceil(amount * vulnerable_mult))
	return maxi(1, int(ceil(amount * armor)))


func take_hit(amount: int, from: Vector2, kind := "claw") -> bool:
	if state == S.DEAD:
		return false
	var dmg := _modify_damage(amount, from, kind)
	if dmg <= 0:
		if fighting:
			Audio.play("shield", -10.0)
		return false
	hp -= dmg
	_flash = 0.1
	Fx.float_text(level, global_position + Vector2(randf_range(-10, 10), -body_size.y - 8), str(dmg),
		Color(1, 0.6, 0.4) if vulnerable else Color(1, 0.9, 0.6))
	Audio.play("enemy_hurt", -2.0)
	if hp <= 0:
		hp = 0
		die()
		return true
	var ratio := float(hp) / float(max_hp)
	if phase - 1 < phase_thresholds.size() and ratio <= phase_thresholds[phase - 1]:
		_enter_phase(phase + 1)
	return true


func _enter_phase(p: int) -> void:
	phase = p
	_transition_t = 1.6
	_set_action("intro")
	state_t = 0.0
	if level:
		level.clear_projectiles()
		level.shake(6.0, 0.6)
		level.toast(phase_message(p), Color(1, 0.7, 0.7))
	Transition.flash(Color(1, 1, 1, 0.35), 0.3)
	Audio.play("phase")
	Audio.play("boss_roar", -2.0)
	phase_changed.emit(p)
	_on_phase(p)


func phase_message(p: int) -> String:
	return "%s grows furious!" % display_name if p == 2 else "%s unleashes everything!" % display_name


func _on_phase(_p: int) -> void:
	pass


func die() -> void:
	if state == S.DEAD:
		return
	fighting = false
	for m in _minions:
		if is_instance_valid(m) and m.has_method("die"):
			m.die()
	_minions.clear()
	_set_state(S.DEAD)
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	sprite.play("death")
	Audio.play("boss_roar")
	Audio.play("slam")
	Progress.add_stat("enemies")
	if level:
		level.shake(8.0, 0.8)
		level.clear_projectiles()
		for i in 5:
			Fx.poof(level, global_position + Vector2(randf_range(-20, 20), randf_range(-40, 0)), 1.5)
	Transition.flash(Color(1, 1, 1, 0.6), 0.6)
	boss_defeated.emit()
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.0)


func reset_fight() -> void:
	if state == S.DEAD:
		return
	fighting = false
	phase = 1
	hp = max_hp
	_transition_t = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	speed_mult = 1.0
	for m in _minions:
		if is_instance_valid(m):
			m.queue_free()
	_minions.clear()
	_set_state(S.PATROL)
	_set_action("idle")
	sprite.modulate = Color.WHITE
	_on_reset()


func _on_reset() -> void:
	pass


func reset_to_spawn() -> void:
	pass  # Bosses reset through reset_fight().


# --------------------------------------------------------------------------
# Helpers for patterns
# --------------------------------------------------------------------------

func warn(offset := Vector2(0, -60), time := 0.6) -> void:
	telegraphs += 1
	Fx.warning(level, global_position + offset, time)
	Audio.play("warn", -4.0)


func spawn_rune(x: float, warn_time := 1.0, color := Color(1, 0.5, 0.2), dmg := 2) -> void:
	var r := RuneScript.new()
	r.level = level
	r.warn_time = warn_time
	r.color = color
	r.damage = dmg
	r.position = Vector2(clampf(x, arena_left + 8, arena_right - 8), floor_y)
	level.add_projectile(r)


func shockwaves(speed := 140.0, dmg := 2) -> void:
	for d in [-1, 1]:
		shoot("shockwave", Vector2(global_position.x + d * (body_size.x / 2 + 8), floor_y), Vector2(d * speed, 0), dmg,
			3.0, 0.0, true)


func player_x() -> float:
	var p := player()
	return p.global_position.x if p else global_position.x


func arena_center() -> float:
	return (arena_left + arena_right) * 0.5


func spawn_minion(script_path: String, x: float) -> void:
	var e: Node = load(script_path).new()
	e.level = level
	e.position = Vector2(x, floor_y)
	level.enemies_root.add_child(e)
	_minions.append(e)
	Fx.poof(level, e.position + Vector2(0, -12))


func _update_visual(delta: float) -> void:
	super._update_visual(delta)
	if _flash <= 0.0 and state != S.DEAD:
		if action != "intro" and state == S.WINDUP:
			pass
		elif vulnerable:
			sprite.modulate = Color(0.85, 0.85, 1.25)
		else:
			sprite.modulate = phase_tint()
