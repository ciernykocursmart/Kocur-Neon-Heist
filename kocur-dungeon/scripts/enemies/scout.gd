extends "res://scripts/enemies/enemy_base.gd"
## White Scout: patrols, chases, and lunges with a dagger after a short tell.


func _configure() -> void:
	sheet = "scout"
	display_name = "White Scout"
	max_hp = 4
	speed = 35.0
	chase_speed = 72.0
	attack_damage = 2
	detect_range = 140.0


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
			_chase(18.0)
			if absf(dx_to_player()) < 34.0 and absf(dy_to_player()) < 24.0:
				_set_state(S.WINDUP)
		S.WINDUP:
			velocity.x = 0.0
			face_player()
			if state_t >= 0.38:
				_set_state(S.ATTACK)
				begin_attack()
				velocity.x = facing * (150.0 if ground_ahead(facing, 10) else 0.0)
				Audio.play("swing", -4.0)
		S.ATTACK:
			if not ground_ahead(facing):
				velocity.x = 0.0
			if state_t >= 0.18:
				attack_active = false
				velocity.x = 0.0
				_set_state(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0, 20)
			if state_t >= 0.55:
				_set_state(S.CHASE)
