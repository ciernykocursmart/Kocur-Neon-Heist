class_name Player
extends Fighter
## Kocur, the black-cat hero. Movement on both street axes, jump, a 3-hit
## paw-claw-WHAM combo with a timing window, flying kick, running pounce,
## PAWQUAKE special (energy meter), grab / knee / throw.

signal hp_changed
signal energy_changed
signal combo_hit(count: int)
signal died_once

const P := B.PLAYER
const COMBO := ["jab", "swipe", "finisher"]

var energy := 50.0
var combo_step := 0
var combo_timer := 0.0
var cur_move := ""
var air_attack_used := false
var running := false
var atk_buf := 0.0
var jump_buf := 0.0
var special_buf := 0.0
var grab_buf := 0.0
var grab_target: Fighter = null
var grab_t := 0.0
var knees := 0
var last_tap := {-1: -10.0, 1: -10.0}
var clock := 0.0
var input := {"move": Vector2.ZERO, "jump": false, "attack": false, "special": false, "grab": false, "run": false}
var control_locked := false
var damage_taken := 0.0
var specials_used := 0
var deaths := 0
var hit_count := 0  ## hits landed in the current combo chain
var hit_timer := 0.0
var best_combo := 0


func _init() -> void:
	team = "player"
	kind = "hero"
	max_hp = P["max_hp"]
	hp = max_hp
	hurt_w = 20.0
	body_h = 92.0
	gravity = P["gravity"]
	down_time = 0.55
	getup_invuln = P["getup_invuln"]
	flash_color = Color("ff6a5a")
	setup_look("hero", 1.0)


# ------------------------------------------------------------------ input
func read_input() -> void:
	if Game.bot_input != null:
		input = Game.bot_input.poll(self)
		return
	var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	input = {
		"move": mv,
		"jump": Input.is_action_just_pressed("jump"),
		"attack": Input.is_action_just_pressed("attack"),
		"special": Input.is_action_just_pressed("special"),
		"grab": Input.is_action_just_pressed("grab"),
		"run": Input.is_action_pressed("run"),
		"tap_left": Input.is_action_just_pressed("move_left"),
		"tap_right": Input.is_action_just_pressed("move_right"),
	}


func tick(dt: float) -> void:
	tick_common(dt)
	clock += dt
	blink = invuln > 0.0 and not dead and state != "special"
	if not dead:
		energy = minf(P["energy_max"], energy + P["energy_regen"] * dt)
	if control_locked or dead:
		input = {"move": Vector2.ZERO, "jump": false, "attack": false, "special": false, "grab": false, "run": false}
	else:
		read_input()
	_buffer(dt)
	if hit_timer > 0.0:
		hit_timer -= dt
		if hit_timer <= 0.0:
			_end_combo_chain()
	combo_timer = maxf(0.0, combo_timer - dt)
	if tick_reactions(dt):
		return
	match state:
		"idle", "walk", "run":
			_ground(dt)
		"jump", "jump_attack":
			_air(dt)
		"land":
			if state_t >= 0.06:
				set_state("idle")
		"attack", "pounce":
			_attack(dt)
		"special":
			_special(dt)
		"grab":
			_grab(dt)
		"throw":
			if state_t >= 0.3:
				set_state("idle")
		"dead_wait":
			pass
		"victory":
			pass
	energy_changed.emit()


func _buffer(dt: float) -> void:
	atk_buf = 0.16 if input.get("attack", false) else maxf(0.0, atk_buf - dt)
	jump_buf = 0.1 if input.get("jump", false) else maxf(0.0, jump_buf - dt)
	special_buf = 0.14 if input.get("special", false) else maxf(0.0, special_buf - dt)
	grab_buf = 0.12 if input.get("grab", false) else maxf(0.0, grab_buf - dt)
	for d in [-1, 1]:
		var key := "tap_left" if d == -1 else "tap_right"
		if input.get(key, false):
			if clock - float(last_tap[d]) < 0.28:
				running = true
			last_tap[d] = clock


# ------------------------------------------------------------------ ground
func _ground(dt: float) -> void:
	var mv: Vector2 = input["move"]
	if absf(mv.x) < 0.2:
		running = false
	if mv.x > 0.2:
		facing = 1
	elif mv.x < -0.2:
		facing = -1
	var run_now: bool = (running or input.get("run", false)) and absf(mv.x) > 0.2
	var tx: float = mv.x * (P["run_x"] if run_now else P["walk_x"])
	var ty: float = mv.y * P["walk_y"]
	var ax: float = P["accel"] if absf(tx) > absf(vel.x) else P["decel"]
	vel.x = move_toward(vel.x, tx, ax * dt)
	vel.y = move_toward(vel.y, ty, (P["accel"] if absf(ty) > absf(vel.y) else P["decel"]) * dt)
	move_by(vel.x * dt, vel.y * dt)
	var moving := absf(vel.x) > 20.0 or absf(vel.y) > 20.0
	var want := "run" if run_now and moving else ("walk" if moving else "idle")
	if want != state:
		state = want
	# Actions, in priority order.
	if jump_buf > 0.0:
		jump_buf = 0.0
		vz = P["jump_v"]
		z = 1.0
		air_attack_used = false
		set_state("jump")
		level.play_sfx("jump", -3.0)
	elif special_buf > 0.0:
		special_buf = 0.0
		try_special()
	elif grab_buf > 0.0 and try_grab():
		grab_buf = 0.0
	elif atk_buf > 0.0:
		atk_buf = 0.0
		grab_buf = 0.0
		if absf(vel.x) > P["walk_x"] + 30.0:
			_start_move("pounce")
			set_state("pounce")
		else:
			start_combo()


## Starts the next combo hit. `chain` = pressed during the previous hit, which
## always continues the combo; otherwise it continues only inside the short
## grace window after a hit and restarts with the jab when that has run out.
func start_combo(chain := false) -> void:
	var step := combo_step if chain or combo_timer > 0.0 else 0
	_start_move(COMBO[step])
	combo_step = (step + 1) % COMBO.size()
	combo_timer = 0.0
	set_state("attack")


func _start_move(move_name: String) -> void:
	cur_move = move_name
	cur_atk = {}
	var mv: Vector2 = input["move"]
	if mv.x > 0.2:
		facing = 1
	elif mv.x < -0.2:
		facing = -1
	if move_name != "pounce":
		vel = Vector2.ZERO
	level.play_sfx("whoosh", -10.0, 0.12)


func _attack(dt: float) -> void:
	var m: Dictionary = B.MOVES[cur_move]
	var su: float = m["startup"]
	var ac: float = m["active"]
	var rc: float = m["recovery"]
	var t := state_t
	if cur_move == "pounce":
		vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
		if _blocked_ahead():
			vel.x = 0.0
		move_by(vel.x * dt, 0.0)
	elif t < su + ac and not _blocked_ahead():
		move_by(facing * float(m.get("lunge", 0.0)) * dt / (su + ac), 0.0)
	if t >= su and t < su + ac:
		if cur_atk.is_empty():
			cur_atk = make_attack(m)
			level.play_sfx(String(m["sound"]), -2.0, 0.08)
		level.resolve_attack(self, cur_atk)
	elif t >= su + ac:
		cur_atk = {}
		# Chain into the next combo hit by pressing attack in the window.
		if state == "attack" and cur_move != "finisher" and atk_buf > 0.0:
			atk_buf = 0.0
			start_combo(true)
			return
		if t >= su + ac + rc:
			if cur_move in ["jab", "swipe"]:
				combo_timer = P["combo_grace"]
			else:
				combo_step = 0
			set_state("idle")


## True when a standing gang cat is right in front: attack lunges stop there
## instead of carrying the hero through the target.
func _blocked_ahead() -> bool:
	for e: Fighter in level.enemies():
		if e.is_knocked() or e.z > 20.0 or absf(e.position.y - position.y) > 20.0:
			continue
		var dx := (e.position.x - position.x) * facing
		if dx >= 0.0 and dx < e.hurt_w + 30.0:
			return true
	return false


# ------------------------------------------------------------------ air
func _air(dt: float) -> void:
	var mv: Vector2 = input["move"]
	vel.x = move_toward(vel.x, mv.x * P["walk_x"] * 0.95, 1100.0 * dt)
	vel.y = move_toward(vel.y, mv.y * P["walk_y"] * 0.6, 900.0 * dt)
	if state == "jump" and absf(mv.x) > 0.2:
		facing = 1 if mv.x > 0 else -1
	move_by(vel.x * dt, vel.y * dt)
	z += vz * dt
	vz -= gravity * dt
	if state == "jump" and atk_buf > 0.0 and not air_attack_used:
		atk_buf = 0.0
		air_attack_used = true
		cur_move = "jump_kick"
		cur_atk = make_attack(B.MOVES["jump_kick"])
		set_state("jump_attack")
		level.play_sfx("swipe", -2.0)
	if state == "jump_attack" and not cur_atk.is_empty():
		if state_t <= float(B.MOVES["jump_kick"]["active"]):
			level.resolve_attack(self, cur_atk)
		else:
			cur_atk = {}
	if z <= 0.0:
		z = 0.0
		vz = 0.0
		cur_atk = {}
		vel *= 0.4
		level.fx.dust(position, 0.7)
		level.play_sfx("land", -8.0)
		set_state("land")


# ------------------------------------------------------------------ special
func try_special() -> bool:
	if energy < P["special_cost"]:
		level.fx.text(position + Vector2(0, -130), "NEED ENERGY", Color("7ab8ff"), 18)
		level.play_sfx("ui_back", -6.0)
		return false
	energy -= P["special_cost"]
	specials_used += 1
	Game.attempt["specials"] = int(Game.attempt.get("specials", 0)) + 1
	vel = Vector2.ZERO
	cur_atk = {}
	set_state("special")
	invuln = maxf(invuln, 0.7)
	level.play_sfx("special", 0.0, 0.02)
	return true


func _special(_dt: float) -> void:
	var m: Dictionary = B.MOVES["pawquake"]
	var su: float = m["startup"]
	var ac: float = m["active"]
	if state_t >= su and state_t < su + ac:
		if cur_atk.is_empty():
			cur_atk = make_attack(m)
			level.fx.ring(position, 140.0, Color("7ab8ff"))
			level.shake(9.0, 0.25)
		level.resolve_attack(self, cur_atk)
	elif state_t >= su + ac:
		cur_atk = {}
		if state_t >= su + ac + float(m["recovery"]):
			set_state("idle")


# ------------------------------------------------------------------ grab
func try_grab() -> bool:
	var best: Fighter = null
	var best_d := 999.0
	for e: Fighter in level.enemies():
		if not e.has_method("can_be_grabbed") or not e.can_be_grabbed():
			continue
		var dx := (e.position.x - position.x) * facing
		var dy := absf(e.position.y - position.y)
		if dx >= 8.0 and dx <= 66.0 + e.hurt_w and dy <= 16.0 and dx < best_d:
			best = e
			best_d = dx
	if best == null:
		return false
	grab_target = best
	grab_t = 0.0
	knees = 0
	vel = Vector2.ZERO
	cur_atk = {}
	best.get_grabbed(self)
	set_state("grab")
	level.play_sfx("grab", -2.0)
	return true


func _grab(dt: float) -> void:
	grab_t += dt
	if grab_target == null or not is_instance_valid(grab_target) or grab_target.dead or grab_target.held_by != self:
		_release_grab(false)
		return
	var mv: Vector2 = input["move"]
	if mv.x > 0.5:
		facing = 1
	elif mv.x < -0.5:
		facing = -1
	grab_target.position = Vector2(position.x + facing * (28.0 + grab_target.hurt_w), position.y)
	grab_target.facing = -facing
	if state_t > 0.12 and atk_buf > 0.0:
		atk_buf = 0.0
		knees += 1
		var m: Dictionary = B.MOVES["knee"]
		grab_target.take_knee(float(m["dmg"]), self)
		level.play_sfx("hit", -2.0)
		level.fx.spark(grab_target.position + Vector2(-facing * 6.0, -40.0), 0.8)
		level.register_hit(self, grab_target, float(m["dmg"]))
		state_t = 0.0
		if knees >= 3 and grab_target != null and is_instance_valid(grab_target) and not grab_target.dead:
			_throw()
		return
	if state_t > 0.12 and grab_buf > 0.0:
		grab_buf = 0.0
		_throw()
		return
	if grab_t >= P["grab_time"]:
		_release_grab(true)


func _throw() -> void:
	if grab_target and is_instance_valid(grab_target) and not grab_target.dead:
		grab_target.get_thrown(self, facing)
		level.play_sfx("throw_body", 0.0)
	grab_target = null
	set_state("throw")


func _release_grab(escaped: bool) -> void:
	if grab_target and is_instance_valid(grab_target) and grab_target.held_by == self:
		grab_target.release_from_grab(escaped)
	grab_target = null
	if state == "grab":
		set_state("idle")


# ------------------------------------------------------------------ damage
func can_be_hit() -> bool:
	return super() and state not in ["dead_wait", "victory"]


func receive_hit(atk: Dictionary, from: Node2D) -> bool:
	if Game.god_mode and can_be_hit():
		flash_t = 0.1
		invuln = P["hurt_invuln"]
		return true
	if state == "grab" and can_be_hit():
		_release_grab(false)
	var before := hp
	var landed := super(atk, from)
	if landed:
		damage_taken += before - hp
		energy = minf(P["energy_max"], energy + P["energy_when_hurt"])
		if not dead:
			invuln = maxf(invuln, P["hurt_invuln"] if not is_knocked() else 0.0)
		level.play_sfx("hurt", 0.0)
		level.shake(5.0, 0.15)
		hp_changed.emit()
	return landed


func react_to_hit(atk: Dictionary, dir: int) -> void:
	cur_atk = {}
	if atk.get("knockdown", false) or chain_hits >= 3:
		knock_down(dir, maxf(float(atk.get("kb", 200.0)), 200.0), float(atk.get("launch", 260.0)))
	else:
		hurt(dir, float(atk.get("kb", 60.0)) * 0.8, 0.28)


func on_died() -> void:
	deaths += 1
	died_once.emit()


func tick_reactions(dt: float) -> bool:
	if dead and state == "down" and state_t > 0.9:
		set_state("dead_wait")
		level.on_player_down()
		return true
	return super(dt)


func heal(amount: float) -> float:
	var before := hp
	hp = minf(max_hp, hp + amount)
	hp_changed.emit()
	return hp - before


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, P["energy_max"])
	energy_changed.emit()


## Brings the player back after losing a life (or after a continue).
func respawn(full_energy := false) -> void:
	dead = false
	hp = max_hp
	z = 0.0
	vz = 0.0
	vel = Vector2.ZERO
	cur_atk = {}
	chain_hits = 0
	grab_target = null
	combo_step = 0
	invuln = P["respawn_invuln"]
	if full_energy:
		energy = P["energy_max"]
	set_state("idle")
	hp_changed.emit()


## Called by the level whenever this player's attack connects.
func on_hit_landed(_target: Fighter, _dmg: float) -> void:
	energy = minf(P["energy_max"], energy + P["energy_per_hit"])
	hit_count += 1
	hit_timer = B.COMBO_TIMEOUT
	best_combo = maxi(best_combo, hit_count)
	combo_hit.emit(hit_count)


func _end_combo_chain() -> void:
	if hit_count >= 5 and level:
		level.combo_bonus(hit_count)
	hit_count = 0


# ------------------------------------------------------------------ pose
func pose() -> Dictionary:
	var p := super()
	var t := state_t
	match state:
		"attack", "pounce":
			var m: Dictionary = B.MOVES[cur_move]
			var su: float = m["startup"]
			var k := clampf(t / maxf(0.01, su), 0.0, 1.0)
			var hit_on := t >= su
			p["eyes"] = "angry" if hit_on else "open"
			p["mouth"] = "open" if cur_move == "finisher" and hit_on else "grin"
			match cur_move:
				"jab":
					p["arm_f"] = Vector2(lerpf(0, 34, k) if hit_on else -6.0, -2) if hit_on else Vector2(-6, 8)
					p["lean"] = 0.15 if hit_on else -0.05
					p["leg_f"] = 0.35
					p["leg_b"] = -0.3
				"swipe":
					p["arm_b"] = Vector2(30, -14) if hit_on else Vector2(-16, -6)
					p["arm_f"] = Vector2(-4, 14)
					p["lean"] = 0.25 if hit_on else -0.1
					p["leg_f"] = 0.4
					p["leg_b"] = -0.4
				"finisher":
					p["arm_f"] = Vector2(26, -30) if hit_on else Vector2(-10, 16)
					p["arm_b"] = Vector2(14, -10) if hit_on else Vector2(-14, 10)
					p["lean"] = 0.3 if hit_on else -0.25
					p["crouch"] = 0.0 if hit_on else 0.5
					p["leg_f"] = 0.6 if hit_on else 0.2
					p["leg_b"] = -0.5
				"pounce":
					p["arm_f"] = Vector2(34, -6)
					p["arm_b"] = Vector2(26, -2)
					p["lean"] = 0.6
					p["leg_b"] = -1.0
					p["lift_b"] = 12.0
					p["leg_f"] = 0.5
		"jump":
			p["crouch"] = 0.2
			p["leg_f"] = 0.5
			p["leg_b"] = -0.6
			p["lift_f"] = 14.0
			p["lift_b"] = 10.0
			p["arm_f"] = Vector2(10, 4)
			p["arm_b"] = Vector2(-12, 2)
		"jump_attack":
			p["lean"] = 0.25
			p["leg_f"] = 1.25
			p["lift_f"] = 24.0
			p["leg_b"] = -0.5
			p["lift_b"] = 14.0
			p["arm_f"] = Vector2(-8, 6)
			p["arm_b"] = Vector2(-14, 4)
			p["eyes"] = "angry"
			p["mouth"] = "open"
		"land":
			p["crouch"] = 0.6
			p["squash"] = Vector2(1.08, 0.94)
		"special":
			var spin := state_t * 30.0
			p["arm_f"] = Vector2(cos(spin) * 30, -10 + sin(spin) * 8)
			p["arm_b"] = Vector2(-cos(spin) * 30, -10 - sin(spin) * 8)
			p["lean"] = sin(spin) * 0.15
			p["eyes"] = "angry"
			p["mouth"] = "yell"
			p["crouch"] = 0.3
			p["tail"] = spin
		"grab":
			p["arm_f"] = Vector2(26, 0)
			p["arm_b"] = Vector2(22, -6)
			p["lean"] = 0.1
			p["mouth"] = "grin"
			if state_t < 0.1 and knees > 0:
				p["leg_f"] = 1.1
				p["lift_f"] = 24.0
		"throw":
			p["arm_f"] = Vector2(20, -34)
			p["arm_b"] = Vector2(10, -30)
			p["lean"] = -0.2
			p["mouth"] = "open"
		"victory":
			p["arm_f"] = Vector2(8, -36)
			p["arm_b"] = Vector2(-6, 12)
			p["eyes"] = "happy"
			p["mouth"] = "grin"
			p["squash"] = Vector2(1.0, 1.0 + absf(sin(anim_t * 6.0)) * 0.05)
		"dead_wait":
			p = super()
			p["lean"] = -1.35
			p["crouch"] = 1.0
			p["eyes"] = "x"
	return p


func draw_overlay() -> void:
	if state == "special" and state_t < 0.5:
		var r := 30.0 + state_t * 260.0
		draw_arc(Vector2(0, -40), r, 0, TAU, 32, Color(0.5, 0.75, 1.0, 1.0 - state_t * 2.0), 5.0)
