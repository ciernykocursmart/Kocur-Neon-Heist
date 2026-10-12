extends "res://scripts/bosses/boss_base.gd"
## Boss 2 - The Ember Guardian. A forge golem-cat with a burning hammer.
##  - Hammer smash: long tell, sends fire waves both ways, then the hammer
##    is stuck in the floor (vulnerable).
##  - Fire volley: three lobbed fireballs aimed around the cat.
##  - Phase 2 (arena control): marks the floor with glowing cracks that erupt
##    into fire pillars a second later, and smashes faster.

const FIRE := Color(1.0, 0.55, 0.15)


func _configure() -> void:
	sheet = "boss_ember"
	display_name = "The Ember Guardian"
	max_hp = 60
	speed = 32.0
	chase_speed = 42.0
	contact_damage = 2
	attack_damage = 3
	knock_resist = 1.0
	poise = true
	armor = 0.6
	vulnerable_mult = 1.75
	body_size = Vector2(30, 46)
	sprite_offset = Vector2(0, -30)
	attack_box_size = Vector2(56, 28)
	attack_box_offset = Vector2(24, -14)


func _choose_action() -> void:
	face_player()
	var r := randf()
	if phase >= 2 and r < 0.35:
		_set_action("erupt_windup", "cast")
		warn(Vector2(0, -64), 0.7)
	elif r < 0.6 or absf(dx_to_player()) > 150.0:
		_set_action("volley_windup", "cast")
		warn(Vector2(0, -64), 0.6)
	else:
		_set_action("approach")


func _run_action(_delta: float) -> void:
	var tempo := 0.8 if phase >= 2 else 1.0
	match action:
		"approach":
			face_player()
			velocity.x = facing * chase_speed
			if absf(dx_to_player()) < 60.0 or state_t > 1.8:
				velocity.x = 0.0
				_set_action("smash_windup", "windup")
				warn()
		"smash_windup":
			velocity.x = 0.0
			if state_t > 0.85 * tempo:
				_set_action("smash", "attack")
				begin_attack()
				Audio.play("slam")
				Audio.play("fire", -2.0)
				level.shake(6.0, 0.4)
				for d in [-1, 1]:
					var w := shoot("shockwave", Vector2(global_position.x + d * 24, floor_y), Vector2(d * 130.0, 0), 2, 3.0, 0.0, true)
					if w:
						w.modulate = Color(1.0, 0.6, 0.3)
		"smash":
			if state_t > 0.25:
				attack_active = false
				_set_action("stuck", "stunned")
				vulnerable = true
		"stuck":
			vulnerable = true
			if state_t > 1.3 * tempo:
				_set_action("recover")
		"volley_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.7 * tempo:
				_set_action("volley", "cast")
				var from := global_position + Vector2(facing * 16, -50)
				var px := player_x()
				for off: float in [-40.0, 0.0, 40.0]:
					var tx: float = px + off
					var t := 1.1
					var vx: float = (tx - from.x) / t
					var vy: float = (floor_y - 6 - from.y - 0.5 * 320.0 * t * t) / t
					shoot("fireball", from, Vector2(vx, vy), 2, 3.0, 320.0)
				Audio.play("fire")
		"volley":
			if state_t > 0.8 * tempo:
				_set_action("recover")
		"erupt_windup":
			velocity.x = 0.0
			if state_t > 0.5:
				_set_action("erupt", "cast")
				var px := player_x()
				var xs := [px, px - 64.0, px + 64.0, arena_left + randf() * (arena_right - arena_left)]
				for x in xs:
					spawn_rune(x, 1.0, FIRE, 2)
				Audio.play("fire", -4.0)
		"erupt":
			if state_t > 1.0:
				_set_action("recover")
				vulnerable = true
		"recover":
			velocity.x = 0.0
			vulnerable = phase >= 2 and state_t < 0.5
			if state_t > 0.7 * tempo:
				_choose_action()
		_:
			if state_t > 0.8:
				_choose_action()


func phase_tint() -> Color:
	return Color(1.3, 0.85, 0.7) if phase >= 2 else Color.WHITE
