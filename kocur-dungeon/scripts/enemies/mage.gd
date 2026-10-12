extends "res://scripts/enemies/enemy_base.gd"
## White Mage: alternates between a slow three-orb volley and a rune trap
## that marks the floor beneath the cat before erupting. Blinks away when
## crowded (with a cooldown), leaving a puff of smoke.

const RuneScript := preload("res://scripts/enemies/rune.gd")

var _next_attack := 0
var _blink_cd := 0.0


func _configure() -> void:
	sheet = "mage"
	display_name = "White Mage"
	max_hp = 6
	speed = 22.0
	chase_speed = 40.0
	attack_damage = 2
	detect_range = 200.0


func _think(delta: float) -> void:
	_blink_cd = maxf(_blink_cd - delta, 0.0)
	match state:
		S.PATROL:
			_patrol()
			if can_see_player():
				_set_state(S.CHASE)
		S.CHASE:
			if not can_see_player(1.3):
				_set_state(S.PATROL)
				return
			face_player()
			velocity.x = 0.0
			if absf(dx_to_player()) < 40.0 and _blink_cd <= 0.0 and _try_blink():
				return
			if state_t > 0.5:
				_set_state(S.WINDUP)
				Audio.play("magic", -8.0)
		S.WINDUP:
			velocity.x = 0.0
			face_player()
			if state_t >= 0.8:
				_cast()
				_set_state(S.ATTACK)
		S.ATTACK:
			if state_t >= 0.35:
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t >= 1.3:
				_set_state(S.CHASE)


func _cast() -> void:
	var from := global_position + Vector2(facing * 10, -24)
	if _next_attack == 0:
		var p := player()
		var base := ((p.global_position + Vector2(0, -8)) - from).normalized() if p else Vector2(facing, 0)
		for a in [-0.35, 0.0, 0.35]:
			shoot("orb", from, base.rotated(a) * 85.0, attack_damage, 4.0)
		Audio.play("magic", -4.0)
	else:
		var p := player()
		if p and level:
			var rune := RuneScript.new()
			rune.level = level
			rune.position = level.floor_below(p.global_position)
			level.add_projectile(rune)
	_next_attack = 1 - _next_attack


func _try_blink() -> bool:
	if level == null:
		return false
	for dist in [96.0, -96.0, 64.0, -64.0]:
		var target := global_position + Vector2(-facing * dist, 0)
		var c: Vector2i = level.grid.cell_of(target + Vector2(0, -8))
		var below: Vector2i = level.grid.cell_of(target + Vector2(0, 4))
		if not level.grid.is_solid(c.x, c.y) and not level.grid.is_solid(c.x, c.y - 1) \
				and (level.grid.is_solid(below.x, below.y) or level.grid.is_oneway(below.x, below.y)) \
				and line_clear(global_position + Vector2(0, -10), target + Vector2(0, -10)):
			Fx.poof(level, global_position + Vector2(0, -12))
			global_position = Vector2(target.x, below.y * 16)
			Fx.poof(level, global_position + Vector2(0, -12))
			Audio.play("magic", -6.0)
			_blink_cd = 3.5
			_set_state(S.RECOVER)
			return true
	_blink_cd = 1.0
	return false
