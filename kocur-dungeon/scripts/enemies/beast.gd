extends "res://scripts/enemies/enemy_base.gd"
## White Beast: a huge, slow brute. Roars before a long charge; slamming into
## a wall leaves it stunned and vulnerable. Up close it stomps, sending
## ground shockwaves both ways (jump over them).

var _charging := false


func _configure() -> void:
	sheet = "beast"
	display_name = "White Beast"
	max_hp = 18
	speed = 24.0
	chase_speed = 40.0
	contact_damage = 2
	attack_damage = 3
	detect_range = 170.0
	knock_resist = 0.9
	poise = true
	hurt_stun = 0.15
	body_size = Vector2(28, 26)
	sprite_offset = Vector2(2, -22)
	attack_box_size = Vector2(36, 22)
	attack_box_offset = Vector2(16, -12)


func current_contact_damage() -> int:
	return 4 if _charging else contact_damage


func _modify_damage(amount: int, _from: Vector2, _kind: String) -> int:
	if state == S.STUNNED:
		return int(ceil(amount * 1.5))
	return amount


func _think(_delta: float) -> void:
	match state:
		S.PATROL:
			_charging = false
			_patrol()
			if can_see_player():
				_set_state(S.CHASE)
		S.CHASE:
			if not can_see_player(1.3):
				_set_state(S.PATROL)
				return
			_chase(30.0)
			if state_t > 0.6:
				if absf(dx_to_player()) < 44.0:
					_set_state(S.WINDUP)
					set_meta("move", "stomp")
				elif absf(dy_to_player()) < 30.0:
					_set_state(S.WINDUP)
					set_meta("move", "charge")
				if state == S.WINDUP:
					Audio.play("roar", -4.0)
					Fx.warning(level, global_position + Vector2(0, -44), 0.7)
		S.WINDUP:
			velocity.x = 0.0
			face_player()
			if state_t >= 0.8:
				if get_meta("move", "charge") == "stomp":
					_stomp()
					_set_state(S.RECOVER)
				else:
					_charging = true
					_set_state(S.ATTACK)
					begin_attack()
		S.ATTACK:
			# Charge.
			velocity.x = facing * 200.0
			if wall_ahead(facing):
				_charging = false
				velocity.x = 0.0
				_set_state(S.STUNNED)
				Audio.play("slam")
				if level:
					level.shake(5.0, 0.3)
				return
			if not ground_ahead(facing, 6) or state_t > 1.4:
				_charging = false
				velocity.x = 0.0
				_set_state(S.RECOVER)
		S.STUNNED:
			velocity.x = 0.0
			if state_t >= 1.7:
				_set_state(S.CHASE)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0, 30)
			if state_t >= 1.0:
				_set_state(S.CHASE)


func _stomp() -> void:
	Audio.play("slam", -2.0)
	if level:
		level.shake(4.0, 0.25)
	for d in [-1, 1]:
		shoot("shockwave", global_position + Vector2(d * 18, 0), Vector2(d * 120.0, 0), 2, 2.0, 0.0, true)


func _anim_for_state() -> String:
	if state == S.ATTACK:
		return "attack"
	return super._anim_for_state()
