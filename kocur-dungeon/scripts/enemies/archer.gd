extends "res://scripts/enemies/enemy_base.gd"
## White Archer: keeps her distance, draws her bow (clear wind-up), then
## looses an aimed arrow. Arrows can be clawed out of the air.


func _configure() -> void:
	sheet = "archer"
	display_name = "White Archer"
	max_hp = 4
	speed = 30.0
	chase_speed = 55.0
	attack_damage = 2
	detect_range = 220.0


func _think(_delta: float) -> void:
	match state:
		S.PATROL:
			_patrol()
			if can_see_player():
				_set_state(S.CHASE)
		S.CHASE:
			if not can_see_player(1.2):
				_set_state(S.PATROL)
				return
			face_player()
			var d := absf(dx_to_player())
			if d < 64.0 and can_move(-facing):
				_set_state(S.RETREAT)
			else:
				velocity.x = 0.0
				if state_t > 0.35:
					_set_state(S.WINDUP)
					Audio.play("warn", -10.0)
		S.RETREAT:
			face_player()
			if can_move(-facing):
				velocity.x = -facing * chase_speed
			else:
				velocity.x = 0.0
			if state_t > 0.6 or absf(dx_to_player()) > 110.0 or not can_move(-facing):
				velocity.x = 0.0
				_set_state(S.WINDUP)
		S.WINDUP:
			velocity.x = 0.0
			face_player()
			if state_t >= 0.75:
				var from := global_position + Vector2(facing * 10, -14)
				var p := player()
				var to: Vector2 = p.global_position + Vector2(0, -8) if p else from + Vector2(facing, 0)
				var dir := (to - from).normalized()
				if dir.x * facing < 0.3:
					dir = Vector2(facing, clampf(dir.y, -0.6, 0.6)).normalized()
				shoot("arrow", from, dir * 210.0, attack_damage, 3.0)
				Audio.play("arrow", -4.0)
				_set_state(S.ATTACK)
		S.ATTACK:
			if state_t >= 0.3:
				_set_state(S.RECOVER)
		S.RECOVER:
			velocity.x = 0.0
			if state_t >= 1.1:
				_set_state(S.CHASE)
