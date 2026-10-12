extends "res://scripts/bosses/boss_base.gd"
## Final boss - The Pale King. Three phases, each with its own identity.
##  Phase 1 (Royal Duel): scepter sweep and lunging dash strike.
##  Phase 2 (Court of Light): teleports, rings of pale orbs, light pillars,
##           and summons two White Scouts once.
##  Phase 3 (Pale Fury): faster tells, combos, crown shards falling from above.
## Every attack has a warning; every big attack leaves an opening.

const ScoutPath := "res://scripts/enemies/scout.gd"
const PALE := Color(0.9, 0.85, 1.0)


func _configure() -> void:
	sheet = "boss_king"
	display_name = "The Pale King"
	max_hp = 105
	speed = 50.0
	chase_speed = 70.0
	contact_damage = 2
	attack_damage = 3
	knock_resist = 1.0
	poise = true
	armor = 0.6
	vulnerable_mult = 1.75
	body_size = Vector2(28, 52)
	sprite_offset = Vector2(0, -38)
	attack_box_size = Vector2(60, 34)
	attack_box_offset = Vector2(24, -18)
	phase_thresholds = [0.66, 0.33]


func phase_name() -> String:
	return ["Royal Duel", "Court of Light", "Pale Fury"][phase - 1]


func phase_message(p: int) -> String:
	return "The Pale King: \"Enough! Witness the Court of Light!\"" if p == 2 else "The Pale King: \"I am the PALE FURY!\""


func _on_phase(p: int) -> void:
	if p == 2:
		spawn_minion(ScoutPath, arena_left + 30)
		spawn_minion(ScoutPath, arena_right - 30)


func _tempo() -> float:
	return [1.0, 0.9, 0.7][phase - 1]


func _choose_action() -> void:
	face_player()
	var r := randf()
	var d := absf(dx_to_player())
	match phase:
		1:
			if d > 110.0 or r < 0.35:
				_set_action("dash_windup", "windup")
				warn(Vector2(0, -70))
			else:
				_set_action("approach")
		2:
			if r < 0.3:
				_set_action("teleport", "cast")
			elif r < 0.6:
				_set_action("ring_windup", "cast")
				warn(Vector2(0, -70), 0.8)
			elif r < 0.8:
				_set_action("pillars_windup", "cast")
				warn(Vector2(0, -70), 0.7)
			else:
				_set_action("approach")
		_:
			if r < 0.25:
				_set_action("rain_windup", "cast")
				warn(Vector2(0, -70), 0.6)
			elif r < 0.5:
				_set_action("dash_windup", "windup")
				warn(Vector2(0, -70))
			elif r < 0.75:
				_set_action("ring_windup", "cast")
				warn(Vector2(0, -70), 0.7)
			else:
				_set_action("approach")


func _run_action(_delta: float) -> void:
	var tempo := _tempo()
	match action:
		"approach":
			face_player()
			velocity.x = facing * chase_speed * (1.3 if phase == 3 else 1.0)
			if absf(dx_to_player()) < 58.0 or state_t > 1.6:
				velocity.x = 0.0
				_set_action("sweep_windup", "windup")
				warn(Vector2(0, -70))
		"sweep_windup":
			velocity.x = 0.0
			if state_t > 0.7 * tempo:
				_set_action("sweep", "attack")
				begin_attack()
				Audio.play("swing")
		"sweep":
			if state_t > 0.25:
				attack_active = false
				if phase == 3 and randf() < 0.5:
					_set_action("dash_windup", "windup")
					state_t = 0.2
				else:
					_set_action("recover", "stunned")
					vulnerable = true
		"dash_windup":
			velocity.x = 0.0
			face_player()
			if state_t > 0.65 * tempo:
				_set_action("dash", "attack")
				begin_attack()
				Audio.play("pounce")
		"dash":
			velocity.x = facing * 260.0
			_attack_hit = _attack_hit and state_t > 0.02
			if state_t > 0.55 or (facing > 0 and global_position.x >= arena_right - 20) or \
					(facing < 0 and global_position.x <= arena_left + 20):
				velocity.x = 0.0
				_set_action("recover", "stunned")
				vulnerable = true
		"teleport":
			velocity.x = 0.0
			if state_t > 0.35:
				Fx.poof(level, global_position + Vector2(0, -30), 1.6)
				var px := player_x()
				global_position.x = arena_left + 40.0 if px > arena_center() else arena_right - 40.0
				Fx.poof(level, global_position + Vector2(0, -30), 1.6)
				Audio.play("magic")
				face_player()
				_set_action("ring_windup", "cast")
				warn(Vector2(0, -70), 0.6)
		"ring_windup":
			velocity.x = 0.0
			if state_t > 0.85 * tempo:
				var n := 10 if phase == 2 else 14
				var from := global_position + Vector2(0, -36)
				var off := randf() * TAU
				for i in n:
					shoot("pale_orb", from, Vector2.RIGHT.rotated(off + i * TAU / n) * 70.0, 2, 5.0)
				Audio.play("magic")
				_set_action("recover", "cast")
				vulnerable = true
		"pillars_windup":
			velocity.x = 0.0
			if state_t > 0.5:
				var px := player_x()
				var xs := [px, px - 72.0, px + 72.0, arena_center()]
				for x in xs:
					spawn_rune(x, 1.0, PALE, 3)
				_set_action("recover", "cast")
				vulnerable = true
		"rain_windup":
			velocity.x = 0.0
			if state_t > 0.5:
				var px := player_x()
				for i in 6:
					var x := clampf(px + (i - 2.5) * 36.0, arena_left + 10, arena_right - 10)
					_crown_shard(x, 0.85 + i * 0.1)
				_set_action("recover", "cast")
				vulnerable = true
		"recover":
			velocity.x = 0.0
			vulnerable = true
			if state_t > 1.0 * tempo:
				_choose_action()
		_:
			if state_t > 0.8:
				_choose_action()


func _crown_shard(x: float, delay: float) -> void:
	var mark := Sprite2D.new()
	mark.texture = load("res://assets/sprites/warning.png")
	level.fx_root.add_child(mark)
	mark.global_position = Vector2(x, ceiling_y + 10)
	var tw := mark.create_tween()
	tw.tween_property(mark, "modulate:a", 0.3, delay * 0.5)
	tw.tween_property(mark, "modulate:a", 1.0, delay * 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and fighting and level:
			shoot("pale_orb", Vector2(x, ceiling_y + 12), Vector2(0, 80), 2, 3.0, 600.0)
		mark.queue_free())


func phase_tint() -> Color:
	match phase:
		2: return Color(0.95, 0.95, 1.25)
		3: return Color(1.35, 0.8, 0.85)
	return Color.WHITE
