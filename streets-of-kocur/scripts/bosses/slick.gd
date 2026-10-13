extends Boss
## SLICK WHISKERS, Neon Lieutenant (Level 3).
##  Dash Slash  - crouches with a glint, then dashes along his lane. Panting after.
##  Fishbone Fan - throws 3 (phase 2: 5) fish bones spread over the street depth.
##  Quick Claws - two fast slashes when the player is close.
## Phase 2 (50%): calls two punks once, dashes twice in a row.

const Projectile = preload("res://scripts/combat/projectile.gd")

var dashes_left := 0
var dash_start := 0.0


func on_boss_setup() -> void:
	speed = 170.0
	thresholds = [0.5]
	cd_base = 0.9
	min_dist = 200.0


func on_phase(p: int) -> void:
	super(p)
	if p == 2:
		summon_once("p2", ["punk", "punk<"])


func choose_move(p: Fighter) -> String:
	var dx := absf(p.position.x - position.x)
	var dy := absf(p.position.y - position.y)
	if dx < 95.0 and dy < 16.0:
		return "claws"
	if dy < 26.0 and rng.randf() < 0.55:
		return "dash"
	return "fan" if rng.randf() < 0.7 else "dash"


func on_move_begin(m: String) -> void:
	level.play_sfx("warn" if m != "claws" else "hiss", -4.0)
	if m == "dash":
		dashes_left = 2 if phase >= 2 else 1


func move_tick(dt: float) -> void:
	match mv:
		"dash":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.55 if dashes_left > 1 or phase == 1 else 0.32):
						cur_atk = make_attack({"dmg": 1.0, "x0": -10.0, "x1": 50.0, "depth": 18.0, "z0": 0.0, "z1": 100.0,
							"kb": 300.0, "launch": 280.0, "knockdown": true, "type": "heavy"}, dmg)
						dash_start = position.x
						level.play_sfx("dash", 0.0)
						go_phase("act")
				"act":
					var old := position.x
					move_by(move_dir * 720.0 * dt, 0.0)
					level.resolve_attack(self, cur_atk)
					if absf(position.x - dash_start) > 640.0 or (mv_t > 0.05 and absf(position.x - old) < 2.0) or mv_t > 1.2:
						dashes_left -= 1
						if dashes_left > 0:
							var p: Fighter = level.player
							facing = 1 if p.position.x > position.x else -1
							move_dir = facing
							go_phase("tele")
						else:
							recover(0.95)
				"rec":
					tick_rec()
		"fan":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.5):
						var n := 5 if phase >= 2 else 3
						for i in n:
							var dz := (i - (n - 1) * 0.5) * 34.0
							var pr := Projectile.new()
							pr.setup_thrown(level, self, "fishbone", dmg * 0.75, facing, 470.0, dz)
							level.add_projectile(pr)
						level.play_sfx("bottle", -2.0)
						go_phase("act")
				"act":
					if mv_t >= 0.15:
						recover(0.6)
				"rec":
					tick_rec()
		"claws":
			match mv_phase:
				"tele":
					if mv_t >= tele(0.28):
						cur_atk = make_attack({"dmg": 0.7, "x0": -6.0, "x1": 72.0, "depth": 18.0, "z0": 0.0, "z1": 100.0,
							"kb": 110.0, "stun": 0.3, "type": "light"}, dmg)
						level.play_sfx("swipe", 0.0)
						go_phase("act")
				"act":
					level.resolve_attack(self, cur_atk)
					if mv_t >= 0.1:
						if cur_atk.get("second", false):
							recover(0.55)
						else:
							cur_atk = make_attack({"dmg": 0.7, "x0": -6.0, "x1": 76.0, "depth": 18.0, "z0": 0.0, "z1": 100.0,
								"kb": 220.0, "launch": 220.0, "knockdown": true, "type": "heavy", "second": true}, dmg)
							mv_t = -0.12
				"rec":
					tick_rec()


func pose() -> Dictionary:
	var p := super()
	if state != "move":
		return p
	match mv:
		"dash":
			if mv_phase == "tele":
				p["crouch"] = 0.7
				p["lean"] = 0.45
				p["arm_f"] = Vector2(-8, 10)
				p["eyes"] = "angry"
			elif mv_phase == "act":
				p["lean"] = 0.7
				p["arm_f"] = Vector2(40, -4)
				p["arm_b"] = Vector2(-30, 4)
				p["leg_b"] = -1.1
				p["lift_b"] = 16.0
		"fan":
			p["arm_f"] = Vector2(-18, -28) if mv_phase == "tele" else Vector2(34, -10)
		"claws":
			p["arm_f"] = Vector2(36, -10) if mv_phase == "act" else Vector2(-12, 0)
			p["arm_b"] = Vector2(28, 4) if mv_phase == "act" and cur_atk.get("second", false) else Vector2(-14, 8)
	return p


func draw_overlay() -> void:
	super()
	if state == "move" and mv == "dash" and mv_phase == "tele":
		var k := clampf(mv_t / tele(0.55), 0.0, 1.0)
		draw_line(Vector2(0, 0), Vector2(move_dir * 640.0, 0), Color(1, 0.3, 0.8, 0.25 + 0.35 * k), 16.0)
		PickupArt._sparkle(self, Vector2(facing * 22.0 * scale_k, -86.0 * scale_k), 5.0 + 3.0 * sin(mv_t * 30.0), Color(1, 1, 1))
	if state == "move" and mv == "fan" and mv_phase == "tele":
		var n := 5 if phase >= 2 else 3
		var k2 := clampf(mv_t / tele(0.5), 0.0, 1.0)
		for i in n:
			var dz := (i - (n - 1) * 0.5) * 34.0
			draw_line(Vector2(facing * 40.0, dz), Vector2(facing * 300.0, dz), Color(1, 1, 1, 0.12 + 0.2 * k2), 4.0)
