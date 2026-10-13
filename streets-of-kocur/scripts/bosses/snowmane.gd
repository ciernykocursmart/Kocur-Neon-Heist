extends Boss
## GENERAL SNOWMANE, Commander of the White Crown (Level 5).
##  Spear Lunge - long-reach thrust along his lane.
##  Banner Spin - spins the spear around him; dizzy afterwards.
##  Crown Leap  - leaps onto the player's position (shadow marks the landing)
##                and lands with a shock ring (phase 2: plus shockwaves).
##  Call the Guard - at 66% and 33% he roars for two reinforcements.

const Projectile = preload("res://scripts/combat/projectile.gd")

var leap_from := Vector2.ZERO


func on_boss_setup() -> void:
	speed = 120.0
	thresholds = [0.66, 0.33]
	cd_base = 1.0
	min_dist = 150.0


func on_phase(p: int) -> void:
	super(p)
	if p == 2:
		summon_once("p2", ["thrower", "punk<"])
		tele_mult = 0.9
	elif p == 3:
		summon_once("p3", ["enforcer<", "runner"])
		tele_mult = 0.8


func choose_move(p: Fighter) -> String:
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if dx < 110.0 and dy < 40.0 and rng.randf() < 0.6:
		return "spin"
	if dx < 200.0 and dy < 16.0:
		return "lunge"
	if rng.randf() < 0.5:
		return "leap"
	return "" if dy > 16.0 else "lunge"


func on_move_begin(m: String) -> void:
	level.play_sfx("boss_roar" if m == "leap" else "warn", -4.0)


func move_tick(dt: float) -> void:
	match mv:
		"lunge":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.6):
						cur_atk = make_attack({"dmg": 1.0, "x0": 0.0, "x1": 180.0, "depth": 18.0, "z0": 0.0, "z1": 110.0,
							"kb": 240.0, "stun": 0.45, "type": "heavy"}, dmg)
						level.play_sfx("dash", 0.0)
						go_phase("act")
				"act":
					move_by(move_dir * 260.0 * dt, 0.0)
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.14:
						recover(0.7)
				"rec":
					tick_rec()
		"spin":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.7):
						cur_atk = make_attack({"dmg": 0.9, "radial": true, "rx": 140.0, "depth": 40.0, "z0": 0.0, "z1": 130.0,
							"kb": 320.0, "launch": 300.0, "knockdown": true, "type": "heavy"}, dmg)
						level.play_sfx("special", -2.0)
						go_phase("act")
				"act":
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.5:
						level.fx.stars(self, 1.0)
						recover(1.0)
				"rec":
					tick_rec()
		"leap":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.4):
						leap_from = position
						target_pos = level.clamp_to_arena(level.player.position)
						level.play_sfx("jump", 0.0)
						go_phase("act")
				"act":
					var k := clampf(mv_t / 0.9, 0.0, 1.0)
					position = level.constrain(self, position, leap_from.lerp(target_pos, k))
					z = sin(k * PI) * 240.0
					if k >= 1.0:
						z = 0.0
						cur_atk = make_attack({"dmg": 1.0, "radial": true, "rx": 120.0, "depth": 44.0, "z0": -10.0, "z1": 60.0,
							"kb": 300.0, "launch": 300.0, "knockdown": true, "type": "heavy"}, dmg)
						level.resolve_attack(self, cur_atk)
						level.shake(12.0, 0.3)
						level.play_sfx("boss_slam", 0.0)
						level.fx.ring(position, 130.0, Color(1, 0.6, 0.3))
						level.fx.dust(position, 2.0)
						if phase >= 2:
							for d in [-1, 1]:
								var pr := Projectile.new()
								pr.setup_shockwave(level, self, dmg * 0.6, d, 380.0)
								level.add_projectile(pr)
						recover(1.0)
				"rec":
					tick_rec()


func pose() -> Dictionary:
	var p := super()
	p["item_angle"] = 0.2
	if state != "move":
		return p
	match mv:
		"lunge":
			if mv_phase == "tele":
				p["arm_f"] = Vector2(-18, 0)
				p["item_angle"] = 1.57
				p["lean"] = -0.2
			else:
				p["arm_f"] = Vector2(38, -6)
				p["item_angle"] = 1.57
				p["lean"] = 0.4
		"spin":
			var s := mv_t * (6.0 if mv_phase == "tele" else 30.0)
			p["arm_f"] = Vector2(cos(s) * 30.0, -20.0)
			p["item_angle"] = s
		"leap":
			p["crouch"] = 0.7 if mv_phase == "tele" else 0.0
			p["arm_f"] = Vector2(10, -34)
			p["item_angle"] = 0.6
	return p


func draw_overlay() -> void:
	super()
	if state != "move":
		return
	match mv:
		"lunge":
			if mv_phase == "tele":
				draw_zone(0.0, 180.0, 18.0, clampf(mv_t / tele(0.6), 0.0, 1.0))
		"spin":
			if mv_phase == "tele":
				draw_circle_zone(Vector2.ZERO, 140.0, 40.0, clampf(mv_t / tele(0.7), 0.0, 1.0))
		"leap":
			if mv_phase == "act":
				var k := clampf(mv_t / 0.9, 0.0, 1.0)
				draw_circle_zone(target_pos - position, 120.0 * (0.4 + 0.6 * k), 44.0 * (0.4 + 0.6 * k), k)
