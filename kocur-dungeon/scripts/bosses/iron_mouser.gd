extends "res://scripts/bosses/boss_base.gd"
## Boss 1 - The Iron Mouser. An armoured guardian that teaches the core
## rhythm: watch the tell, dodge, then punish while it is stuck.
##  - Slam: raises its gauntlet (tell), smashes the floor, sends shockwaves
##    both ways (jump them) and is stuck for a long, vulnerable moment.
##  - Charge: crouches (tell), rushes across the arena; hitting the wall
##    leaves it dazed.
##  - Phase 2: Leap - jumps at the cat and lands with shockwaves.


func _configure() -> void:
	sheet = "boss_mouser"
	display_name = "The Iron Mouser"
	max_hp = 44
	speed = 40.0
	chase_speed = 55.0
	contact_damage = 2
	attack_damage = 3
	knock_resist = 1.0
	poise = true
	armor = 0.5
	vulnerable_mult = 2.0
	body_size = Vector2(28, 44)
	sprite_offset = Vector2(0, -30)
	attack_box_size = Vector2(54, 30)
	attack_box_offset = Vector2(22, -14)


func _choose_action() -> void:
	face_player()
	var d := absf(dx_to_player())
	if phase >= 2 and randf() < 0.35:
		_set_action("leap_windup", "windup")
		warn()
	elif d > 130.0 and randf() < 0.6:
		_set_action("charge_windup", "windup")
		warn()
	else:
		_set_action("approach")


func _run_action(_delta: float) -> void:
	var tempo := 0.8 if phase >= 2 else 1.0
	match action:
		"approach":
			face_player()
			velocity.x = facing * chase_speed * (1.2 if phase >= 2 else 1.0)
			if absf(dx_to_player()) < 56.0 or state_t > 1.6:
				velocity.x = 0.0
				_set_action("slam_windup", "windup")
				warn()
		"slam_windup":
			velocity.x = 0.0
			if state_t > 0.75 * tempo:
				_set_action("slam", "attack")
				begin_attack()
				Audio.play("slam")
				level.shake(6.0, 0.35)
				shockwaves(150.0)
		"slam":
			if state_t > 0.2:
				attack_active = false
				_set_action("stuck", "stunned")
				vulnerable = true
		"stuck":
			vulnerable = true
			if state_t > 1.5 * tempo:
				_set_action("recover")
		"charge_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.65 * tempo:
				_set_action("charge", "walk")
				begin_attack()
		"charge":
			velocity.x = facing * 230.0
			_attack_hit = false if state_t < 0.05 else _attack_hit
			var at_wall := (facing > 0 and global_position.x >= arena_right - body_size.x / 2 - 2) or \
				(facing < 0 and global_position.x <= arena_left + body_size.x / 2 + 2) or wall_ahead(facing)
			if at_wall:
				velocity.x = 0.0
				Audio.play("slam")
				level.shake(7.0, 0.4)
				_set_action("dazed", "stunned")
				vulnerable = true
			elif state_t > 2.5:
				_set_action("recover")
		"dazed":
			velocity.x = 0.0
			vulnerable = true
			if state_t > 1.7 * tempo:
				_set_action("recover")
		"leap_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.55 * tempo:
				var target := clampf(player_x(), arena_left + 20, arena_right - 20)
				velocity = Vector2((target - global_position.x) / 0.85, -380.0)
				_set_action("leap", "attack")
		"leap":
			if state_t > 0.15 and is_on_floor():
				velocity.x = 0.0
				Audio.play("slam")
				level.shake(6.0, 0.35)
				shockwaves(160.0)
				_set_action("stuck", "stunned")
				vulnerable = true
			elif state_t > 2.0:
				_set_action("recover")
		"recover":
			velocity.x = 0.0
			if state_t > 0.6 * tempo:
				_choose_action()
		_:
			if state_t > 0.8:
				_choose_action()


func current_contact_damage() -> int:
	return 3 if action == "charge" else contact_damage


func phase_tint() -> Color:
	return Color(1.15, 0.95, 0.9) if phase >= 2 else Color.WHITE
