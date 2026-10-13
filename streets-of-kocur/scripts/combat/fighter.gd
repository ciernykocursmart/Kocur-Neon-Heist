class_name Fighter
extends Node2D
## Base class for everything that fights: the player, gang cats and bosses.
##
## Positioning model (pseudo-3D street):
##   position.x = horizontal position, position.y = depth on the street
##   (the node is y-sorted by it), z = height above the ground (jumps, knock-ups).
## The sprite is drawn at (0, -z); the shadow and all hit tests use the
## ground position, so art, shadow and hitboxes always line up.
##
## The Level calls tick(dt) on every fighter in a fixed order each physics
## frame; nothing moves on its own, which keeps combat deterministic.

signal defeated(f: Fighter)

const B = preload("res://scripts/data/balance.gd")
const Looks = preload("res://scripts/data/looks.gd")

var level: Node  ## the Level scene root
var team := "enemy"
var kind := ""
var max_hp := 100.0
var hp := 100.0
var z := 0.0
var vz := 0.0
var vel := Vector2.ZERO
var facing := 1
var state := "idle"
var state_t := 0.0
var anim_t := 0.0
var hurt_w := 22.0  ## half-width of the hurtbox
var body_h := 95.0  ## hurtbox height above z
var depth_r := 8.0  ## depth thickness of the body
var invuln := 0.0
var flash_t := 0.0
var flash_color := Color(1, 1, 1)
var dead := false
var armor := 0  ## 0: flinches, 1: only heavy/special hits stagger, 2: never staggered
var kb_mult := 1.0
var scale_k := 1.0
var look := {}
var gravity := 1700.0
var stun := 0.3
var down_time := 0.65
var getup_invuln := 0.25
var cur_atk := {}  ## the attack currently active, see make_attack()
var chain_hits := 0  ## consecutive hits without a knock-down (anti stun-lock)
var chain_t := 0.0
var held_by: Fighter = null
var blink := false  ## draw blinking (invulnerable)
var last_hit_from := 1

static var _atk_id := 0


func setup_look(look_kind: String, s: float) -> void:
	look = Looks.get_look(look_kind)
	scale_k = s


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


func is_airborne() -> bool:
	return z > 0.5


func is_knocked() -> bool:
	return state in ["knock", "down", "getup"]


## Creates one activation of an attack. Every activation has a unique id and
## its own hit list, so a hitbox damages each target at most once.
func make_attack(move: Dictionary, dmg_mult := 1.0) -> Dictionary:
	_atk_id += 1
	var a := move.duplicate()
	a["id"] = _atk_id
	a["dmg"] = float(move.get("dmg", 5.0)) * dmg_mult
	a["hit"] = []
	a["owner"] = self
	return a


## Common timers; subclasses call this first in tick().
func tick_common(dt: float) -> void:
	state_t += dt
	anim_t += dt
	invuln = maxf(0.0, invuln - dt)
	flash_t = maxf(0.0, flash_t - dt)
	if chain_t > 0.0:
		chain_t -= dt
		if chain_t <= 0.0:
			chain_hits = 0


func tick(_dt: float) -> void:
	pass


func can_be_hit() -> bool:
	return not dead and invuln <= 0.0 and not state in ["down", "getup", "dead", "thrown"] and held_by == null


## Hit test for a (non-radial) attack against this fighter's hurtbox. Uses
## the ground position: x overlap in the attacker's facing direction, depth
## within the attack's depth band, and overlapping heights.
static func overlaps(apos: Vector2, az: float, afacing: int, atk: Dictionary, t) -> bool:
	var tpos: Vector2 = t.position
	var dy: float = absf(tpos.y - apos.y)
	if dy > float(atk.get("depth", 18.0)) + t.depth_r:
		return false
	var h0: float = az + float(atk.get("z0", 0.0))
	var h1: float = az + float(atk.get("z1", 90.0))
	if t.z > h1 or t.z + t.body_h < h0:
		return false
	if atk.get("radial", false):
		return absf(t.position.x - apos.x) <= float(atk.get("rx", 100.0)) + t.hurt_w
	var x0: float = apos.x + afacing * float(atk.get("x0", 0.0))
	var x1: float = apos.x + afacing * float(atk.get("x1", 60.0))
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	return t.position.x + t.hurt_w >= lo and t.position.x - t.hurt_w <= hi


## Applies a hit. Returns true if it landed.
func receive_hit(atk: Dictionary, from: Node2D) -> bool:
	if not can_be_hit():
		return false
	var dmg: float = float(atk.get("dmg", 0.0))
	var dir := int(signf(position.x - from.position.x))
	if dir == 0:
		dir = int(from.get("facing")) if from.get("facing") != null else 1
	last_hit_from = dir
	hp = maxf(0.0, hp - dmg)
	flash_t = 0.14
	chain_hits += 1
	chain_t = 0.9
	on_hit_taken(dmg, atk, from)
	if hp <= 0.0:
		die(dir, atk)
		return true
	react_to_hit(atk, dir)
	return true


func on_hit_taken(_dmg: float, _atk: Dictionary, _from: Node2D) -> void:
	pass


func react_to_hit(atk: Dictionary, dir: int) -> void:
	var heavy: bool = atk.get("knockdown", false)
	var kb: float = float(atk.get("kb", 60.0))
	var strong: bool = String(atk.get("type", "light")) in ["special", "throw", "hazard"]
	if armor >= 2:
		vel.x = dir * kb * 0.08 * kb_mult
		return
	if armor == 1 and not strong:
		vel.x = dir * kb * 0.2 * kb_mult
		return
	if heavy or chain_hits >= 5:
		knock_down(dir, maxf(kb, 220.0), float(atk.get("launch", 260.0)))
	else:
		hurt(dir, kb, float(atk.get("stun", 0.3)))


func hurt(dir: int, kb: float, stun_time: float) -> void:
	cur_atk = {}
	facing = -dir
	vel = Vector2(dir * kb * kb_mult, 0)
	stun = stun_time
	set_state("hurt")


func knock_down(dir: int, kb: float, launch: float) -> void:
	cur_atk = {}
	chain_hits = 0
	facing = -dir
	vel = Vector2(dir * kb * kb_mult, 0)
	vz = launch
	z = maxf(z, 1.0)
	set_state("knock")


func die(dir: int, atk: Dictionary) -> void:
	dead = true
	cur_atk = {}
	knock_down(dir, maxf(float(atk.get("kb", 200.0)), 260.0), maxf(float(atk.get("launch", 300.0)), 300.0))
	on_died()
	defeated.emit(self)


func on_died() -> void:
	pass


## Shared physics for hurt / knocked / down / getting up. Returns true while
## the fighter is busy with one of those states.
func tick_reactions(dt: float) -> bool:
	match state:
		"hurt":
			vel.x = move_toward(vel.x, 0.0, 1400.0 * dt)
			move_by(vel.x * dt, 0.0)
			if state_t >= stun:
				vel = Vector2.ZERO
				set_state("idle")
			return true
		"knock":
			z += vz * dt
			vz -= gravity * dt
			move_by(vel.x * dt, 0.0)
			if z <= 0.0:
				z = 0.0
				vz = 0.0
				vel.x *= 0.35
				on_landed_hard()
				set_state("down")
			return true
		"down":
			vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
			move_by(vel.x * dt, 0.0)
			if dead:
				return true
			if state_t >= down_time:
				set_state("getup")
			return true
		"getup":
			if state_t >= 0.32:
				invuln = maxf(invuln, getup_invuln)
				set_state("idle")
			return true
	return false


func on_landed_hard() -> void:
	if level:
		level.fx.dust(position, 1.2)
		level.play_sfx("land", -4.0)


## Moves on the street plane and lets the level resolve bounds/obstacles.
func move_by(dx: float, dy: float) -> void:
	var old := position
	position += Vector2(dx, dy)
	if level:
		position = level.constrain(self, old, position)


func shadow_rx() -> float:
	return hurt_w * 1.3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	CatPainter.draw_shadow(self, shadow_rx(), z)
	if blink and int(anim_t * 20.0) % 2 == 0:
		return
	draw_set_transform(Vector2(0, -z), 0.0, Vector2(facing * scale_k, scale_k))
	draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_overlay()


func draw_body() -> void:
	var p := pose()
	if flash_t > 0.0:
		p["flash"] = Color(flash_color.r, flash_color.g, flash_color.b, 0.75)
	CatPainter.draw_cat(self, look, p)


## Drawn without the body transform (telegraph marks, icons over the head).
func draw_overlay() -> void:
	pass


## Default pose: idle breathing, walk cycle, hurt and knocked-down poses.
func pose() -> Dictionary:
	var p := {}
	p["tail"] = anim_t * 3.0
	match state:
		"hurt":
			p["lean"] = -0.35
			p["eyes"] = "hurt"
			p["mouth"] = "open"
			p["arm_f"] = Vector2(-10, 10)
			p["arm_b"] = Vector2(-14, 8)
			p["head_tilt"] = -0.25
		"knock", "down", "dead":
			p["lean"] = -1.35 if state != "knock" else -0.9
			p["crouch"] = 1.0
			p["eyes"] = "x" if dead else "dizzy"
			p["mouth"] = "open"
			p["arm_f"] = Vector2(-16, -8)
			p["arm_b"] = Vector2(-20, -4)
			p["leg_f"] = 1.2
			p["leg_b"] = 0.9
			p["lift_f"] = 10.0
			p["head_tilt"] = -0.6
		"getup":
			p["crouch"] = 1.0 - state_t / 0.32
			p["lean"] = -0.5 * (1.0 - state_t / 0.32)
			p["eyes"] = "hurt"
		"walk", "approach", "reposition", "enter", "retreat", "run":
			var sp := 11.0 if state == "run" else 8.0
			var s := sin(anim_t * sp)
			p["leg_f"] = s * 0.55
			p["leg_b"] = -s * 0.55
			p["lift_f"] = maxf(0.0, s) * 5.0
			p["lift_b"] = maxf(0.0, -s) * 5.0
			p["arm_f"] = Vector2(6 - s * 8, 20)
			p["arm_b"] = Vector2(-4 + s * 8, 20)
			p["squash"] = Vector2(1.0, 1.0 + absf(s) * 0.03)
			p["lean"] = 0.12 if state == "run" else 0.04
		_:
			var b := sin(anim_t * 3.2)
			p["squash"] = Vector2(1.0 + b * 0.015, 1.0 - b * 0.015)
			p["arm_f"] = Vector2(10, 16 + b)
			p["arm_b"] = Vector2(-2, 18 + b)
	return p
