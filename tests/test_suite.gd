extends Node
## Headless test-suite (loaded by tests/run_tests.gd once autoloads exist).
##
## Covers: script compilation, room templates, facility generation and
## solvability across many seeds, mission catalogue scaling, upgrades,
## save/load round-trip, and full in-engine mission simulations (win by
## stealing the data and extracting, lose by dying, restart, hacking flows,
## alarm escalation and reinforcement spawns).

var failures := 0
var passes := 0
var _current := ""


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("  FAIL [%s] %s" % [_current, msg])


func section(name: String) -> void:
	_current = name
	print("== %s" % name)


func run() -> void:
	var gs = get_node("/root/GameState")
	gs.persistence_enabled = false

	test_scripts_compile()
	test_room_templates()
	test_generation(gs)
	test_mission_catalog()
	test_upgrades_and_save(gs)
	await test_menu_scenes()
	await test_mission_win(gs)
	await test_mission_lose_and_restart(gs)
	await test_hack_and_alarm(gs)
	await test_bot_playthrough(gs)

	print("")
	print("RESULT: %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


# --------------------------------------------------------------------------

func test_scripts_compile() -> void:
	section("scripts compile")
	var dirs := ["res://scripts/autoload", "res://scripts/core", "res://scripts/world", "res://scripts/actors", "res://scripts/objects", "res://scripts/systems", "res://scripts/ui"]
	for d in dirs:
		var da := DirAccess.open(d)
		check(da != null, "dir exists %s" % d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				check(s != null and s.can_instantiate(), "compiles %s/%s" % [d, f])
	for scene in ["res://scenes/main_menu.tscn", "res://scenes/game.tscn", "res://scenes/hideout.tscn"]:
		var ps = load(scene)
		check(ps is PackedScene, "scene loads %s" % scene)


func test_room_templates() -> void:
	section("room templates")
	for t in RoomTemplates.TEMPLATES:
		var rows: Array = t["rows"]
		check(rows.size() == RoomTemplates.H, "%s has %d rows" % [t["name"], RoomTemplates.H])
		var has_center := false
		for y in rows.size():
			var line: String = rows[y]
			check(line.length() == RoomTemplates.W, "%s row %d width %d" % [t["name"], y, line.length()])
			if "S" in line:
				has_center = true
			for x in line.length():
				var door_zone := (y >= 4 and y <= 6 and (x <= 1 or x >= 13)) or (x >= 6 and x <= 8 and (y <= 1 or y >= 9))
				if door_zone:
					check(line[x] != "#" and line[x] != "c", "%s door area clear at %d,%d" % [t["name"], x, y])
		check(has_center, "%s has an S marker" % t["name"])
	check(RoomTemplates.by_tag("spawn").size() >= 1, "spawn template exists")
	check(RoomTemplates.by_tag("data").size() >= 2, "data templates exist")
	check(RoomTemplates.generic().size() >= 6, "enough generic rooms")


func _flood(fac_tiles: PackedByteArray, w: int, h: int, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			var t := fac_tiles[n.y * w + n.x]
			if t == FacilityGenerator.Tile.WALL or t == FacilityGenerator.Tile.CRATE:
				continue
			seen[n] = true
			q.append(n)
	return seen


func test_generation(gs) -> void:
	section("facility generation (200 layouts)")
	var bad := 0
	for i in 200:
		var def: Dictionary = MissionCatalog.build(1 + i % 8, i * 7919)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(def["seed"])
		var L := FacilityGenerator.generate(def, rng)
		var w: int = L["width"]
		var h: int = L["height"]
		var rooms: Array = L["rooms"]
		var spawn_cell: Vector2i = rooms[L["spawn_room"]]["markers"]["S"][0]
		var reach := _flood(L["tiles"], w, h, spawn_cell)
		# Every room centre reachable (doors treated as open/hackable).
		for r in rooms.size():
			var s_cell: Vector2i = rooms[r]["markers"]["S"][0]
			if not reach.has(s_cell):
				bad += 1
				printerr("  unreachable room %d (%s) in layout %d" % [r, rooms[r]["name"], i])
		# Every marker must be on walkable floor and reachable.
		for r in rooms:
			for ch in r["markers"].keys():
				for c in r["markers"][ch]:
					if not reach.has(c):
						bad += 1
						printerr("  unreachable marker %s at %s in layout %d" % [ch, c, i])
		check(L["spawn_room"] != L["data_room"], "data room differs from spawn (layout %d)" % i)
		var data_doors_locked := true
		for d in L["doors"]:
			if L["data_room"] in d["rooms"] and not d["locked"]:
				data_doors_locked = false
		check(data_doors_locked, "vault doors locked (layout %d)" % i)
	check(bad == 0, "all rooms and markers reachable (%d problems)" % bad)


func test_mission_catalog() -> void:
	section("mission catalogue")
	var a := MissionCatalog.build(1, 42)
	var b := MissionCatalog.build(1, 42)
	check(a == b, "deterministic")
	var m5 := MissionCatalog.build(5, 42)
	check(int(m5["guards"]) > int(a["guards"]), "difficulty scales (guards)")
	check(int(m5["hunters"]) > 0 and int(a["hunters"]) == 0, "hunters appear later")
	check(int(m5["reward"]) > int(a["reward"]), "rewards scale")
	var m50 := MissionCatalog.build(50, 42)
	check(int(m50["cols"]) <= 5 and int(m50["rows"]) <= 4, "size capped")


func test_upgrades_and_save(gs) -> void:
	section("upgrades + save/load")
	gs.reset_campaign()
	check(gs.UPGRADES.size() >= 5, "at least five upgrades")
	check(not gs.buy_upgrade("armor"), "cannot buy without credits")
	gs.add_credits(1000)
	var cost: int = gs.upgrade_cost("armor")
	check(gs.buy_upgrade("armor"), "buy armor")
	check(gs.credits == 1000 - cost, "credits deducted")
	check(gs.upgrade_level("armor") == 1, "armor level 1")
	check(gs.player_max_hp() == 125.0, "armor raises max hp")
	check(gs.upgrade_cost("armor") > cost, "cost increases")
	for i in 10:
		gs.add_credits(5000)
		gs.buy_upgrade("servos")
	check(gs.upgrade_level("servos") == int(gs.UPGRADES["servos"]["max"]), "upgrade capped at max")

	gs.mission_index = 4
	gs.stats["kills"] = 17
	var snapshot: Dictionary = gs.to_save_dict()
	var json := JSON.stringify(snapshot)
	gs.reset_campaign()
	check(gs.credits == 0 and gs.mission_index == 1, "reset clears")
	gs.from_save_dict(JSON.parse_string(json))
	check(gs.credits == snapshot["credits"], "credits restored")
	check(gs.mission_index == 4, "mission index restored")
	check(gs.upgrade_level("armor") == 1 and gs.upgrade_level("servos") == 3, "upgrades restored")
	check(int(gs.stats["kills"]) == 17, "stats restored")
	# Corrupt / hostile data is clamped.
	gs.from_save_dict({"upgrades": {"armor": 99}, "mission_index": -5})
	check(gs.upgrade_level("armor") == int(gs.UPGRADES["armor"]["max"]), "corrupt upgrade clamped")
	check(gs.mission_index == 1, "corrupt mission index clamped")

	# Real file round-trip.
	gs.persistence_enabled = true
	var had_save: bool = gs.has_save()
	var backup := ""
	if had_save:
		backup = FileAccess.get_file_as_string(gs.SAVE_PATH)
	gs.reset_campaign()
	gs.add_credits(321)
	gs.mission_index = 3
	check(gs.save_game(), "save_game writes")
	gs.reset_campaign()
	check(gs.load_game(), "load_game reads")
	check(gs.credits == 321 and gs.mission_index == 3, "file round-trip")
	if had_save:
		var f := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		gs.delete_save()
	gs.persistence_enabled = false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_menu_scenes() -> void:
	section("menu scenes")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu", "main menu loads")
	get_tree().change_scene_to_file("res://scenes/hideout.tscn")
	await _frames(10)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Hideout", "hideout loads")


func _load_game_scene() -> Node:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	return get_tree().current_scene


func test_mission_win(gs) -> void:
	section("mission win flow")
	gs.reset_campaign()
	var game = await _load_game_scene()
	check(game is Game, "game scene loads")
	if not (game is Game):
		return
	check(game.player != null, "player spawned")
	check(game.get_tree().get_nodes_in_group("enemies").size() >= 3, "enemies spawned")
	check(game.data_core != null and game.extraction != null, "objective + extraction spawned")
	check(game.get_tree().get_nodes_in_group("cameras").size() >= 1, "cameras spawned")
	check(game.doors.size() >= 1, "security doors spawned")
	game.player.invuln = 1000.0
	await _frames(60)
	check(not game.mission_over, "mission running after 1s")
	# Every enemy must be able to path somewhere (nav works).
	var e: Enemy = game.get_tree().get_nodes_in_group("enemies")[0]
	check(game.facility.find_path(e.global_position, e.patrol_points.back()).size() > 0 or e.patrol_points.size() == 1, "enemy has a patrol path")
	# Extraction before data does nothing.
	game.player.global_position = game.extraction.global_position
	await _frames(120)
	check(not game.mission_over, "no extraction without data")
	# Hack the data core (skip the mini-game).
	game.data_core.complete_hack()
	check(game.has_data, "data stolen")
	check(game.extraction.active, "extraction active")
	check(game.alarm.level >= AlarmSystem.Level.CAUTION, "theft raises caution")
	# Make enemies harmless for the extraction test.
	for en in game.get_tree().get_nodes_in_group("enemies"):
		en.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.global_position = game.extraction.global_position
	await _frames(100)
	check(game.mission_over, "mission completed after standing on EVAC")
	check(gs.mission_index == 2, "mission index advanced")
	check(gs.credits >= int(game.def["reward"]), "reward paid (%d)" % gs.credits)
	check(game.get_tree().paused, "tree paused on end screen")
	check(game.end_screen._root.visible, "victory screen visible")
	get_tree().paused = false


func test_mission_lose_and_restart(gs) -> void:
	section("mission lose + restart")
	gs.reset_campaign()
	var game = await _load_game_scene()
	if not (game is Game):
		check(false, "game loads")
		return
	var layout_before: PackedByteArray = game.facility.tiles.duplicate()
	game.player.invuln = 0.0
	game.player.take_damage(9999.0, game.player.global_position + Vector2(10, 0))
	check(game.player.dead, "player dead")
	check(game.mission_over, "mission over on death")
	await _frames(90)
	check(game.end_screen._root.visible, "game over screen visible")
	check(int(gs.stats["deaths"]) == 1, "death recorded")
	check(gs.mission_index == 1, "mission index unchanged on death")
	game.restart_mission()
	await _frames(6)
	var game2 = get_tree().current_scene
	check(game2 is Game and game2 != game, "scene reloaded")
	if game2 is Game:
		check(not game2.mission_over and not game2.player.dead, "fresh mission state")
		check(game2.facility.tiles == layout_before, "same layout on retry")
		check(not get_tree().paused, "tree unpaused after retry")


func test_hack_and_alarm(gs) -> void:
	section("hacking + alarm + AI")
	gs.reset_campaign()
	gs.mission_index = 3
	var game = await _load_game_scene()
	if not (game is Game):
		check(false, "game loads")
		return
	# Doors: hacking opens and unblocks navigation.
	var door: SecurityDoor = game.doors[0]
	var cell: Vector2i = door.cells[0]
	check(game.facility.astar.is_point_solid(cell), "locked door blocks nav")
	door.complete_hack()
	await _frames(3)
	check(not game.facility.astar.is_point_solid(cell), "hacked door opens nav")

	# Hack mini-game flow via the HUD overlay.
	var cam: SecurityCamera = game.get_tree().get_nodes_in_group("cameras")[0]
	game.player.global_position = cam.global_position + Vector2(30, 0)
	await _frames(3)
	game.focus = cam
	game.request_interact()
	check(game.hud.is_hacking(), "hack overlay opened")
	check(game.player.locked, "player locked while hacking")
	var overlay: HackOverlay = game.hud._hack
	overlay.cursor = overlay.target
	overlay._lock()
	overlay.cursor = overlay.target
	overlay._lock()
	await _frames(2)
	check(cam.hacked_done, "camera hacked via overlay")
	check(not game.player.locked, "player unlocked after hack")

	# Failing a hack leaves a trace.
	var panel: AlarmPanel = null
	for n in game.get_tree().get_nodes_in_group("interactables"):
		if n is AlarmPanel:
			panel = n
	check(panel != null, "alarm panel exists")
	game.focus = panel
	game._hack_cooldown = 0.0
	game.request_interact()
	for i in 5:
		overlay.cursor = fmod(overlay.target + PI, TAU)
		overlay._lock()
	check(not game.hud.is_hacking(), "hack ended after misses")
	check(game.alarm.level == AlarmSystem.Level.CAUTION, "failed hack -> caution")

	# Alarm escalation + broadcast + reinforcements.
	var before: int = game.get_tree().get_nodes_in_group("enemies").size()
	game.alarm.raise_alarm(game.player.global_position, "TEST")
	check(game.alarm.level == AlarmSystem.Level.ALARM, "alarm raised")
	check(game.alarm.times_raised == 1, "alarm counted")
	await _frames(2)
	var searching := 0
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en.state == Enemy.State.SEARCH or en.state == Enemy.State.CHASE:
			searching += 1
	check(searching == before, "all enemies respond to alarm (%d/%d)" % [searching, before])
	game.alarm.reinforce_timer = 0.01
	game.player.invuln = 1000.0
	await _frames(5)
	check(game.get_tree().get_nodes_in_group("enemies").size() > before, "reinforcements spawned")
	# Alarm panel resets alarm & sensors.
	panel.complete_hack()
	check(game.alarm.level == AlarmSystem.Level.CALM, "alarm panel resets alarm")
	check(not game.facility.zones_active, "zones disabled")

	# Enemy detection: put the player right in front of a guard.
	var guard: Enemy = null
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en is EnemyGuard:
			guard = en
			break
	check(guard != null, "guard exists")
	if guard != null:
		guard.state = Enemy.State.PATROL
		guard.awareness = 0.0
		guard.patrol_points = [guard.global_position]
		var spot := guard.global_position + Vector2.from_angle(guard.facing) * 60.0
		if game.facility.has_los(guard.global_position, spot):
			game.player.global_position = spot
			await _frames(90)
			check(guard.state == Enemy.State.CHASE, "guard detects player in front (state %s)" % Enemy.STATE_NAMES[guard.state])
		# Silent takedown on an unaware guard.
		guard.state = Enemy.State.PATROL
		guard.awareness = 0.0
		guard.take_damage(9999.0, guard.global_position, true)
		check(guard.is_dead(), "guard killed")
		check(game.takedowns >= 1, "takedown counted")

	# Let the simulation run with full AI for a few seconds without errors.
	game.player.invuln = 1000.0
	await _frames(240)
	check(true, "simulation ran 4s with AI active")
	gs.mission_index = 1
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(5)


## Walks the cat with real physics along A* paths: hack every door, reach the
## data core, download, reach EVAC. Proves layouts are traversable by the
## player's collision shape and that the full loop completes with AI active.
func test_bot_playthrough(gs) -> void:
	section("bot playthrough (missions 1-6)")
	for m in range(1, 7):
		gs.reset_campaign()
		gs.campaign_seed = 1000 + m * 31
		gs.mission_index = m
		var game = await _load_game_scene()
		if not (game is Game):
			check(false, "mission %d loads" % m)
			continue
		game.player.invuln = 100000.0
		for d in game.doors:
			d.complete_hack()
		await _frames(2)
		var ok_data: bool = await _bot_walk(game, game.data_core.global_position, 40.0, 60 * 90)
		check(ok_data, "mission %d: bot reached data core" % m)
		if not ok_data:
			continue
		game.data_core.complete_hack()
		var ok_evac: bool = await _bot_walk(game, game.extraction.global_position, 10.0, 60 * 90)
		check(ok_evac, "mission %d: bot reached EVAC" % m)
		await _frames(100)
		check(game.mission_over and gs.mission_index == m + 1, "mission %d: completed via EVAC" % m)
		get_tree().paused = false


func _bot_walk(game, target: Vector2, tolerance: float, max_frames: int) -> bool:
	var p: Player = game.player
	var path: PackedVector2Array = game.facility.find_path(p.global_position, target)
	if path.is_empty():
		printerr("  no path to target")
		return false
	path.append(target)
	var i := 0
	var stuck := 0
	var last := p.global_position
	for f in max_frames:
		if game.mission_over:
			return true
		while i < path.size() - 1 and p.global_position.distance_to(path[i]) < 10.0:
			i += 1
		if p.global_position.distance_to(target) < tolerance:
			return true
		var dir := (path[i] - p.global_position).normalized()
		p.move_and_collide(dir * 260.0 / 60.0)
		await get_tree().physics_frame
		if f % 30 == 0:
			if p.global_position.distance_to(last) < 4.0:
				stuck += 1
				if stuck > 6:
					printerr("  bot stuck at %s (cell %s) heading to %s" % [p.global_position, game.facility.cell_of(p.global_position), path[i]])
					return false
			else:
				stuck = 0
			last = p.global_position
	return false
