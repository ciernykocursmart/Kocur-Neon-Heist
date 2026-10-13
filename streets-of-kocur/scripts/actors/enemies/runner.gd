extends Enemy
## White Runner: fast and slippery. Circles to the side the player is not
## facing, then lunges in with a flying kick from mid range and runs off.

var retreat_dir := 1


func on_setup() -> void:
	moves = {
		"lunge": {"windup": 0.28, "active": 0.26, "recovery": 0.3, "dmg": 1.0, "x0": -4.0, "x1": 56.0,
			"depth": 16.0, "z0": 0.0, "z1": 80.0, "kb": 200.0, "stun": 0.35, "lunge": 0.0, "sound": "dash"},
	}


func think_goal(p: Fighter) -> Vector2:
	# Flank: prefer the side behind the player's back.
	var side := float(-p.facing)
	if has_token:
		return p.position + Vector2(side * 130.0, 0)
	return p.position + Vector2(side * hover.x, hover.y)


func pick_attack(p: Fighter) -> String:
	if not has_token:
		return ""
	var dx := absf(p.position.x - position.x)
	if dx >= 80.0 and dx <= 175.0 and absf(p.position.y - position.y) <= 12.0 and p.z < 40.0:
		return "lunge"
	return ""


func _tick_attack(dt: float) -> void:
	if state_t < float(move["active"]):
		move_by(facing * 560.0 * dt, 0.0)
		level.resolve_attack(self, cur_atk)
	else:
		cur_atk = {}
		set_state("recover")


func tick_custom(dt: float) -> void:
	if state == "retreat":
		move_by(retreat_dir * speed * dt, 0.0)
		facing = -retreat_dir
		if state_t > 0.8:
			set_state("approach")
	else:
		super(dt)


func tick(dt: float) -> void:
	var was := state
	super(dt)
	# After a lunge, run off instead of standing next to the player.
	if was == "recover" and state == "approach" and not dead:
		var p: Fighter = level.player
		retreat_dir = 1 if position.x >= p.position.x else -1
		set_state("retreat")


func on_windup_start() -> void:
	level.play_sfx("hiss", -8.0, 0.15)


func pose() -> Dictionary:
	var p := super()
	match state:
		"attack":
			p["lean"] = 0.5
			p["leg_f"] = 1.2
			p["lift_f"] = 22.0
			p["leg_b"] = -0.8
			p["arm_f"] = Vector2(-6, 6)
		"windup":
			p["crouch"] = 0.6
			p["lean"] = 0.3
		"retreat", "approach":
			p["lean"] = 0.3
	return p
