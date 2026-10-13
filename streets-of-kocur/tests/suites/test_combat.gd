extends "res://tests/test_case.gd"
## Hit detection, enemy AI, waves and the archetypes' special rules.


func _jab_at(lv: Node, pad: Pad) -> void:
	pad.press("attack")
	step(lv, 14)


func test_depth_aware_targeting() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.facing = 1
	var same: Node = add_enemy(lv, "brawler", p.position + Vector2(55, 0))
	var deep: Node = add_enemy(lv, "brawler", p.position + Vector2(55, 60))
	var behind: Node = add_enemy(lv, "brawler", p.position + Vector2(-60, 0))
	for e: Node in [same, deep, behind]:
		e.cd = 99.0
	_jab_at(lv, pad)
	check(same.hp < same.max_hp, "enemy in front on the same depth is hit")
	eq(deep.hp, deep.max_hp, "enemy 60 px deeper on the street is not hit")
	eq(behind.hp, behind.max_hp, "enemy behind the cat is not hit")


func test_overlap_math() -> void:
	var atk := {"x0": -4.0, "x1": 62.0, "depth": 18.0, "z0": 15.0, "z1": 85.0}
	var t := {"position": Vector2(150, 500), "z": 0.0, "body_h": 92.0, "hurt_w": 20.0, "depth_r": 8.0}
	var o := Target.new(t)
	check(Fighter.overlaps(Vector2(100, 500), 0.0, 1, atk, o), "in reach")
	check(not Fighter.overlaps(Vector2(100, 500), 0.0, -1, atk, o), "facing away misses")
	check(not Fighter.overlaps(Vector2(100, 530), 0.0, 1, atk, o), "too deep misses")
	check(Fighter.overlaps(Vector2(100, 520), 0.0, 1, atk, o), "inside the depth band hits")
	o.position = Vector2(200, 500)
	check(not Fighter.overlaps(Vector2(100, 500), 0.0, 1, atk, o), "too far misses")
	o.position = Vector2(150, 500)
	o.z = 120.0
	check(not Fighter.overlaps(Vector2(100, 500), 0.0, 1, atk, o), "target high in the air is above the hitbox")
	var rad := {"radial": true, "rx": 125.0, "depth": 48.0, "z0": -10.0, "z1": 120.0}
	o.z = 0.0
	o.position = Vector2(-20, 500)
	check(Fighter.overlaps(Vector2(100, 500), 0.0, 1, rad, o), "radial reaches behind")


class Target:
	var position: Vector2
	var z: float
	var body_h: float
	var hurt_w: float
	var depth_r: float

	func _init(d: Dictionary) -> void:
		position = d["position"]
		z = d["z"]
		body_h = d["body_h"]
		hurt_w = d["hurt_w"]
		depth_r = d["depth_r"]


func test_one_hit_per_activation() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "enforcer", p.position + Vector2(50, 0))
	var atk: Dictionary = p.make_attack(B.MOVES["jab"])
	var hp0: float = e.hp
	for i in 6:
		lv.resolve_attack(p, atk)
	near(e.hp, hp0 - B.MOVES["jab"]["dmg"], 0.01, "a held-out hitbox damages once")
	var atk2: Dictionary = p.make_attack(B.MOVES["jab"])
	e.invuln = 0.0
	lv.resolve_attack(p, atk2)
	near(e.hp, hp0 - 2.0 * B.MOVES["jab"]["dmg"], 0.01, "a new activation can hit again")


func test_full_combo_damage_and_knockdown() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "brawler", p.position + Vector2(60, 0))
	e.cd = 99.0
	for i in 3:
		pad.press("attack")
		step(lv, 10)
	step(lv, 10)
	var expected: float = B.MOVES["jab"]["dmg"] + B.MOVES["swipe"]["dmg"] + B.MOVES["finisher"]["dmg"]
	near(e.max_hp - e.hp, expected, 0.01, "all three combo hits connect")
	check(e.state in ["knock", "down"], "finisher knocks down (%s)" % e.state)
	eq(p.hit_count, 3, "combo counter = 3")


func test_enemies_approach_and_attack() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(300, 40), "approach")
	e.cd = 0.5
	var hp0: float = p.hp
	var attacked := false
	var d0: float = e.position.distance_to(p.position)
	for i in 400:
		step(lv, 1)
		if e.state == "windup":
			attacked = true
		if p.hp < hp0:
			break
	check(e.position.distance_to(p.position) < d0 - 100.0, "punk walked up to the player")
	check(attacked, "punk wound up an attack")
	check(p.hp < hp0, "punk's punch damaged an idle player")


func test_attack_tokens_limit_attackers() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	game().god_mode = true
	var es: Array = []
	for i in 5:
		var e: Node = add_enemy(lv, "punk", p.position + Vector2(200 + i * 20, -60 + i * 30), "approach")
		e.cd = 0.0
		es.append(e)
	var max_busy := 0
	for i in 600:
		step(lv, 1)
		var busy := 0
		for e: Node in es:
			if e.state in ["windup", "attack"] and e.has_token:
				busy += 1
		max_busy = maxi(max_busy, busy)
		check(lv.tokens.size() <= int(game().diff()["attackers"]), "token budget respected") if i % 60 == 0 else null
	check(max_busy >= 1 and max_busy <= 2, "at most 2 melee attackers at once on Normal (saw %d)" % max_busy)


func test_cooldown_between_attacks() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	game().god_mode = true
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(50, 0), "approach")
	e.cd = 0.0
	var starts: Array = []
	var prev := ""
	for i in 600:
		step(lv, 1)
		if e.state == "windup" and prev != "windup":
			starts.append(i)
		prev = e.state
	check(starts.size() >= 2, "punk attacked repeatedly (%d)" % starts.size())
	var min_gap := 9999
	for i in range(1, starts.size()):
		min_gap = mini(min_gap, starts[i] - starts[i - 1])
	check(min_gap >= 50, "gap between attack starts >= 50 frames (min %d)" % min_gap)


func test_dead_enemies_stop() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(60, 0), "windup")
	e.move = e.moves["punch"]
	e.move_name = "punch"
	e.hp = 1.0
	var atk: Dictionary = p.make_attack(B.MOVES["jab"])
	p.facing = 1
	lv.resolve_attack(p, atk)
	check(e.dead, "enemy died")
	var hp0: float = p.hp
	var score0: int = game().score
	step(lv, 200)
	eq(p.hp, hp0, "dead enemy never attacks")
	check(not (e in lv.enemies_list) or not is_instance_valid(e), "dead enemy removed from the level")
	eq(game().score, score0, "no double score for the corpse")
	eq(int(game().attempt["enemies"]), 1, "counted once")


func test_waves_progress_and_cap() -> void:
	var lv: Node = await start_level(0, 0)
	game().god_mode = true
	var bot := Bot.new()
	game().bot_input = bot
	var max_alive := 0
	var cleared := false
	var started := false
	for i in 60 * 120:
		step(lv, 1)
		if lv.enc.current == 0:
			started = true
			max_alive = maxi(max_alive, lv.enc.alive.size())
			check(lv.locked, "arena locked during the fight") if i % 30 == 0 else null
		if started and lv.enc.list[0]["state"] == "cleared":
			cleared = true
			break
	check(started, "first encounter triggered")
	check(cleared, "first encounter cleared by the bot")
	check(max_alive <= lv.enc.MAX_ALIVE, "never more than %d alive (saw %d)" % [lv.enc.MAX_ALIVE, max_alive])
	var total := 0
	for w: Array in lv.data["encounters"][0]["waves"]:
		total += w.size()
	eq(lv.enc.spawned_total, total, "every enemy of every wave spawned exactly once")
	eq(game().checkpoint, 1, "checkpoint advanced")
	check(not lv.locked, "arena unlocked after clearing")
	lv.enc.start(0)
	eq(lv.enc.current, -1, "a cleared encounter never restarts")


func test_thrower_projectile_and_jump_dodge() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	var t: Node = add_enemy(lv, "thrower", p.position + Vector2(260, 0), "approach")
	t.cd = 0.0
	var thrown := false
	for i in 300:
		step(lv, 1)
		if not lv.projectiles.is_empty():
			thrown = true
			break
	check(thrown, "thrower threw a bottle")
	if not thrown:
		return
	var pr: Node = lv.projectiles[0]
	t.cd = 99.0
	var hp0: float = p.hp
	# Jump when the bottle is close.
	for i in 120:
		if is_instance_valid(pr) and absf(pr.position.x - p.position.x) < 90.0 and p.z == 0.0 and p.state != "jump":
			pad.press("jump")
		step(lv, 1)
		if not is_instance_valid(pr) or pr.spent:
			break
	eq(p.hp, hp0, "jumping over the bottle avoids the damage")
	# A second bottle hits a cat that stands still.
	t.cd = 0.0
	p.invuln = 0.0
	var hp1: float = p.hp
	for i in 400:
		step(lv, 1)
		if p.hp < hp1:
			break
	check(p.hp < hp1, "a bottle hits a cat that does not dodge")


func test_enforcer_armor() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "enforcer", p.position + Vector2(60, 0))
	e.cd = 99.0
	lv.resolve_attack(p, p.make_attack(B.MOVES["jab"]))
	check(e.hp < e.max_hp, "jab damages the enforcer")
	check(e.state not in ["hurt", "knock"], "jab does not stagger the enforcer (%s)" % e.state)
	lv.resolve_attack(p, p.make_attack(B.MOVES["finisher"]))
	check(e.state not in ["knock", "down"], "even the finisher does not knock it down")
	lv.resolve_attack(p, p.make_attack(B.MOVES["pawquake"]))
	eq(e.state, "knock", "PAWQUAKE knocks the enforcer down")
	check(not e.can_be_grabbed(), "not grabbable")


func test_runner_and_brawler_behaviour() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	game().god_mode = true
	var r: Node = add_enemy(lv, "runner", p.position + Vector2(300, 0), "approach")
	r.cd = 0.0
	var lunged := false
	for i in 400:
		step(lv, 1)
		if r.move_name == "lunge" and r.state == "attack":
			lunged = true
			break
	check(lunged, "runner lunges")
	r.die(1, {})
	var b: Node = add_enemy(lv, "brawler", p.position + Vector2(55, 0))
	b.cd = 99.0
	lv.resolve_attack(p, p.make_attack(B.MOVES["jab"]))
	check(b.state != "hurt", "brawler shrugs off the first light hit (poise)")
	p.invuln = 0.0
	lv.resolve_attack(p, p.make_attack(B.MOVES["swipe"]))
	lv.resolve_attack(p, p.make_attack(B.MOVES["jab"]))
	check(b.state == "hurt" or b.state == "knock", "brawler flinches after enough hits (%s)" % b.state)


func test_anti_stunlock() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(-50, 0))
	var weak := {"dmg": 0.0, "kb": 10.0, "stun": 0.3, "type": "light", "x0": 0.0, "x1": 80.0, "depth": 20.0}
	for i in 3:
		p.invuln = 0.0
		p.receive_hit(e.make_attack(weak), e)
	eq(p.state, "knock", "the third hit in a row knocks the player down (escape from stun-lock)")
	step(lv, 80)
	check(p.invuln > 0.0 or p.state == "idle", "player gets up with invulnerability")


func test_boss_has_phases_and_telegraphs() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	game().god_mode = true
	var b: Node = lv.spawn_boss("lardpaw")
	b.position = p.position + Vector2(300, 0)
	b.set_state("idle")
	var moves := {}
	var teles := 0
	var prev_phase := ""
	for i in 60 * 40:
		step(lv, 1)
		if b.state == "move" and b.mv_phase == "tele" and prev_phase != "tele":
			teles += 1
			moves[b.mv] = true
		prev_phase = b.mv_phase if b.state == "move" else ""
		if moves.size() >= 3:
			break
	check(moves.size() >= 3, "Lardpaw used 3 different telegraphed attacks: %s" % str(moves.keys()))
	check(teles >= 3, "every attack starts with a telegraph")
	b.hp = b.max_hp * 0.6
	step(lv, 1)
	eq(b.phase, 2, "phase 2 below 66%")
	b.hp = b.max_hp * 0.3
	step(lv, 1)
	eq(b.phase, 3, "phase 3 (food frenzy) below 33%")

