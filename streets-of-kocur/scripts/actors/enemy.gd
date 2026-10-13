class_name Enemy
extends Fighter
## Base white-cat gang member. Simple readable state machine:
##   enter -> approach / reposition -> windup (telegraph) -> attack -> recover
##   hurt / knock / down / getup / grabbed / thrown / defeated
## Melee attackers need an "attack token" from the level, so only a limited
## number of cats (by difficulty) commit to attacking the player at once while
## the rest circle at a distance. Archetypes override pick_attack(),
## think_goal() and the attack table.

var data := {}
var speed := 120.0
var dmg := 7.0
var atk_range := 52.0
var cooldown := 1.2
var cd := 0.8
var score_value := 100
var has_token := false
var token_t := 0.0
var rng := RandomNumberGenerator.new()
var hover := Vector2(200, 0)
var hover_t := 0.0
var stuck_t := 0.0
var detour := 0.0
var detour_t := 0.0
var grabbable := true
var poise := 0
var poise_count := 0
var move_name := ""
var move := {}
var queue_next := ""
var thrown_atk := {}
var thrown_by: Fighter = null
var fade := 0.0
var removed := false
var spawn_side := 1
var outside_t := 0.0
var is_boss := false
var hit_react_t := 0.0  ## boss/armored "ouch" pose timer

## Attack table, shared shape with the player's moves (see balance.gd).
var moves := {
	"punch": {"windup": 0.38, "active": 0.08, "recovery": 0.4, "dmg": 1.0, "x0": -4.0, "x1": 58.0, "depth": 16.0,
		"z0": 10.0, "z1": 90.0, "kb": 90.0, "stun": 0.3, "lunge": 30.0, "sound": "jab"},
}


func setup(enemy_kind: String, lvl: Node, seed_value: int) -> void:
	level = lvl
	kind = enemy_kind
	team = "enemy"
	rng.seed = seed_value
	var d := Game.diff()
	if B.ENEMIES.has(enemy_kind):
		data = B.ENEMIES[enemy_kind]
		setup_look(enemy_kind, float(data["scale"]))
	max_hp = float(data.get("hp", 30.0)) * float(d["enemy_hp"])
	hp = max_hp
	speed = float(data.get("speed", 120.0))
	dmg = float(data.get("dmg", 7.0)) * float(d["enemy_dmg"])
	atk_range = float(data.get("range", 52.0))
	cooldown = float(data.get("cooldown", 1.2)) / float(d["aggro"])
	score_value = int(data.get("score", 100))
	hurt_w = float(data.get("hurt_w", 20.0))
	body_h = 92.0 * scale_k
	armor = int(data.get("armor", 0))
	poise = int(data.get("poise", 0))
	grabbable = bool(data.get("grab", true))
	flash_color = Color("ff4a5a")
	cd = 0.6 + rng.randf() * 0.8
	hover = Vector2(180 + rng.randf() * 90, rng.randf_range(-60, 60))
	on_setup()


func on_setup() -> void:
	pass


func tick(dt: float) -> void:
	tick_common(dt)
	cd -= dt
	hit_react_t = maxf(0.0, hit_react_t - dt)
	if dead:
		tick_reactions(dt)
		if state in ["down", "dead"]:
			fade += dt
			blink = fade > 0.5
			if fade > 1.3 and not removed:
				removed = true
				level.remove_actor(self)
		return
	if held_by != null:
		return
	if state == "thrown":
		_tick_thrown(dt)
		return
	if tick_reactions(dt):
		_drop_token()
		return
	match state:
		"enter":
			_tick_enter(dt)
		"idle", "approach", "reposition":
			_think(dt)
		"windup":
			if state_t >= float(move["windup"]):
				set_state("attack")
				cur_atk = make_attack(move, dmg)
				level.play_sfx(String(move.get("sound", "jab")), -3.0, 0.1)
				on_attack_start()
		"attack":
			_tick_attack(dt)
		"recover":
			if state_t >= float(move.get("recovery", 0.4)):
				if queue_next != "" and not level.player_unavailable():
					var nxt := queue_next
					queue_next = ""
					start_attack(nxt)
				else:
					queue_next = ""
					cd = cooldown * (0.8 + rng.randf() * 0.4)
					_drop_token()
					set_state("approach")
		_:
			tick_custom(dt)


func tick_custom(_dt: float) -> void:
	if state_t > 3.0:
		set_state("approach")


# ------------------------------------------------------------------ movement
func _tick_enter(dt: float) -> void:
	var b: Rect2 = level.arena_rect()
	var inside_x := clampf(position.x, b.position.x + 80.0, b.end.x - 80.0)
	facing = 1 if inside_x > position.x else -1
	move_by(signf(inside_x - position.x) * speed * maxf(1.0, 160.0 / speed) * dt, 0.0)
	if absf(inside_x - position.x) < 8.0 or state_t > 6.0:
		set_state("approach")


## Where this enemy wants to stand right now (world position).
func think_goal(p: Fighter) -> Vector2:
	var side := 1.0 if position.x >= p.position.x else -1.0
	if has_token:
		return p.position + Vector2(side * atk_range * 0.8, 0)
	return p.position + Vector2(side * hover.x, hover.y)


func _think(dt: float) -> void:
	var p: Fighter = level.player
	if level.player_unavailable():
		_drop_token()
		_walk_to(p.position + Vector2((1.0 if position.x >= p.position.x else -1.0) * 260.0, hover.y), dt, 0.6)
		return
	hover_t -= dt
	if hover_t <= 0.0:
		hover_t = 1.4 + rng.randf() * 1.4
		hover = Vector2(170 + rng.randf() * 110, rng.randf_range(-70, 70))
	if not has_token and cd <= 0.2 and wants_token():
		has_token = level.request_token(self)
		token_t = 0.0
	if has_token:
		token_t += dt
		if token_t > 5.0:
			_drop_token()
			cd = 0.8
	var goal := think_goal(p)
	_walk_to(goal, dt, 1.0)
	facing = 1 if p.position.x > position.x else -1
	if cd <= 0.0:
		var a := pick_attack(p)
		if a != "":
			start_attack(a)


func wants_token() -> bool:
	return true


func _walk_to(goal: Vector2, dt: float, speed_k: float) -> void:
	if detour_t > 0.0:
		detour_t -= dt
		goal.y += detour
	var d := goal - position
	var v := Vector2.ZERO
	if absf(d.x) > 6.0:
		v.x = signf(d.x) * speed * speed_k
	if absf(d.y) > 4.0:
		v.y = signf(d.y) * speed * 0.7 * speed_k
	# Keep a little space from other gang members so groups stay readable.
	for e: Fighter in level.enemies():
		if e == self or e.dead:
			continue
		var o := position - e.position
		if absf(o.x) < 34.0 and absf(o.y) < 14.0:
			v.y += (1.0 if o.y >= 0.0 else -1.0) * 60.0
			v.x += (1.0 if o.x >= 0.0 else -1.0) * 30.0
	var old := position
	move_by(v.x * dt, v.y * dt)
	var moved := position.distance_to(old)
	if v.length() > 10.0 and moved < v.length() * dt * 0.25:
		stuck_t += dt
		if stuck_t > 0.8:
			stuck_t = 0.0
			detour = 90.0 if rng.randf() < 0.5 else -90.0
			detour_t = 1.0
	else:
		stuck_t = maxf(0.0, stuck_t - dt)
	state = "approach" if v.length() > 10.0 else "idle"


func _drop_token() -> void:
	if has_token:
		has_token = false
		level.release_token(self)


# ------------------------------------------------------------------ attacks
## Returns the attack to start now, or "" to keep positioning.
func pick_attack(p: Fighter) -> String:
	if not has_token:
		return ""
	if in_melee_range(p, atk_range):
		return "punch"
	return ""


func in_melee_range(p: Fighter, reach: float) -> bool:
	var dx := absf(p.position.x - position.x)
	return dx <= reach + 4.0 and dx >= 14.0 and absf(p.position.y - position.y) <= 10.0 and p.z < 40.0


func start_attack(n: String) -> void:
	move_name = n
	move = moves[n]
	cur_atk = {}
	vel = Vector2.ZERO
	var p: Fighter = level.player
	facing = 1 if p.position.x > position.x else -1
	set_state("windup")
	on_windup_start()


func on_windup_start() -> void:
	pass


func on_attack_start() -> void:
	pass


func _tick_attack(dt: float) -> void:
	var act := float(move.get("active", 0.08))
	if state_t < act:
		move_by(facing * float(move.get("lunge", 0.0)) * dt / act, 0.0)
		level.resolve_attack(self, cur_atk)
	else:
		cur_atk = {}
		set_state("recover")


# ------------------------------------------------------------------ reactions
func react_to_hit(atk: Dictionary, dir: int) -> void:
	_drop_token()
	queue_next = ""
	if poise > 0 and not atk.get("knockdown", false) and String(atk.get("type", "")) == "light":
		poise_count += 1
		if poise_count < poise:
			vel.x = dir * 30.0
			hit_react_t = 0.15
			return
	poise_count = 0
	if armor >= 1:
		hit_react_t = 0.18
	super(atk, dir)


func on_hit_taken(_dmg: float, _atk: Dictionary, _from: Node2D) -> void:
	level.play_sfx("hit" if String(_atk.get("type", "light")) == "light" else "hit_heavy", -1.0, 0.12)


func on_died() -> void:
	_drop_token()
	if held_by and is_instance_valid(held_by):
		held_by = null
	level.on_enemy_defeated(self)


# ------------------------------------------------------------------ grabs
func can_be_grabbed() -> bool:
	return grabbable and not dead and not is_boss and held_by == null and z <= 0.5 \
		and state in ["idle", "approach", "reposition", "hurt", "windup", "recover", "retreat"]


func get_grabbed(by: Fighter) -> void:
	_drop_token()
	held_by = by
	cur_atk = {}
	queue_next = ""
	set_state("grabbed")


func take_knee(amount: float, by: Fighter) -> void:
	hp = maxf(0.0, hp - amount)
	flash_t = 0.12
	if hp <= 0.0:
		held_by = null
		die(int(by.facing), {"kb": 260.0, "launch": 300.0})


func release_from_grab(escaped: bool) -> void:
	held_by = null
	if escaped:
		hurt(-facing, 160.0, 0.2)
	else:
		set_state("approach")


func get_thrown(by: Fighter, dir: int) -> void:
	held_by = null
	thrown_by = by
	set_state("thrown")
	facing = -dir
	vel = Vector2(dir * float(B.MOVES["throw"]["speed"]), 0)
	vz = float(B.MOVES["throw"]["launch"])
	z = 30.0
	thrown_atk = by.make_attack({"dmg": B.MOVES["throw"]["thrown_dmg"], "radial": true, "rx": 30.0, "depth": 22.0,
		"z0": -60.0, "z1": 90.0, "kb": 320.0, "launch": 280.0, "knockdown": true, "type": "throw"})
	thrown_atk["hit"].append(self)


func _tick_thrown(dt: float) -> void:
	z += vz * dt
	vz -= gravity * dt
	var old_x := position.x
	move_by(vel.x * dt, 0.0)
	# The hitbox travels with the thrown body; the thrower still gets the credit (atk owner).
	level.resolve_attack(self, thrown_atk, "enemy", self)
	var hit_wall := absf(position.x - old_x) < absf(vel.x * dt) * 0.3
	if z <= 0.0 or hit_wall:
		z = maxf(z, 0.0)
		var d: float = float(B.MOVES["throw"]["dmg"])
		hp = maxf(0.0, hp - d)
		flash_t = 0.14
		level.shake(6.0, 0.18)
		level.play_sfx("hit_heavy", 0.0)
		level.fx.dust(position, 1.5)
		if thrown_by and is_instance_valid(thrown_by):
			level.register_hit(thrown_by, self, d)
		if hp <= 0.0:
			die(int(signf(vel.x)) if vel.x != 0.0 else 1, {"kb": 120.0, "launch": 180.0})
		else:
			knock_down(int(signf(vel.x)) if vel.x != 0.0 else 1, 120.0, 160.0)


# ------------------------------------------------------------------ drawing
func pose() -> Dictionary:
	var p := super()
	match state:
		"windup":
			p["lean"] = -0.25
			p["arm_f"] = Vector2(-14, 4)
			p["arm_b"] = Vector2(-16, 10)
			p["eyes"] = "angry"
			p["mouth"] = "teeth"
			p["crouch"] = 0.3
		"attack":
			p["lean"] = 0.25
			p["arm_f"] = Vector2(32, -4)
			p["eyes"] = "angry"
			p["mouth"] = "open"
			p["leg_f"] = 0.4
			p["leg_b"] = -0.4
		"recover":
			p["arm_f"] = Vector2(18, 10)
		"grabbed":
			p["eyes"] = "wide"
			p["mouth"] = "o"
			p["arm_f"] = Vector2(-4, -20)
			p["arm_b"] = Vector2(-10, -18)
			p["lean"] = -0.15
			p["leg_f"] = sin(anim_t * 20.0) * 0.4
			p["leg_b"] = -sin(anim_t * 20.0) * 0.4
		"thrown":
			p["curl"] = 1.0
			p["item_angle"] = anim_t * 14.0
	if hit_react_t > 0.0 and not state in ["knock", "down"]:
		p["eyes"] = "hurt"
		p["mouth"] = "o"
		p["lean"] = float(p.get("lean", 0.0)) - 0.12
	return p


func draw_overlay() -> void:
	# Attack telegraph: a "!" over the head while winding up.
	if state == "windup" and not dead:
		var y := -body_h - 34.0 - z
		var a := clampf(state_t * 6.0, 0.0, 1.0)
		var col := Color(1.0, 0.85, 0.2, a)
		draw_circle(Vector2(0, y), 11.0, Color(0.15, 0.05, 0.1, a))
		draw_line(Vector2(0, y - 7), Vector2(0, y + 2), col, 4.0)
		draw_circle(Vector2(0, y + 6), 2.2, col)
