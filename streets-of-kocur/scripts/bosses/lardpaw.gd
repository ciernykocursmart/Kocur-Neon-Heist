extends Boss
## LORD LARDPAW, the enormous fat white cat who runs the White Crown gang.
##  Belly Bounce  - wobbles, leaps high, the landing spot is marked on the
##                  ground; lands with a shock ring. Huffs afterwards (open).
##  Rolling Charge - curls into a giant furball, spins up, rolls across the
##                  arena; bounces once in phase 2+; dizzy when he stops.
##  Paw Slam      - raises a paw over a red zone, then slams it.
##  Food Frenzy   - at 33% he stops to gobble a giant drumstick (open!),
##                  spills a fish for the player, then gets faster and cans
##                  rain down around each Belly Bounce landing.
## Phase 2 at 66%: two punks join once; bounce adds shockwaves; rolls bounce.

const Projectile = preload("res://scripts/combat/projectile.gd")

var bounce_from := Vector2.ZERO
var rolls_left := 0
var frenzy := false


func on_boss_setup() -> void:
	speed = 70.0
	thresholds = [0.66, 0.33]
	cd_base = 1.2
	min_dist = 190.0
	kb_mult = 0.1
	depth_r = 22.0


func shadow_rx() -> float:
	return 80.0


func on_phase(p: int) -> void:
	super(p)
	if p == 2:
		summon_once("p2", ["punk", "punk<"])
		tele_mult = 0.95
	elif p == 3:
		if state == "move":
			cur_atk = {}
		z = 0.0
		begin("frenzy")


func choose_move(p: Fighter) -> String:
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if dx < 200.0 and dy < 44.0 and rng.randf() < 0.55:
		return "slam"
	if dy < 70.0 and rng.randf() < 0.45:
		return "roll"
	return "bounce"


func on_move_begin(m: String) -> void:
	match m:
		"bounce":
			level.play_sfx("boss_bounce", -2.0)
		"roll":
			level.play_sfx("boss_roll", 0.0)
			rolls_left = 2 if phase >= 2 else 1
		"slam":
			level.play_sfx("warn", -2.0)
		"frenzy":
			level.play_sfx("boss_roar", 2.0)
			level.fx.comic(position + Vector2(0, -body_h - 30), "FOOD FRENZY!", Color("ff6a2a"))


func move_tick(dt: float) -> void:
	match mv:
		"bounce":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.7):
						bounce_from = position
						target_pos = level.clamp_to_arena(level.player.position)
						level.play_sfx("jump", 0.0, 0.0)
						go_phase("act")
				"act":
					var k := clampf(mv_t / 1.0, 0.0, 1.0)
					position = level.constrain(self, position, bounce_from.lerp(target_pos, k))
					z = sin(k * PI) * 280.0
					if k >= 1.0:
						z = 0.0
						cur_atk = make_attack({"dmg": 1.0, "radial": true, "rx": 165.0, "depth": 58.0, "z0": -10.0, "z1": 50.0,
							"kb": 340.0, "launch": 320.0, "knockdown": true, "type": "heavy"}, dmg)
						level.resolve_attack(self, cur_atk)
						level.shake(16.0, 0.4)
						level.play_sfx("boss_slam", 2.0)
						level.fx.ring(position, 190.0, Color(1, 0.75, 0.4))
						level.fx.dust(position, 2.6)
						if phase >= 2:
							for d in [-1, 1]:
								var pr := Projectile.new()
								pr.setup_shockwave(level, self, dmg * 0.55, d, 360.0)
								level.add_projectile(pr)
						if frenzy:
							_can_rain()
						recover(1.3)
				"rec":
					tick_rec()
		"roll":
			match mv_phase:
				"tele":
					# Line up roughly with the player's lane while spinning up.
					var p: Fighter = level.player
					move_by(0.0, signf(p.position.y - position.y) * minf(absf(p.position.y - position.y), 50.0 * dt))
					if mv_t >= tele(0.9):
						_new_roll_atk()
						go_phase("act")
				"act":
					var old := position.x
					move_by(move_dir * (700.0 if frenzy else 600.0) * dt, 0.0)
					level.resolve_attack(self, cur_atk)
					if mv_t > 0.08 and absf(position.x - old) < 2.0:
						level.shake(10.0, 0.25)
						level.play_sfx("boss_slam", -2.0)
						rolls_left -= 1
						if rolls_left > 0:
							move_dir = -move_dir
							facing = move_dir
							_new_roll_atk()
							mv_t = 0.0
						else:
							level.fx.stars(self, 1.8)
							recover(1.8)
					elif mv_t > 3.0:
						recover(1.0)
				"rec":
					tick_rec()
		"slam":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.75):
						cur_atk = make_attack({"dmg": 1.1, "x0": 20.0, "x1": 175.0, "depth": 40.0, "z0": 0.0, "z1": 120.0,
							"kb": 320.0, "launch": 300.0, "knockdown": true, "type": "heavy"}, dmg)
						level.play_sfx("boss_slam", 0.0)
						level.shake(10.0, 0.25)
						level.fx.dust(position + Vector2(facing * 110.0, 0), 2.2)
						go_phase("act")
				"act":
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.12:
						recover(0.9)
				"rec":
					tick_rec()
		"frenzy":
			match mv_phase:
				"tele":
					# Eating: wide open for punishment. Spills a fish for the player.
					if mv_t >= 1.7:
						frenzy = true
						tele_mult = 0.8
						cd_base = 0.85
						level.spawn_drop("fish", position + Vector2(-facing * 90.0, 20.0))
						level.fx.comic(position + Vector2(0, -body_h - 20), "BURP!", Color("ffd23a"))
						level.play_sfx("meow", 2.0)
						finish_move()


func _new_roll_atk() -> void:
	cur_atk = make_attack({"dmg": 0.9, "radial": true, "rx": 40.0, "depth": 34.0, "z0": 0.0, "z1": 160.0,
		"kb": 360.0, "launch": 300.0, "knockdown": true, "type": "heavy"}, dmg)


func _can_rain() -> void:
	var p: Fighter = level.player
	for i in 4:
		var off := Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(-70.0, 70.0))
		if i == 0:
			off = Vector2.ZERO
		var pr := Projectile.new()
		pr.setup_fall(level, self, dmg * 0.55, level.clamp_to_arena(p.position + off), 0.9 + i * 0.15)
		level.add_projectile(pr)


func vulnerable() -> bool:
	return super() or (state == "move" and mv == "frenzy")


func pose() -> Dictionary:
	var p := super()
	p["belly"] = sin(anim_t * 4.0) * 0.04
	if hit_react_t > 0.0:
		p["belly"] = 0.12
		p["squash"] = Vector2(1.06, 0.95)
	if state != "move":
		return p
	match mv:
		"bounce":
			if mv_phase == "tele":
				p["crouch"] = 0.8
				p["squash"] = Vector2(1.0 + sin(mv_t * 30.0) * 0.05, 1.0 - sin(mv_t * 30.0) * 0.05)
				p["belly"] = 0.1 + sin(mv_t * 30.0) * 0.08
				p["arm_f"] = Vector2(10, -20)
				p["arm_b"] = Vector2(-10, -20)
				p["mouth"] = "yell"
			elif mv_phase == "act":
				p["arm_f"] = Vector2(14, -30)
				p["arm_b"] = Vector2(-14, -30)
				p["eyes"] = "angry"
				p["mouth"] = "open"
				p["leg_f"] = 0.6
				p["leg_b"] = -0.6
				p["lift_f"] = 8.0
		"roll":
			if mv_phase != "rec":
				p["curl"] = 1.0
				p["item_angle"] = anim_t * (25.0 if mv_phase == "act" else 12.0) * move_dir
		"slam":
			if mv_phase == "tele":
				p["arm_f"] = Vector2(10, -48)
				p["lean"] = -0.15
				p["eyes"] = "angry"
				p["mouth"] = "teeth"
			else:
				p["arm_f"] = Vector2(48, 30)
				p["lean"] = 0.2
				p["mouth"] = "open"
		"frenzy":
			var bite := sin(mv_t * 14.0)
			p["arm_f"] = Vector2(14, -18 + bite * 4.0)
			p["mouth"] = "open" if bite > 0.0 else "grin"
			p["eyes"] = "happy"
	if frenzy and not (mv == "roll" and mv_phase != "rec"):
		p["flash"] = Color(1, 0.3, 0.2, 0.18 + 0.1 * sin(anim_t * 10.0))
	return p


func draw_body() -> void:
	var lk := look
	if state == "move" and mv == "frenzy":
		look = look.duplicate()
		look["acc"] = (look["acc"] as Array) + ["drumstick"]
	super()
	look = lk


func draw_overlay() -> void:
	super()
	if state != "move":
		return
	match mv:
		"bounce":
			if mv_phase == "act":
				var k := clampf(mv_t / 1.0, 0.0, 1.0)
				draw_circle_zone(target_pos - position, 165.0 * (0.5 + 0.5 * k), 58.0 * (0.5 + 0.5 * k), k)
		"slam":
			if mv_phase == "tele":
				draw_zone(20.0, 175.0, 40.0, clampf(mv_t / tele(0.75), 0.0, 1.0))
		"roll":
			if mv_phase == "tele":
				var k2 := clampf(mv_t / tele(0.9), 0.0, 1.0)
				draw_line(Vector2.ZERO, Vector2(move_dir * 1000.0, 0), Color(1, 0.3, 0.2, 0.2 + 0.3 * k2), 50.0)
