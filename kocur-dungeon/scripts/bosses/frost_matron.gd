extends "res://scripts/bosses/boss_base.gd"
## Boss 3 - The Frost Matron. A crypt witch who keeps her distance.
##  - Blink: vanishes in snow and reappears elsewhere in the hall.
##  - Shard fan: five ice shards fanned at the cat (claw them away).
##  - Icicle rain: sparkles mark the ceiling, icicles drop a moment later.
##  - Phase 2: Frost nova - a ring of shards from her position; casts faster.
## She is vulnerable while recovering from each spell.


func _configure() -> void:
	sheet = "boss_frost"
	display_name = "The Frost Matron"
	max_hp = 56
	speed = 30.0
	contact_damage = 2
	attack_damage = 2
	knock_resist = 1.0
	poise = true
	armor = 0.75
	vulnerable_mult = 1.5
	body_size = Vector2(26, 44)
	sprite_offset = Vector2(0, -30)


func _choose_action() -> void:
	face_player()
	var r := randf()
	if absf(dx_to_player()) < 70.0 and randf() < 0.7:
		_set_action("blink", "cast")
	elif r < 0.4:
		_set_action("shards_windup", "cast")
		warn(Vector2(0, -60), 0.6)
	elif phase >= 2 and r < 0.65:
		_set_action("nova_windup", "windup")
		warn(Vector2(0, -60), 0.7)
	else:
		_set_action("rain_windup", "cast")
		warn(Vector2(0, -60), 0.6)


func _run_action(_delta: float) -> void:
	var tempo := 0.8 if phase >= 2 else 1.0
	match action:
		"blink":
			velocity.x = 0.0
			if state_t > 0.3:
				Fx.poof(level, global_position + Vector2(0, -24), 1.4)
				Audio.play("ice")
				var px := player_x()
				var target := arena_left + 30.0 if px > arena_center() else arena_right - 30.0
				global_position.x = target
				Fx.poof(level, global_position + Vector2(0, -24), 1.4)
				face_player()
				_set_action("shards_windup", "cast")
		"shards_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.7 * tempo:
				var from := global_position + Vector2(facing * 14, -36)
				var p := player()
				var base := ((p.global_position + Vector2(0, -8)) - from).normalized() if p else Vector2(facing, 0)
				for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
					shoot("ice_shard", from, base.rotated(a) * 140.0, 2, 3.0)
				Audio.play("ice")
				_set_action("recover", "idle")
				vulnerable = true
		"rain_windup":
			velocity.x = 0.0
			if state_t > 0.5:
				var px := player_x()
				for i in 5:
					var x := clampf(px + (i - 2) * 40.0 + randf_range(-8, 8), arena_left + 12, arena_right - 12)
					_drop_icicle(x, 0.9 + i * 0.12)
				Audio.play("ice")
				_set_action("recover", "cast")
				vulnerable = true
		"nova_windup":
			velocity.x = 0.0
			if state_t > 0.75 * tempo:
				var from := global_position + Vector2(0, -26)
				for i in 10:
					var a := PI + i * PI / 9.0
					shoot("ice_shard", from, Vector2.RIGHT.rotated(a) * 110.0, 2, 3.0)
				Audio.play("ice")
				_set_action("recover", "stunned")
				vulnerable = true
		"recover":
			vulnerable = true
			velocity.x = 0.0
			if state_t > 1.2 * tempo:
				_choose_action()
		_:
			if state_t > 0.8:
				_choose_action()


func _drop_icicle(x: float, delay: float) -> void:
	# Sparkle warning on the ceiling, then a falling shard.
	var mark := Node2D.new()
	level.fx_root.add_child(mark)
	mark.global_position = Vector2(x, ceiling_y + 6)
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/icicle.png")
	mark.add_child(spr)
	var tw := mark.create_tween()
	tw.tween_property(spr, "modulate", Color(0.6, 0.9, 1.0, 0.4), delay * 0.5)
	tw.tween_property(spr, "modulate", Color(1, 1, 1, 1), delay * 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and fighting and level:
			shoot("ice_shard", Vector2(x, ceiling_y + 8), Vector2(0, 60), 2, 3.0, 700.0)
		mark.queue_free())


func phase_tint() -> Color:
	return Color(0.8, 0.95, 1.3) if phase >= 2 else Color.WHITE
