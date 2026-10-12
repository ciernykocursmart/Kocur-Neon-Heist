extends "res://tests/test_case.gd"
## Every level: map structure, physics-based reachability (exit, checkpoints,
## collectibles, no dead ends), loads cleanly, can be completed, and items,
## secrets and rescues are tracked without duplicates.

const LevelCatalog := preload("res://scripts/data/level_catalog.gd")
const LevelGrid := preload("res://scripts/world/level_grid.gd")
const Reach := preload("res://tests/level_reach.gd")


func _grid(id: String) -> RefCounted:
	var g := LevelGrid.new()
	g.parse(LevelCatalog.get_level(id)["map"])
	return g


func test_map_structure() -> void:
	for lv: Dictionary in LevelCatalog.LEVELS:
		var id: String = lv["id"]
		var g := _grid(id)
		eq(g.entities_of("P").size(), 1, "%s has one start" % id)
		eq(g.entities_of("X").size(), 1, "%s has one exit" % id)
		gt(g.entities_of("K").size(), 0, "%s has a checkpoint" % id)
		var has_boss: bool = lv.has("boss")
		eq(g.entities_of("12345").size(), 1 if has_boss else 0, "%s guardian placement" % id)
		if has_boss:
			gt(g.entities_of("!").size(), 0, "%s has an arena trigger" % id)
			check(LevelCatalog.get_level(id)["map"].contains("]"), "%s arena has gates" % id)
		eq(g.entities_of("R").size(), 1 if lv["cat"] != "" else 0, "%s cage count matches its captive" % id)
		var t := LevelCatalog.totals(id)
		if not has_boss or id == "2-3" or id == "3-3" or id == "4-3":
			gt(int(t["coins"]) + int(t["gems"]), 0, "%s has collectibles" % id)
		var signs: int = g.entities_of("?").size()
		var texts: Array = lv.get("signs", [])
		eq(signs, texts.size(), "%s: every sign has its own text" % id)
		for y in g.height:
			check(g.is_solid(0, y) and g.is_solid(g.width - 1, y), "%s side walls closed (row %d)" % [id, y])
			if not (g.is_solid(0, y) and g.is_solid(g.width - 1, y)):
				break


func test_every_level_reachable() -> void:
	for lv: Dictionary in LevelCatalog.LEVELS:
		var id: String = lv["id"]
		var t0 := Time.get_ticks_msec()
		var r := Reach.new()
		r.setup(lv["map"])
		r.analyze(false)
		var exit_cell: Vector2i = r.g.entities_of("X")[0]["cell"]
		check(r.can_interact(exit_cell), "%s: exit reachable without pounce" % id)
		for e in r.g.entities_of("K!l"):
			check(r.can_interact(e["cell"]) or r.can_touch(e["cell"]),
				"%s: %s at %s reachable without pounce" % [id, e["ch"], e["cell"]])
		var dead := r.dead_ends(r.goal_nodes(exit_cell))
		eq(dead.size(), 0, "%s: no spot without a way to the exit (walking/jumping only)" % id)
		var r2 := Reach.new()
		r2.setup(lv["map"])
		r2.analyze(true)
		var missing: Array = []
		for e in r2.g.entities_of("ogTf$R"):
			var c: Vector2i = e["cell"]
			if not r2.can_touch(c) and not r2.can_interact(c):
				missing.append("%s@%s" % [e["ch"], c])
		eq(missing, [], "%s: every collectible, secret and cage reachable" % id)
		eq(r2.dead_ends(r2.goal_nodes(exit_cell)).size(), 0, "%s: no soft-lock spots even with pounce" % id)
		note("%s reachability: %d spots, %d ms" % [id, r.nodes.size(), Time.get_ticks_msec() - t0])


func test_every_level_loads_and_runs() -> void:
	for lv: Dictionary in LevelCatalog.LEVELS:
		var id: String = lv["id"]
		var lvl := await spawn_level(id)
		var g := _grid(id)
		check(lvl.player != null, "%s: player spawned" % id)
		check(lvl.exit_door != null, "%s: exit door built" % id)
		eq(lvl.checkpoints.size(), g.entities_of("K").size(), "%s: checkpoints built" % id)
		eq(lvl.gems_total, g.entities_of("g").size(), "%s: gems counted" % id)
		eq(lvl.secrets_total, int(LevelCatalog.totals(id)["secrets"]), "%s: secrets counted" % id)
		var expected_enemies: int = g.entities_of("sGAWB12345").size()
		eq(lvl.enemies_root.get_child_count(), expected_enemies, "%s: enemies spawned" % id)
		eq(lvl.boss != null, lv.has("boss"), "%s: guardian presence" % id)
		if lv.has("boss"):
			check(lvl.exit_door.locked, "%s: exit locked until the guardian falls" % id)
		lvl.player.invuln = 999.0
		await frames(60)
		check(not lvl.player.is_dead(), "%s: runs a second without the player dying" % id)
		check(lvl.player.global_position.y < g.height * 16, "%s: player stays inside the map" % id)


func _finish(lvl: Node) -> void:
	var p: CharacterBody2D = lvl.player
	p.invuln = 999.0
	p.global_position = lvl.exit_door.global_position + Vector2(0, -2)
	await frames(5)
	await hold("interact", 2)
	await frames(40)


func test_complete_every_level() -> void:
	Progress.new_game()
	for lv: Dictionary in LevelCatalog.LEVELS:
		var id: String = lv["id"]
		var lvl := await spawn_level(id)
		if lv.has("boss"):
			await _finish(lvl)
			check(not lvl.finished, "%s: locked door cannot be used before the guardian falls" % id)
			lvl.player.global_position = Vector2(lvl.boss_trigger_x + 24, lvl.player.global_position.y)
			await frames(10)
			check(lvl.boss_active, "%s: crossing the arena line starts the fight" % id)
			for gate in lvl.boss_gates:
				check(not gate.is_open, "%s: arena gates close" % id)
			lvl.boss.die()
			await frames(10)
			check(lvl.boss_defeated, "%s: guardian defeated" % id)
			check(not lvl.exit_door.locked, "%s: exit unlocks after the guardian" % id)
		await _finish(lvl)
		check(lvl.finished, "%s: exit completes the level" % id)
		eq(lvl.overlays.state, "results", "%s: results screen shown" % id)
		check(Progress.is_completed(id), "%s: completion saved" % id)
	check(Progress.data["game_complete"], "campaign complete after the final encounter")
	eq(int(Progress.data["unlocked"]), LevelCatalog.count() - 1, "every level unlocked")


func test_items_banked_once_and_survive_death() -> void:
	Progress.new_game()
	var lvl := await spawn_level("1-1")
	var p: CharacterBody2D = lvl.player
	await frames(10)
	var coin_cell := Vector2i(9, 18)
	p.global_position = Vector2(coin_cell.x * 16 + 8, coin_cell.y * 16 + 15)
	await frames(10)
	gt(lvl.pending_coins(), 0, "coin picked up into the run")
	var pending: int = lvl.pending_coins()
	p.hurt(999, p.global_position, true)
	await frames(100)
	lvl.overlays._close()
	tree.paused = false
	lvl.retry_from_checkpoint()
	await frames(5)
	eq(lvl.pending_coins(), pending, "collected coins survive a death")
	await _finish(lvl)
	var coins_after: int = Progress.coins()
	gt(coins_after, 0, "coins banked on completion")
	# Replay: the same coin is a ghost and pays nothing.
	lvl = await spawn_level("1-1")
	p = lvl.player
	await frames(10)
	p.global_position = Vector2(coin_cell.x * 16 + 8, coin_cell.y * 16 + 15)
	await frames(10)
	eq(lvl.pending_coins(), 0, "already banked coin pays nothing on replay")
	var summary := [{}]
	lvl.completed.connect(func(s: Dictionary) -> void: summary[0] = s)
	await _finish(lvl)
	var challenge_pay: int = (summary[0]["challenges"] as Array).size() * 25
	eq(Progress.coins(), coins_after + challenge_pay, "replay earns only newly completed challenges")
	eq(summary[0]["first_clear"], false, "no second first-clear bonus")


func test_rescue_cat_and_secret() -> void:
	Progress.new_game()
	var lvl := await spawn_level("1-2")
	var g := _grid("1-2")
	var p: CharacterBody2D = lvl.player
	p.invuln = 999.0
	var cage_cell: Vector2i = g.entities_of("R")[0]["cell"]
	p.global_position = Vector2(cage_cell.x * 16 + 8, cage_cell.y * 16 + 15)
	await frames(6)
	await hold("interact", 2)
	await frames(5)
	check(lvl.run_cats.has("pip"), "cage opened, Pip rescued in this run")
	var sec_cell: Vector2i = g.entities_of("$")[0]["cell"]
	p.global_position = Vector2(sec_cell.x * 16 + 8, sec_cell.y * 16 + 15)
	await frames(6)
	eq(lvl.run_secrets.size(), 1, "secret zone found")
	await _finish(lvl)
	check(Progress.has_cat("pip"), "rescue saved")
	eq(Progress.total_secrets(), 1, "secret saved")
	var hp_with_pip := Progress.max_hp()
	eq(hp_with_pip, 12, "Pip's perk: +1 heart")
	lvl = await spawn_level("1-2")
	await frames(5)
	var cage: Node = null
	for o in lvl.objects.get_children():
		if o.get("cat_id") == "pip":
			cage = o
	check(cage != null and cage.freed, "cage stays open on replay")
	eq(lvl.player.max_hp, 12, "the cat's perk is active in levels")


func test_results_continue_to_next_level() -> void:
	Progress.new_game()
	var lvl := await spawn_level("1-1")
	await _finish(lvl)
	lvl.overlays.show_blessings()
	await frames(2)
	eq(lvl.overlays.state, "blessing", "blessing choice shown")
	var tr: Node = tree.root.get_node("Transition")
	var btn: Button = lvl.overlays._center.find_children("*", "Button", true, false)[0]
	btn.pressed.emit()
	for i in 120:
		await process_frames(1)
		if tree.current_scene != lvl and tree.current_scene != null and not tr.busy:
			break
	var cur := tree.current_scene
	check(cur != null and cur.get("level_id") == "1-2", "continue loads the next level (1-2)")
	eq(Progress.run_blessings.size(), 1, "the chosen blessing is active")


func test_checkpoints_heal_and_respawn_order() -> void:
	var lvl := await spawn_level("1-1")
	var p: CharacterBody2D = lvl.player
	await frames(5)
	p.hurt(4, p.global_position, true)
	p.invuln = 0.0
	var hp: int = p.hp
	var cp: Node2D = lvl.checkpoints[0]
	p.global_position = cp.global_position + Vector2(0, -2)
	await frames(5)
	gt(p.hp, hp, "lighting a checkpoint heals")
	check(cp.active, "checkpoint lit")
	if lvl.checkpoints.size() > 1:
		var cp2: Node2D = lvl.checkpoints[1]
		p.global_position = cp2.global_position + Vector2(0, -2)
		await frames(5)
		eq(lvl.current_checkpoint, cp2, "later checkpoint becomes the respawn point")
		p.hurt(2, p.global_position, true)
		var hp2: int = p.hp
		p.global_position = cp.global_position + Vector2(0, -2)
		await frames(5)
		eq(p.hp, hp2, "a lantern heals only once (no healing farm)")
		eq(lvl.current_checkpoint, cp2, "walking back does not move the respawn point backwards")


func test_rising_fire_and_bell_tower() -> void:
	var lvl := await spawn_level("5-3")
	check(lvl.rising != null, "5-3 has the rising fire")
	check(not lvl.rising.active, "fire waits at the bottom")
	var p: CharacterBody2D = lvl.player
	p.invuln = 999.0
	p.global_position.y -= 16 * 6
	await frames(5)
	check(lvl.rising.active, "climbing starts the fire")
	var y0: float = lvl.rising.top_y
	await frames(60)
	lt(lvl.rising.top_y, y0, "fire rises")
