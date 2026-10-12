extends "res://tests/test_case.gd"
## Claw and pounce damage, cooldowns, enemy defeat, guard blocking,
## enemy attacks, projectile cleanup.

const ARENA := """
##############################
#                            #
#                            #
#                            #
#                            #
# P  %s                      #
##############################
"""


func _arena(enemy: String) -> Node:
	return await spawn_map(ARENA.replace("%s", enemy))


func _first_enemy(lvl: Node) -> Node:
	var es := enemies_of(lvl)
	return es[0] if es.size() > 0 else null


func _stand_next_to(lvl: Node, e: Node2D, dist := 18.0) -> void:
	var p: CharacterBody2D = lvl.player
	p.global_position = Vector2(e.global_position.x - dist, e.global_position.y)
	p.facing = 1
	p.invuln = 99.0  # isolate the test from contact damage
	await frames(2)


func test_claw_damages_once_per_swing() -> void:
	var lvl := await _arena("s")
	var e: Node = _first_enemy(lvl)
	check(e != null, "scout spawned")
	e.set_physics_process(false)
	await _stand_next_to(lvl, e)
	var hp0: int = e.hp
	await hold("attack", 2)
	await frames(20)
	eq(e.hp, hp0 - Progress.claw_damage(), "one swing deals claw damage exactly once")
	eq(lvl.player.stats["attacks"], 1, "one swing")


func test_attack_cooldown() -> void:
	var lvl := await _arena("")
	var p: CharacterBody2D = lvl.player
	await frames(10)
	await hold("attack", 1)
	await frames(2)
	await hold("attack", 1)
	await frames(3)
	eq(p.stats["attacks"], 1, "second press during cooldown does not swing")
	await frames(30)
	await hold("attack", 1)
	await frames(2)
	eq(p.stats["attacks"], 2, "swing again after cooldown")


func test_enemy_defeat_stops_it() -> void:
	var lvl := await _arena("s")
	var e: Node = _first_enemy(lvl)
	var defeated := [false]
	e.defeated.connect(func(_x: Node) -> void: defeated[0] = true)
	var enemies0: int = Progress.data["stats"]["enemies"]
	var hits := 0
	while is_instance_valid(e) and e.hp > 0 and hits < 20:
		e.take_hit(Progress.claw_damage(), e.global_position - Vector2(10, 0), "claw")
		hits += 1
	check(defeated[0], "defeated signal")
	eq(e.state, e.S.DEAD, "enemy in DEAD state")
	eq(e.collision_layer, 0, "dead enemy no longer collides")
	check(not e.take_hit(5, Vector2.ZERO), "dead enemy cannot be hit again")
	eq(Progress.data["stats"]["enemies"], enemies0 + 1, "kill counted once")
	var p: CharacterBody2D = lvl.player
	p.invuln = 0.0
	p.global_position = e.global_position
	var hp: int = p.hp
	await frames(10)
	eq(p.hp, hp, "dead enemy deals no contact damage")
	await frames(90)
	check(not is_instance_valid(e), "dead enemy is removed from the scene")


func test_contact_damage_hurts_player() -> void:
	var lvl := await _arena("s")
	var e: Node = _first_enemy(lvl)
	var p: CharacterBody2D = lvl.player
	await frames(5)
	var hp: int = p.hp
	p.global_position = e.global_position
	await frames(3)
	lt(p.hp, hp, "touching an enemy hurts")


func test_pounce_damages_and_bounces() -> void:
	var lvl := await _arena("B")
	var e: Node = _first_enemy(lvl)
	e.set_physics_process(false)
	await _stand_next_to(lvl, e, 40.0)
	var hp0: int = e.hp
	await hold("pounce", 2)
	await frames(15)
	eq(e.hp, hp0 - Progress.pounce_damage(), "pounce deals pounce damage")
	gt(Progress.pounce_damage(), Progress.claw_damage(), "pounce hits harder than a claw")


func test_guard_blocks_front_claw_not_back() -> void:
	var lvl := await _arena("G")
	var e: Node = _first_enemy(lvl)
	e.set_physics_process(false)
	e.facing = -1  # facing the player on its left
	var hp0: int = e.hp
	check(not e.take_hit(2, e.global_position + Vector2(-20, 0), "claw"), "front claw blocked")
	eq(e.hp, hp0, "no damage through the shield")
	check(e.take_hit(2, e.global_position + Vector2(20, 0), "claw"), "claw from behind lands")
	check(e.take_hit(3, e.global_position + Vector2(-20, 0), "pounce"), "pounce through the shield lands")
	eq(e.hp, hp0 - 5, "damage from behind and pounce applied")


func test_guard_telegraphs_before_attacking() -> void:
	var lvl := await _arena("G")
	var e: Node = _first_enemy(lvl)
	var p: CharacterBody2D = lvl.player
	p.invuln = 99.0
	p.global_position = e.global_position + Vector2(-30, 0)
	var saw_windup := false
	var windup_before_attack := false
	for i in 180:
		await frames(1)
		if e.state == e.S.WINDUP:
			saw_windup = true
		if e.state == e.S.ATTACK:
			windup_before_attack = saw_windup
			break
	check(saw_windup, "guard winds up")
	check(windup_before_attack, "wind-up always precedes the thrust")


func test_archer_shoots_and_projectiles_expire() -> void:
	var lvl := await _arena("     A")
	var p: CharacterBody2D = lvl.player
	p.invuln = 99.0
	var seen := 0
	for i in 300:
		await frames(1)
		seen = maxi(seen, lvl.projectiles.get_child_count())
		if seen > 0:
			break
	gt(seen, 0, "archer fired at the player")
	var proj: Node = lvl.projectiles.get_child(0)
	await frames(int(proj.lifetime * 60) + 30)
	check(not is_instance_valid(proj), "arrow removed after its lifetime / impact")


func test_projectile_hits_player_once() -> void:
	var lvl := await _arena("")
	var p: CharacterBody2D = lvl.player
	await frames(10)
	var hp: int = p.hp
	var proj: Node = load("res://scripts/enemies/projectile.gd").new()
	proj.level = lvl
	proj.velocity = Vector2(-60, 0)
	proj.damage = 2
	proj.position = p.global_position + Vector2(40, -8)
	lvl.add_projectile(proj)
	await frames(60)
	eq(p.hp, hp - 2, "projectile dealt its damage once")
	check(not is_instance_valid(proj), "projectile destroyed on hit")


func test_claw_deflects_projectiles() -> void:
	var lvl := await _arena("")
	var p: CharacterBody2D = lvl.player
	await frames(10)
	p.facing = 1
	var proj: Node = load("res://scripts/enemies/projectile.gd").new()
	proj.level = lvl
	proj.velocity = Vector2(-40, 0)
	proj.position = p.global_position + Vector2(30, -8)
	lvl.add_projectile(proj)
	var hp: int = p.hp
	await frames(8)
	await hold("attack", 2)
	await frames(30)
	eq(p.hp, hp, "deflected projectile does not hurt")


func test_clear_projectiles() -> void:
	var lvl := await _arena("")
	for i in 5:
		var proj: Node = load("res://scripts/enemies/projectile.gd").new()
		proj.level = lvl
		proj.velocity = Vector2(0, 0)
		proj.lifetime = 30.0
		proj.position = Vector2(200 + i * 10, 40)
		lvl.add_projectile(proj)
	await frames(2)
	eq(lvl.projectiles.get_child_count(), 5, "projectiles added")
	lvl.clear_projectiles()
	await frames(2)
	eq(lvl.projectiles.get_child_count(), 0, "all projectiles cleared")


func test_every_enemy_type_can_be_defeated() -> void:
	for ch in ["s", "G", "A", "W", "B"]:
		var lvl := await _arena(ch)
		var e: Node = _first_enemy(lvl)
		lvl.player.invuln = 999.0
		check(e != null, "enemy %s spawned" % ch)
		var hits := 0
		while is_instance_valid(e) and e.state != e.S.DEAD and hits < 40:
			e.take_hit(Progress.pounce_damage(), e.global_position + Vector2(-e.facing * 12, 0), "pounce")
			hits += 1
			await frames(1)
		check(e.state == e.S.DEAD, "%s (%s) defeated in %d pounces" % [ch, e.display_name, hits])
		lt(hits, 10, "%s needs a fair number of hits" % e.display_name)


func test_enemies_ramp_up() -> void:
	var lvl := await _arena("s")
	var scout_hp: int = _first_enemy(lvl).max_hp
	lvl = await _arena("B")
	var beast_hp: int = _first_enemy(lvl).max_hp
	gt(beast_hp, scout_hp, "the late-game beast is much tougher than the first scout")
