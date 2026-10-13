extends Enemy
## White Enforcer: armoured heavy. Can't be grabbed and ignores light hits
## (only finishers, throws, PAWQUAKE and hazards knock it down). Two clearly
## telegraphed moves: a glowing-red hammer slam and a shoulder charge that
## leaves it dazed if it hits a wall.

var charge_dir := 1


func on_setup() -> void:
	knockdown_resist()
	moves = {
		"slam": {"windup": 0.75, "active": 0.12, "recovery": 0.75, "dmg": 1.0, "x0": -10.0, "x1": 108.0,
			"depth": 26.0, "z0": 0.0, "z1": 110.0, "kb": 300.0, "launch": 300.0, "knockdown": true, "stun": 0.5,
			"lunge": 20.0, "sound": "boss_slam"},
		"charge": {"windup": 0.6, "active": 0.9, "recovery": 0.5, "dmg": 0.85, "x0": -4.0, "x1": 60.0,
			"depth": 20.0, "z0": 0.0, "z1": 110.0, "kb": 320.0, "launch": 260.0, "knockdown": true, "stun": 0.5,
			"lunge": 0.0, "sound": "dash"},
	}


func knockdown_resist() -> void:
	kb_mult = 0.35
	down_time = 0.9


func pick_attack(p: Fighter) -> String:
	if not has_token:
		return ""
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if in_melee_range(p, 90.0):
		return "slam"
	if dx >= 200.0 and dx <= 460.0 and dy <= 16.0 and rng.randf() < 0.5:
		return "charge"
	return ""


func think_goal(p: Fighter) -> Vector2:
	var side := 1.0 if position.x >= p.position.x else -1.0
	if has_token:
		return p.position + Vector2(side * 70.0, 0)
	return p.position + Vector2(side * hover.x, hover.y)


func on_windup_start() -> void:
	level.play_sfx("warn", -6.0)
	charge_dir = facing


func _tick_attack(dt: float) -> void:
	if move_name == "charge":
		var old := position.x
		move_by(charge_dir * 520.0 * dt, 0.0)
		level.resolve_attack(self, cur_atk)
		if state_t > 0.1 and absf(position.x - old) < 2.0:
			cur_atk = {}
			level.shake(6.0, 0.2)
			level.play_sfx("crate", -2.0)
			level.fx.stars(self)
			set_state("dazed")
			return
		if state_t >= float(move["active"]):
			cur_atk = {}
			set_state("recover")
		return
	super(dt)
	if state == "recover" and move_name == "slam":
		level.shake(5.0, 0.15)
		level.fx.dust(position + Vector2(facing * 70.0, 0), 1.6)


func tick_custom(dt: float) -> void:
	if state == "dazed":
		if state_t >= 1.1:
			cd = cooldown
			_drop_token()
			set_state("approach")
	else:
		super(dt)


func pose() -> Dictionary:
	var p := super()
	match state:
		"windup":
			if move_name == "slam":
				p["arm_f"] = Vector2(-4, -40)
				p["arm_b"] = Vector2(-10, -34)
				p["lean"] = -0.3
			else:
				p["crouch"] = 0.5
				p["lean"] = 0.4
				p["leg_b"] = sin(anim_t * 25.0) * 0.4
		"attack":
			if move_name == "slam":
				p["arm_f"] = Vector2(36, 14)
				p["arm_b"] = Vector2(30, 18)
				p["lean"] = 0.4
			else:
				p["lean"] = 0.55
				p["arm_f"] = Vector2(14, 6)
				var s := sin(anim_t * 18.0)
				p["leg_f"] = s * 0.7
				p["leg_b"] = -s * 0.7
		"dazed":
			p["eyes"] = "dizzy"
			p["mouth"] = "o"
			p["head_tilt"] = sin(anim_t * 5.0) * 0.2
	return p


func draw_body() -> void:
	# Red glow behind the enforcer while it winds up: the big-hit telegraph.
	if state == "windup":
		var a := 0.25 + 0.25 * sin(state_t * 30.0)
		draw_circle(Vector2(0, -50), 60.0, Color(1.0, 0.15, 0.1, a))
	super()


func draw_overlay() -> void:
	super()
	if state == "windup" and move_name == "slam":
		var a := clampf(state_t / 0.75, 0.0, 1.0)
		var r := Rect2(Vector2(minf(facing * -10.0, facing * 108.0), -10), Vector2(118.0, 20))
		draw_rect(r, Color(1, 0.2, 0.1, 0.15 + 0.25 * a))
		draw_rect(r, Color(1, 0.3, 0.2, 0.6 * a), false, 2.0)
	if state == "windup" and move_name == "charge":
		var a2 := clampf(state_t / 0.6, 0.0, 1.0)
		draw_line(Vector2(0, 0), Vector2(facing * 420.0, 0), Color(1, 0.3, 0.2, 0.45 * a2), 10.0)
