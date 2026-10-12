extends "res://scripts/enemies/enemy_base.gd"
## White Guard: tough, shielded spearman. Blocks claws from the front while
## standing ready; strike from behind, pounce through the shield, or punish
## the long recovery after his telegraphed thrust.

var _blocked_flash := 0.0


func _configure() -> void:
	sheet = "guard"
	display_name = "White Guard"
	max_hp = 10
	speed = 28.0
	chase_speed = 50.0
	attack_damage = 3
	detect_range = 130.0
	knock_resist = 0.6
	poise = true
	attack_box_size = Vector2(40, 14)
	attack_box_offset = Vector2(22, -12)


func _modify_damage(amount: int, from: Vector2, kind: String) -> int:
	var from_front := signf(from.x - global_position.x) == float(facing)
	if kind == "claw" and from_front and state in [S.PATROL, S.CHASE, S.WINDUP]:
		Audio.play("shield", -6.0)
		Fx.spark(level, global_position + Vector2(facing * 10, -12))
		Fx.float_text(level, global_position + Vector2(0, -30), "BLOCK", Color(0.7, 0.8, 1.0))
		var p := player()
		if p:
			p.velocity.x = signf(p.global_position.x - global_position.x) * 140.0
		return 0
	return amount


func _think(_delta: float) -> void:
	match state:
		S.PATROL:
			_patrol()
			if can_see_player():
				_set_state(S.CHASE)
		S.CHASE:
			if not can_see_player(1.4):
				_set_state(S.PATROL)
				return
			_chase(24.0)
			if absf(dx_to_player()) < 46.0 and absf(dy_to_player()) < 24.0:
				_set_state(S.WINDUP)
				Fx.warning(level, global_position + Vector2(0, -42), 0.6)
				Audio.play("warn", -6.0)
		S.WINDUP:
			velocity.x = 0.0
			face_player()
			if state_t >= 0.65:
				_set_state(S.ATTACK)
				begin_attack()
				velocity.x = facing * (60.0 if ground_ahead(facing, 8) else 0.0)
				Audio.play("swing")
		S.ATTACK:
			if state_t >= 0.22:
				attack_active = false
				velocity.x = 0.0
				_set_state(S.RECOVER)
		S.RECOVER:
			velocity.x = 0.0
			if state_t >= 0.9:
				_set_state(S.CHASE)


func _anim_for_state() -> String:
	if state == S.RECOVER:
		return "hurt"
	return super._anim_for_state()
