extends "res://scripts/bosses/boss_base.gd"
## Boss 4 - The Shadow Stalker. A white cat swallowed by the dark.
##  - Leap: its eyes flash, then it pounces in an arc at the cat; landing
##    leaves it open.
##  - Vanish & rush: fades out, reappears at the arena edge (eyes flash)
##    and dashes along the floor - jump over it.
##  - Phase 2: shadow orbs after vanishing, double leaps.

var _leaps := 0


func _configure() -> void:
	sheet = "boss_stalker"
	display_name = "The Shadow Stalker"
	max_hp = 60
	speed = 60.0
	chase_speed = 80.0
	contact_damage = 2
	attack_damage = 3
	knock_resist = 1.0
	poise = true
	armor = 0.7
	vulnerable_mult = 1.75
	body_size = Vector2(36, 26)
	sprite_offset = Vector2(0, -22)


func _choose_action() -> void:
	face_player()
	if randf() < 0.55:
		_leaps = 2 if phase >= 2 else 1
		_set_action("leap_windup", "windup")
		warn(Vector2(0, -44), 0.6)
	else:
		_set_action("vanish", "cast")


func _run_action(_delta: float) -> void:
	var tempo := 0.8 if phase >= 2 else 1.0
	match action:
		"leap_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.6 * tempo:
				var target := clampf(player_x(), arena_left + 24, arena_right - 24)
				velocity = Vector2((target - global_position.x) / 0.75, -330.0)
				_set_action("leap", "attack")
				Audio.play("pounce")
				begin_attack()
		"leap":
			if state_t > 0.15 and is_on_floor():
				velocity.x = 0.0
				level.shake(3.0, 0.2)
				_leaps -= 1
				if _leaps > 0:
					_set_action("leap_windup", "windup")
					state_t = 0.25
				else:
					_set_action("landed", "stunned")
					vulnerable = true
			elif state_t > 2.0:
				_set_action("recover")
		"landed":
			vulnerable = true
			velocity.x = 0.0
			if state_t > 1.2 * tempo:
				_set_action("recover")
		"vanish":
			velocity.x = 0.0
			sprite.modulate.a = maxf(0.0, 1.0 - state_t * 2.0)
			if state_t > 0.8:
				var from_left := player_x() > arena_center()
				global_position.x = arena_left + 26.0 if from_left else arena_right - 26.0
				facing = 1 if from_left else -1
				sprite.modulate.a = 1.0
				Fx.poof(level, global_position + Vector2(0, -16))
				_set_action("rush_windup", "windup")
				warn(Vector2(0, -44), 0.5)
				if phase >= 2:
					var from := global_position + Vector2(0, -30)
					var p := player()
					if p:
						var dir := ((p.global_position + Vector2(0, -8)) - from).normalized()
						for a in [-0.3, 0.0, 0.3]:
							shoot("shadow_orb", from, dir.rotated(a) * 75.0, 2, 5.0)
		"rush_windup":
			velocity.x = 0.0
			if state_t > 0.7 * tempo:
				_set_action("rush", "attack")
				begin_attack()
				Audio.play("roar", -4.0)
		"rush":
			velocity.x = facing * 240.0
			if (facing > 0 and global_position.x >= arena_right - 24) or (facing < 0 and global_position.x <= arena_left + 24):
				velocity.x = 0.0
				_set_action("landed", "stunned")
				vulnerable = true
		"recover":
			velocity.x = 0.0
			if state_t > 0.6 * tempo:
				_choose_action()
		_:
			if state_t > 0.8:
				_choose_action()


func current_contact_damage() -> int:
	return 3 if action in ["rush", "leap"] else contact_damage


func _modify_damage(amount: int, from: Vector2, kind: String) -> int:
	if action == "vanish":
		return 0
	return super._modify_damage(amount, from, kind)


func phase_tint() -> Color:
	return Color(1.2, 0.9, 1.3) if phase >= 2 else Color.WHITE
