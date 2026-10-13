extends "res://tests/test_case.gd"
## Player controller and moves.


func test_moves_both_axes() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	var start: Vector2 = p.position
	pad.move = Vector2(1, 0)
	step(lv, 30)
	check(p.position.x > start.x + 80.0, "moved right (%.0f)" % (p.position.x - start.x))
	eq(p.facing, 1, "faces right")
	pad.move = Vector2(-1, 0)
	step(lv, 30)
	eq(p.facing, -1, "faces left")
	var y0: float = p.position.y
	pad.move = Vector2(0, 1)
	step(lv, 30)
	check(p.position.y > y0 + 40.0, "moved down the street (%.0f)" % (p.position.y - y0))
	pad.move = Vector2(0, -1)
	step(lv, 200)
	near(p.position.y, lv.ymin, 0.5, "stopped at the back edge of the street")
	pad.move = Vector2(0, 1)
	step(lv, 300)
	near(p.position.y, lv.ymax, 0.5, "stopped at the front edge")


func test_acceleration_and_stop() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	pad.move = Vector2(1, 0)
	step(lv, 1)
	check(p.vel.x > 0.0 and p.vel.x < B.PLAYER["walk_x"], "accelerates (%.0f)" % p.vel.x)
	step(lv, 20)
	near(p.vel.x, B.PLAYER["walk_x"], 1.0, "reaches walk speed")
	pad.move = Vector2.ZERO
	step(lv, 10)
	near(p.vel.x, 0.0, 0.01, "decelerates to a stop")
	eq(p.state, "idle", "idle when stopped")


func test_jump_and_land() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	pad.press("jump")
	step(lv, 10)
	eq(p.state, "jump", "jumping")
	check(p.z > 30.0, "in the air (z=%.0f)" % p.z)
	step(lv, 70)
	eq(p.z, 0.0, "landed")
	check(p.state in ["idle", "land"], "back on the ground (%s)" % p.state)


func test_combo_progression_and_reset() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	pad.press("attack")
	step(lv, 2)
	eq(p.state, "attack", "attack started")
	eq(p.cur_move, "jab", "first hit is the paw jab")
	step(lv, 6)
	pad.press("attack")
	step(lv, 8)
	eq(p.cur_move, "swipe", "second press inside the window -> claw swipe")
	step(lv, 8)
	pad.press("attack")
	step(lv, 6)
	eq(p.cur_move, "finisher", "third press -> heavy finisher")
	# Mashing during the finisher's recovery must not chain into anything.
	for i in 10:
		pad.press("attack")
		step(lv, 2)
	check(p.cur_move == "finisher" or p.cur_move == "jab", "finisher not cancelled into a 4th combo hit")
	step(lv, 60)
	pad.press("attack")
	step(lv, 3)
	eq(p.cur_move, "jab", "combo restarts with the jab after the finisher")
	# Missing the timing window resets the combo.
	step(lv, 30)
	pad.press("attack")
	step(lv, 30)
	eq(p.state, "idle", "jab finished")
	step(lv, 40)
	pad.press("attack")
	step(lv, 3)
	eq(p.cur_move, "jab", "late press restarts the combo instead of continuing it")


func test_special_uses_energy() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.energy = 100.0
	pad.press("special")
	step(lv, 2)
	eq(p.state, "special", "PAWQUAKE started")
	near(p.energy, 50.0, 1.0, "costs one bar (50)")
	check(p.invuln > 0.0, "invulnerable while spinning")
	step(lv, 60)
	p.energy = 20.0
	pad.press("special")
	step(lv, 2)
	check(p.state != "special", "refused without enough energy")
	check(p.energy < 50.0, "energy not spent when refused")


func test_special_hits_many() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	var es: Array = []
	for off in [Vector2(80, 0), Vector2(-80, 0), Vector2(40, 30), Vector2(-40, -30)]:
		es.append(add_enemy(lv, "punk", p.position + off))
	var far: Node = add_enemy(lv, "punk", p.position + Vector2(300, 0))
	p.energy = 100.0
	pad.press("special")
	step(lv, 30)
	for e: Node in es:
		check(e.hp < e.max_hp and e.state in ["knock", "down"], "PAWQUAKE hit and knocked down a nearby cat")
	eq(far.hp, far.max_hp, "far cat untouched")


func test_damage_and_invulnerability() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(50, 0))
	var atk: Dictionary = e.make_attack({"dmg": 10.0, "kb": 50.0, "stun": 0.2, "type": "light"})
	check(p.receive_hit(atk, e), "first hit lands")
	near(p.hp, 90.0, 0.01, "hp reduced by 10")
	check(p.invuln > 0.0, "invulnerable after the hit")
	var atk2: Dictionary = e.make_attack({"dmg": 10.0, "kb": 50.0, "type": "light"})
	check(not p.receive_hit(atk2, e), "second hit during invulnerability is ignored")
	near(p.hp, 90.0, 0.01, "no repeated damage")
	step(lv, 70)
	var atk3: Dictionary = e.make_attack({"dmg": 10.0, "kb": 50.0, "type": "light"})
	check(p.receive_hit(atk3, e), "hit lands again after invulnerability ends")


func test_knockback_and_recovery() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	var e: Node = add_enemy(lv, "brawler", p.position + Vector2(50, 0))
	var x0: float = p.position.x
	p.receive_hit(e.make_attack({"dmg": 5.0, "kb": 300.0, "launch": 300.0, "knockdown": true, "type": "heavy"}), e)
	eq(p.state, "knock", "knocked down")
	step(lv, 120)
	check(p.position.x < x0 - 20.0, "pushed away from the attacker")
	eq(p.state, "idle", "got back up")
	check(p.invuln > 0.0 or p.state == "idle", "recovered")


func test_death_respawn_restores_control() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	game().lives = 3
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(50, 0))
	p.hp = 3.0
	p.receive_hit(e.make_attack({"dmg": 10.0, "kb": 100.0, "type": "light"}), e)
	check(p.dead, "player died")
	step(lv, 150)
	eq(game().lives, 2, "lost one life")
	check(not p.dead and p.state == "idle", "respawned (%s)" % p.state)
	near(p.hp, p.max_hp, 0.01, "full health after respawn")
	check(p.invuln > 0.5, "respawn invulnerability")
	var x0: float = p.position.x
	pad.move = Vector2(-1, 0)
	step(lv, 20)
	check(p.position.x < x0 - 20.0, "input works after respawn")


func test_last_life_game_over_and_continue() -> void:
	var lv: Node = await arena()
	var p: Node = lv.player
	game().lives = 1
	game().continues_left = 3
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(50, 0))
	p.hp = 1.0
	p.receive_hit(e.make_attack({"dmg": 10.0, "kb": 100.0, "type": "light"}), e)
	step(lv, 150)
	eq(lv.flow, "gameover", "game over")
	check(lv.overlays.root.find_child("GameOver", true, false) != null, "game over screen shown")
	var c: Button = lv.overlays.root.find_child("Continue", true, false)
	check(c != null and not c.disabled, "continue available")
	c.pressed.emit()
	await tree.root.get_node("Transition").finished
	var lv2: Node = tree.current_scene
	check(lv2 != lv and lv2.player != null, "level reloaded")
	eq(game().lives, int(game().diff()["lives"]), "lives restored by the continue")
	eq(game().continues_left, 2, "one continue used")
	lv2.set_physics_process(false)


func test_grab_knee_throw() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(48, 0))
	var other: Node = add_enemy(lv, "punk", p.position + Vector2(220, 0))
	other.cd = 99.0
	pad.press("grab")
	step(lv, 2)
	eq(p.state, "grab", "grabbed")
	check(e.held_by == p, "enemy held")
	step(lv, 10)
	var hp0: float = e.hp
	pad.press("attack")
	step(lv, 2)
	check(e.hp < hp0, "knee damages the held cat")
	step(lv, 10)
	other.position = p.position + Vector2(150, 0)
	other.set_state("hurt")
	other.stun = 2.0
	pad.press("grab")
	step(lv, 2)
	eq(e.state, "thrown", "thrown")
	check(e.held_by == null, "released")
	step(lv, 60)
	check(other.hp < other.max_hp, "thrown cat bowled over its friend")
	check(e.hp < hp0, "thrown cat took landing damage")
	e.die(1, {})
	other.die(1, {})
	step(lv, 30)
	var enf: Node = add_enemy(lv, "enforcer", p.position + Vector2(50 * p.facing, 0))
	p.facing = 1 if enf.position.x > p.position.x else -1
	pad.press("grab")
	step(lv, 3)
	check(p.state != "grab", "enforcers can't be grabbed")


func test_grab_times_out() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(48, 0))
	pad.press("grab")
	step(lv, 2)
	step(lv, 120)
	check(p.state != "grab" and e.held_by == null, "grab released automatically")
	pad.move = Vector2(0, 1)
	var y0: float = p.position.y
	step(lv, 20)
	check(p.position.y > y0, "player free after grab")


func test_jump_kick_and_pounce() -> void:
	var pad := Pad.new()
	var lv: Node = await arena()
	game().bot_input = pad
	var p: Node = lv.player
	p.facing = 1
	var e: Node = add_enemy(lv, "punk", p.position + Vector2(70, 0))
	pad.press("jump")
	step(lv, 6)
	pad.press("attack")
	step(lv, 3)
	eq(p.state, "jump_attack", "flying kick")
	step(lv, 30)
	check(e.hp < e.max_hp, "flying kick hit")
	e.die(1, {})
	step(lv, 120)
	pad.move = Vector2(1, 0)
	pad.run = true
	step(lv, 25)
	eq(p.state, "run", "running")
	pad.press("attack")
	step(lv, 2)
	eq(p.state, "pounce", "running attack = pounce")
