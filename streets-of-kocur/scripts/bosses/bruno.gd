extends Boss
## BIG BRUNO BOLTPAW, Foreman of the Yard (Level 4 mini-boss).
##  Wrench Slam    - wrench raised high, red zone ahead, then a slam that also
##                   sends a ground shockwave (jump it). Wrench gets stuck: open.
##  Shoulder Charge - scrapes his paw, charges across the arena; dizzy if he
##                   hits the wall.
##  Wrench Sweep   - a quick wide swing when the player hugs him.
## Phase 2 (50%): two runners join once; slams send shockwaves both ways.

const Projectile = preload("res://scripts/combat/projectile.gd")


func on_boss_setup() -> void:
	speed = 85.0
	thresholds = [0.5]
	cd_base = 1.2
	min_dist = 130.0


func on_phase(p: int) -> void:
	super(p)
	if p == 2:
		summon_once("p2", ["runner", "runner<"])
		tele_mult = 0.85


func choose_move(p: Fighter) -> String:
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if dx < 120.0 and dy < 24.0:
		return "sweep" if rng.randf() < 0.45 else "slam"
	if dy < 22.0 and dx > 230.0 and rng.randf() < 0.6:
		return "charge"
	if dx < 200.0 and dy < 30.0:
		return "slam"
	return ""


func on_move_begin(m: String) -> void:
	level.play_sfx("boss_roar" if m == "charge" else "warn", -3.0)


func move_tick(dt: float) -> void:
	match mv:
		"slam":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.8):
						cur_atk = make_attack({"dmg": 1.0, "x0": -10.0, "x1": 135.0, "depth": 30.0, "z0": 0.0, "z1": 120.0,
							"kb": 320.0, "launch": 320.0, "knockdown": true, "type": "heavy"}, dmg)
						level.play_sfx("boss_slam", 0.0)
						level.shake(10.0, 0.25)
						level.fx.dust(position + Vector2(facing * 110.0, 0), 2.0)
						for d in ([facing, -facing] if phase >= 2 else [facing]):
							var pr := Projectile.new()
							pr.setup_shockwave(level, self, dmg * 0.6, d, 400.0)
							level.add_projectile(pr)
						go_phase("act")
				"act":
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.14:
						recover(1.1)
				"rec":
					tick_rec()
		"charge":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.7):
						cur_atk = make_attack({"dmg": 0.9, "x0": -10.0, "x1": 60.0, "depth": 22.0, "z0": 0.0, "z1": 140.0,
							"kb": 360.0, "launch": 300.0, "knockdown": true, "type": "heavy"}, dmg)
						go_phase("act")
				"act":
					var old := position.x
					move_by(move_dir * (620.0 if phase >= 2 else 560.0) * dt, 0.0)
					level.resolve_attack(self, cur_atk)
					if mv_t > 0.08 and absf(position.x - old) < 2.0:
						level.shake(12.0, 0.3)
						level.play_sfx("boss_slam", -2.0)
						level.fx.stars(self, 1.6)
						recover(1.6)
					elif mv_t > 1.8:
						recover(0.6)
				"rec":
					tick_rec()
		"sweep":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.45):
						cur_atk = make_attack({"dmg": 0.7, "x0": -45.0, "x1": 118.0, "depth": 26.0, "z0": 0.0, "z1": 120.0,
							"kb": 260.0, "stun": 0.4, "type": "heavy"}, dmg)
						level.play_sfx("heavy", 0.0)
						go_phase("act")
				"act":
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.12:
						recover(0.6)
				"rec":
					tick_rec()


func pose() -> Dictionary:
	var p := super()
	p["item_angle"] = 0.3
	if state != "move":
		return p
	match mv:
		"slam":
			if mv_phase == "tele":
				p["arm_f"] = Vector2(-6, -40)
				p["item_angle"] = -0.4
				p["lean"] = -0.25
				p["eyes"] = "angry"
			else:
				p["arm_f"] = Vector2(34, 18)
				p["item_angle"] = 2.1
				p["lean"] = 0.35
		"charge":
			p["lean"] = 0.6 if mv_phase == "act" else 0.35
			p["crouch"] = 0.4
			if mv_phase == "tele":
				p["leg_f"] = sin(mv_t * 30.0) * 0.6
			elif mv_phase == "act":
				var s := sin(anim_t * 16.0)
				p["leg_f"] = s * 0.7
				p["leg_b"] = -s * 0.7
		"sweep":
			p["arm_f"] = Vector2(-20, -10) if mv_phase == "tele" else Vector2(38, -4)
			p["item_angle"] = -1.2 if mv_phase == "tele" else 1.4
	return p


func draw_overlay() -> void:
	super()
	if state != "move" or mv_phase != "tele":
		return
	match mv:
		"slam":
			draw_zone(-10.0, 135.0, 30.0, clampf(mv_t / tele(0.8), 0.0, 1.0))
		"sweep":
			draw_zone(-45.0, 118.0, 26.0, clampf(mv_t / tele(0.45), 0.0, 1.0))
		"charge":
			var k := clampf(mv_t / tele(0.7), 0.0, 1.0)
			draw_line(Vector2.ZERO, Vector2(move_dir * 900.0, 0), Color(1, 0.3, 0.2, 0.2 + 0.35 * k), 22.0)
