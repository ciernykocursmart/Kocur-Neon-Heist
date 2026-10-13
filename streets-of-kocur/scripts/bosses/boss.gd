class_name Boss
extends Enemy
## Shared boss behaviour: walk-in + intro roar, phases at health thresholds,
## and "moves" made of three readable parts:
##   tele (telegraph, never hurts) -> act (the attack) -> rec (vulnerable).
## Bosses have super armour (never stun-locked); hits make them jiggle instead.
## Subclasses implement choose_move(), move_tick() and their telegraph art.

signal phase_changed(p: int)

var boss_id := ""
var phase := 1
var mv := ""
var mv_phase := ""
var mv_t := 0.0
var rec_time := 0.8
var tele_mult := 1.0
var cd_base := 1.1
var thresholds := [0.5]  ## hp fractions that start phase 2, 3...
var title := ""
var display_name := ""
var target_pos := Vector2.ZERO
var move_dir := 1
var summons_done := {}
var min_dist := 140.0


func setup_boss(id: String, lvl: Node, seed_value: int) -> void:
	level = lvl
	boss_id = id
	kind = id
	team = "enemy"
	is_boss = true
	rng.seed = seed_value
	var d: Dictionary = B.BOSSES[id]
	var df := Game.diff()
	setup_look(id, float(d["scale"]))
	display_name = String(d["name"])
	title = String(d["title"])
	max_hp = float(d["hp"]) * float(df["enemy_hp"])
	hp = max_hp
	dmg = float(d["dmg"]) * float(df["enemy_dmg"])
	hurt_w = float(d["hurt_w"])
	body_h = 92.0 * scale_k
	depth_r = 12.0
	armor = 2
	grabbable = false
	score_value = int(d["score"])
	flash_color = Color("ff5a6a")
	cd = 1.0
	on_boss_setup()
	set_state("enter")


func on_boss_setup() -> void:
	pass


func can_be_hit() -> bool:
	return super() and state not in ["enter", "intro"]


func hp_frac() -> float:
	return hp / maxf(1.0, max_hp)


func tick(dt: float) -> void:
	tick_common(dt)
	hit_react_t = maxf(0.0, hit_react_t - dt)
	if dead:
		tick_reactions(dt)
		return
	match state:
		"enter":
			_tick_enter_boss(dt)
			return
		"intro":
			if state_t >= 1.3:
				set_state("idle")
			return
	# Phase changes at health thresholds (checked between moves too).
	while phase - 1 < thresholds.size() and hp_frac() <= float(thresholds[phase - 1]):
		phase += 1
		on_phase(phase)
		phase_changed.emit(phase)
	match state:
		"idle", "approach":
			cd -= dt
			if level.player_unavailable():
				_walk_to(level.player.position + Vector2((1.0 if position.x > level.player.position.x else -1.0) * 300.0, 0), dt, 0.6)
				return
			position_tick(dt)
			if cd <= 0.0:
				var m := choose_move(level.player)
				if m != "":
					begin(m)
		"move":
			mv_t += dt
			move_tick(dt)
		_:
			tick_custom(dt)


func _tick_enter_boss(dt: float) -> void:
	var b: Rect2 = level.arena_rect()
	var goal_x := b.end.x - 260.0
	facing = -1
	move_by(signf(goal_x - position.x) * 140.0 * dt, 0.0)
	if absf(goal_x - position.x) < 6.0 or state_t > 6.0:
		set_state("intro")
		level.boss_intro(self)


func on_phase(_p: int) -> void:
	level.play_sfx("phase", 0.0)
	level.fx.comic(position + Vector2(0, -body_h - 40), "GRRR!", Color("ff4a4a"))


## Default positioning: keep a comfortable distance and drift toward the
## player's depth. Bosses never leave the arena.
func position_tick(dt: float) -> void:
	var p: Fighter = level.player
	var side := 1.0 if position.x >= p.position.x else -1.0
	var goal := p.position + Vector2(side * min_dist, 0)
	_walk_to(goal, dt, 1.0)
	facing = 1 if p.position.x > position.x else -1


func choose_move(_p: Fighter) -> String:
	return ""


func begin(m: String) -> void:
	mv = m
	mv_phase = "tele"
	mv_t = 0.0
	cur_atk = {}
	vel = Vector2.ZERO
	var p: Fighter = level.player
	facing = 1 if p.position.x > position.x else -1
	move_dir = facing
	target_pos = p.position
	set_state("move")
	on_move_begin(m)


func on_move_begin(_m: String) -> void:
	level.play_sfx("warn", -4.0)


func go_phase(ph: String) -> void:
	mv_phase = ph
	mv_t = 0.0


## Ends the move with a vulnerable recovery window.
func recover(t: float) -> void:
	cur_atk = {}
	rec_time = t
	go_phase("rec")


func finish_move() -> void:
	cur_atk = {}
	mv = ""
	mv_phase = ""
	cd = cd_base * (0.8 + rng.randf() * 0.4) * (0.7 if phase >= 3 else 1.0)
	set_state("idle")


func tick_rec() -> void:
	if mv_t >= rec_time:
		finish_move()


func tele(t: float) -> float:
	return t * tele_mult


func vulnerable() -> bool:
	return state == "move" and mv_phase == "rec"


func move_tick(_dt: float) -> void:
	finish_move()


func summon_once(key: String, kinds: Array) -> void:
	if summons_done.has(key):
		return
	summons_done[key] = true
	level.summon(kinds)


func react_to_hit(atk: Dictionary, dir: int) -> void:
	hit_react_t = 0.16
	vel.x = dir * 20.0
	if vulnerable() and rng.randf() < 0.25:
		level.fx.comic(position + Vector2(-dir * 10.0, -body_h * 0.6), "OOF!" if rng.randf() < 0.5 else "MREOW!", Color("ffd23a"))


func on_hit_taken(d: float, a: Dictionary, f: Node2D) -> void:
	level.play_sfx("boss_hit", -2.0, 0.15)
	super(d, a, f)


func on_died() -> void:
	level.on_boss_defeated(self)
	super()


## Red ground zone helper for telegraphs (local coords, facing applied).
func draw_zone(x0: float, x1: float, depth: float, k: float) -> void:
	var a := minf(x0 * facing, x1 * facing)
	var b := maxf(x0 * facing, x1 * facing)
	var r := Rect2(a, -depth, b - a, depth * 2.0)
	draw_rect(r, Color(1, 0.15, 0.1, 0.12 + 0.28 * k))
	draw_rect(r, Color(1, 0.35, 0.25, 0.4 + 0.5 * k), false, 3.0)


func draw_circle_zone(c: Vector2, rx: float, ry: float, k: float) -> void:
	draw_colored_polygon(CatPainter._ellipse(c, rx, ry, 0, 28), Color(1, 0.15, 0.1, 0.12 + 0.25 * k))
	draw_polyline(CatPainter._ellipse(c, rx, ry, 0, 28) + PackedVector2Array([c + Vector2(rx, 0)]), Color(1, 0.35, 0.25, 0.5 + 0.5 * k), 3.0)


func pose() -> Dictionary:
	var p := super()
	if state == "intro":
		p["arm_f"] = Vector2(14, -30)
		p["arm_b"] = Vector2(-10, -26)
		p["mouth"] = "yell"
		p["eyes"] = "angry"
		p["lean"] = -0.15
	if vulnerable():
		p["eyes"] = "dizzy"
		p["mouth"] = "open"
	if hit_react_t > 0.0:
		p["squash"] = Vector2(1.08, 0.94)
	return p


func draw_overlay() -> void:
	if vulnerable() and int(mv_t * 6.0) % 2 == 0:
		var y := -body_h - 30.0 - z
		var w := 70.0
		draw_rect(Rect2(-w * 0.5, y - 12, w, 20), Color(0.1, 0.05, 0.12, 0.7))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-w * 0.5 + 4, y + 3), "OPEN!", HORIZONTAL_ALIGNMENT_CENTER, w - 8, 15, Color("ffd23a"))
