extends "res://tests/test_case.gd"
## Player controller: running, jumping, ground detection, pounce, damage,
## invulnerability, death and respawn. Runs inside real level 1-1.

const M := preload("res://scripts/player/movement.gd")
const Reach := preload("res://tests/level_reach.gd")


func test_spawns_on_ground() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	check(p != null, "player exists")
	check(p.is_on_floor(), "player lands on the ground")
	eq(p.hp, p.max_hp, "full health at start")
	check(lvl.exit_door != null, "level has an exit door")


func test_run_left_and_right() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var x0 := p.global_position.x
	await hold("move_right", 40)
	gt(p.global_position.x - x0, 40.0, "moved right")
	near(p.velocity.x, M.RUN_SPEED, 30.0, "reached run speed")
	await frames(20)
	near(p.velocity.x, 0.0, 1.0, "decelerates to a stop")
	var x1 := p.global_position.x
	await hold("move_left", 25)
	lt(p.global_position.x, x1 - 15.0, "moved left")
	eq(p.facing, -1, "faces left")


func test_jump_height_and_landing() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var y0 := p.global_position.y
	press("jump")
	var top := y0
	var airborne := false
	for i in 80:
		await frames(1)
		top = minf(top, p.global_position.y)
		if not p.is_on_floor():
			airborne = true
		elif airborne:
			break
	release("jump")
	check(airborne, "left the ground")
	near(y0 - top, 60.0, 6.0, "full jump apex is about 60 px (3.75 tiles)")
	check(p.is_on_floor(), "landed again")
	near(p.global_position.y, y0, 1.0, "landed at the same height")
	eq(p.stats["jumps"], 1, "exactly one jump counted while holding the button")


func test_short_hop_is_lower() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var y0 := p.global_position.y
	await hold("jump", 4)
	var top := y0
	for i in 50:
		await frames(1)
		top = minf(top, p.global_position.y)
	lt(y0 - top, 40.0, "tapping jump gives a short hop (variable height)")
	gt(y0 - top, 8.0, "short hop still leaves the ground")


func test_jump_buffer_and_coyote() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	# Coyote: walk off the 1-1 ledge at x=64 (top row 14) and jump a few frames late.
	await place_player(lvl, Vector2i(63, 13))
	press("move_right")
	var left_ground := -1
	for i in 40:
		await frames(1)
		if not p.is_on_floor():
			left_ground = i
			break
	check(left_ground >= 0, "walked off the ledge")
	await frames(3)
	press("jump")
	await frames(2)
	release("jump")
	release("move_right")
	lt(p.velocity.y, -100.0, "jump still allowed just after leaving the ledge (coyote time)")
	for i in 120:
		await frames(1)
		if p.is_on_floor():
			break
	await frames(10)
	# Buffer: press jump while still falling, a few pixels above the floor.
	var floor_y := p.global_position.y
	press("jump")
	await frames(30)
	release("jump")
	var buffered := false
	var pressed := false
	for i in 120:
		await frames(1)
		if not pressed and p.velocity.y > 0 and floor_y - p.global_position.y < 12.0:
			press("jump")
			await frames(1)
			release("jump")
			pressed = true
			continue
		if pressed and p.velocity.y < -100.0:
			buffered = true
			break
	check(pressed, "reached the moment just before landing")
	check(buffered, "jump pressed just before landing is buffered")


func test_no_double_jump() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	await hold("jump", 10)
	var vy_after := p.velocity.y
	await hold("jump", 2)
	await frames(1)
	check(p.velocity.y >= vy_after, "second jump in the air does nothing")
	eq(p.stats["jumps"], 1, "only one jump counted")


func test_pounce_and_cooldown() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var x0 := p.global_position.x
	await hold("pounce", 2)
	eq(p.state, p.State.POUNCE, "pounce started")
	await frames(14)
	gt(p.global_position.x - x0, 40.0, "pounce dashes forward")
	check(not p.combat.pounce_ready(), "pounce on cooldown right after")
	await hold("pounce", 2)
	eq(p.stats["pounces"], 1, "pounce cannot be spammed during cooldown")
	await frames(int(Progress.pounce_cooldown() * 60) + 5)
	check(p.combat.pounce_ready(), "pounce ready after cooldown")
	await hold("pounce", 2)
	eq(p.stats["pounces"], 2, "second pounce after cooldown")


func test_upward_pounce() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var y0 := p.global_position.y
	press("move_up")
	await hold("pounce", 2)
	release("move_up")
	var top := y0
	for i in 20:
		await frames(1)
		top = minf(top, p.global_position.y)
	gt(y0 - top, 30.0, "holding up makes the pounce rise")


func test_damage_iframes_and_knockback() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var hp: int = p.hp
	check(p.hurt(2, p.global_position + Vector2(20, 0)), "hit lands")
	eq(p.hp, hp - 2, "lost one heart")
	lt(p.velocity.x, 0.0, "knocked back away from the source")
	check(p.is_invulnerable(), "invulnerable after a hit")
	check(not p.hurt(2, p.global_position + Vector2(20, 0)), "second hit ignored during i-frames")
	eq(p.hp, hp - 2, "no damage during i-frames")
	await frames(int(p.INVULN_TIME * 60) + 4)
	check(not p.is_invulnerable(), "i-frames end")
	check(p.hurt(1, p.global_position), "can be hurt again")
	eq(p.hp, hp - 3, "half a heart lost")


func test_shield_blocks_a_hit() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	p.add_shield(1)
	var hp: int = p.hp
	p.hurt(2, p.global_position)
	eq(p.hp, hp, "shield absorbed the hit")
	eq(p.shield, 0, "shield used up")


func test_heal_capped() -> void:
	var lvl := await spawn_level("1-1")
	await frames(10)
	var p: CharacterBody2D = lvl.player
	p.hurt(4, p.global_position)
	p.heal(100)
	eq(p.hp, p.max_hp, "healing never exceeds max health")


func test_death_and_respawn_at_checkpoint() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	var cp: Node2D = lvl.checkpoints[0]
	p.global_position = cp.global_position + Vector2(0, -2)
	await frames(6)
	eq(lvl.current_checkpoint, cp, "touching a lantern activates the checkpoint")
	var died := [false]
	p.died.connect(func() -> void: died[0] = true)
	p.global_position = lvl.start_position
	await frames(3)
	p.hurt(999, p.global_position, true)
	check(died[0], "died signal")
	check(p.is_dead(), "player is dead")
	check(not p.is_controllable(), "no control while dead")
	await frames(90)
	check(lvl.overlays.state == "death", "death screen shown")
	check(tree.paused, "game paused on the death screen")
	tree.paused = false
	lvl.overlays._close()
	lvl.retry_from_checkpoint()
	await frames(3)
	check(not p.is_dead(), "alive after retry")
	eq(p.hp, p.max_hp, "full health after respawn")
	near(p.global_position.x, cp.respawn_position().x, 2.0, "respawned at the checkpoint")
	eq(lvl.deaths, 1, "death counted")


func test_hazard_resets_to_safe_ground() -> void:
	var lvl := await spawn_level("1-1")
	await frames(20)
	var p: CharacterBody2D = lvl.player
	await place_player(lvl, Vector2i(24, 16))
	await frames(30)
	var safe: Vector2 = p.safe_position
	var hp: int = p.hp
	p.global_position = Vector2(26 * 16 + 8, 21 * 16)  # into the spike pit
	await frames(40)
	lt(p.hp, hp, "spikes hurt")
	check(not p.is_dead(), "spikes alone do not kill a healthy cat")
	near(p.global_position.x, safe.x, 24.0, "returned to the last safe ground")


func test_drop_through_oneway() -> void:
	var lvl := await spawn_level("1-1")
	await frames(10)
	var p: CharacterBody2D = lvl.player
	await place_player(lvl, Vector2i(69, 14))  # one-way platform at row 15
	await frames(10)
	check(p.is_on_floor(), "standing on the thin platform")
	var y0 := p.global_position.y
	press("move_down")
	await hold("jump", 2)
	await frames(20)
	release("move_down")
	gt(p.global_position.y, y0 + 20.0, "down + jump drops through the platform")


## A small test map: floor, then a 3-tile step and (far right) a 4-tile wall.
const STEP_MAP := """
########################################
#                                      #
#                                      #
#                                      #
#                                      #
#                                  ####
#                                  ####
#                ####              ####
#                ####              ####
# P              ####              ####
########################################
"""


func _try_climb(lvl: Node, start: Vector2i) -> int:
	var p: CharacterBody2D = lvl.player
	await place_player(lvl, start)
	press("move_right")
	press("jump")
	var airborne := false
	for i in 70:
		await frames(1)
		if not p.is_on_floor():
			airborne = true
		elif airborne:
			break
	release("jump")
	release("move_right")
	await frames(10)
	return int(p.global_position.y - 1) / 16


func test_validator_matches_real_jump() -> void:
	# The reachability validator simulates jumps; it must agree with the real cat
	# on what is climbable: a 3-tile step yes, a 4-tile wall no.
	var r := Reach.new()
	r.setup(STEP_MAP.strip_edges())
	r.analyze(false)
	check(r.nodes.has(Vector2i(17, 6)), "validator: 3-tile step is climbable")
	check(not r.nodes.has(Vector2i(36, 4)), "validator: 4-tile wall is not climbable")
	await clear_scene()
	tree.root.get_node("Transition").next_level_id = "1-1"
	var lvl: Node = load("res://scenes/level.tscn").instantiate()
	lvl.map_override = STEP_MAP.strip_edges()
	tree.root.add_child(lvl)
	tree.current_scene = lvl
	await frames(10)
	eq(await _try_climb(lvl, Vector2i(15, 9)), 6, "real cat climbs the 3-tile step")
	var row := await _try_climb(lvl, Vector2i(33, 9))
	check(row > 4, "real cat cannot climb the 4-tile wall (ended on row %d)" % row)
	var p: CharacterBody2D = lvl.player
	var y0 := p.global_position.y
	var top := y0
	press("jump")
	for i in 60:
		await frames(1)
		top = minf(top, p.global_position.y)
	release("jump")
	gt(y0 - top, 48.0 + 8.0, "full jump clears 3 tiles with at least 8 px to spare")
	lt(y0 - top, 64.0, "full jump cannot clear 4 tiles")
