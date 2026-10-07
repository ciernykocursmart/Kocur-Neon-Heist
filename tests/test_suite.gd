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
	await test_combat(gs)
	await test_weapons(gs)
	await test_stealth_features(gs)
	await test_progression_and_modes(gs)
	test_save_robustness(gs)
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
	section("facility generation (240 layouts: 12 campaign missions + endless)")
	var bad := 0
	var arenas := 0
	var finals := 0
	for i in 240:
		var def: Dictionary = MissionCatalog.build(1 + i % 12, i * 7919) if i % 20 < 12 else MissionCatalog.build_endless(1 + i % 9, i * 31)
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
		var vault_rooms: Array = [L["data_room"]]
		vault_rooms.append_array(L["arena_rooms"])
		if bool(def.get("final", false)):
			finals += 1
			if not (L["arena_rooms"] as Array).is_empty():
				arenas += 1
		for d in L["doors"]:
			for vr in vault_rooms:
				if vr in d["rooms"] and not d["locked"]:
					data_doors_locked = false
		check(data_doors_locked, "vault doors locked (layout %d)" % i)
	check(bad == 0, "all rooms and markers reachable (%d problems)" % bad)
	check(finals > 0 and arenas == finals, "final missions build a merged WARDEN arena (%d/%d)" % [arenas, finals])


func test_mission_catalog() -> void:
	section("mission catalogue + campaign data")
	var a := MissionCatalog.build(1, 42)
	var b := MissionCatalog.build(1, 42)
	check(a == b, "deterministic")
	check(Campaign.MISSIONS.size() == 12, "12 campaign missions")
	check(Campaign.INTEL.size() == 12, "12 intel fragments")
	var acts := {}
	var prev_reward := 0
	var prev_threat := 0
	for i in range(1, 13):
		var m := MissionCatalog.build(i, 42)
		acts[int(m["act"])] = int(acts.get(int(m["act"]), 0)) + 1
		check(int(m["reward"]) > prev_reward, "reward grows at mission %d" % i)
		prev_reward = int(m["reward"])
		var threat := MissionCatalog.THREATS.find(String(m["threat"]))
		check(threat >= prev_threat, "threat never drops at mission %d" % i)
		prev_threat = threat
		var hostiles := int(m["guards"]) + int(m["drones"]) + int(m["hunters"]) * 2 + int(m["enforcers"]) * 2
		check(hostiles <= int(m["cols"]) * int(m["rows"]) * 3, "mission %d enemy density sane" % i)
		check(String(m["briefing"]) != "", "mission %d has a briefing" % i)
		check(int(m["intel"]) == i - 1, "mission %d hides intel %d" % [i, i - 1])
	check(acts.get(0, 0) == 4 and acts.get(1, 0) == 4 and acts.get(2, 0) == 4, "three acts of four missions")
	check(MissionCatalog.build(1, 42)["hunters"] == 0 and MissionCatalog.build(1, 42)["enforcers"] == 0, "mission 1 is gentle")
	check(MissionCatalog.build(12, 42)["final"] == true, "mission 12 is the finale")
	check(MissionCatalog.build(5, 42)["objective"] == "shards", "act II introduces multi-core objectives")
	var e1 := MissionCatalog.build_endless(1, 42)
	var e9 := MissionCatalog.build_endless(9, 42)
	check(e1["mode"] == "endless" and int(e9["guards"]) > int(e1["guards"]), "endless scales with depth")
	check(int(e9["reward"]) > int(e1["reward"]), "endless rewards scale")
	var e50 := MissionCatalog.build_endless(50, 42)
	check(int(e50["cols"]) <= 5 and int(e50["rows"]) <= 4, "endless size capped")


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
	check(game.get_tree().get_nodes_in_group("enemies").size() >= 2, "enemies spawned")
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
	await _frames(45)
	var game2 = get_tree().current_scene
	check(game2 is Game and game2 != game, "scene reloaded")
	if game2 is Game:
		check(not game2.mission_over and not game2.player.dead, "fresh mission state")
		check(game2.facility.tiles == layout_before, "same layout on retry")
		check(not get_tree().paused, "tree unpaused after retry")


func test_hack_and_alarm(gs) -> void:
	section("hacking + alarm + AI")
	gs.reset_campaign()
	gs.campaign_seed = 99
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
		guard.look_base = guard.facing
		guard.anim_t = 0.0
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
	section("bot playthrough (all 12 campaign missions)")
	for m in range(1, 13):
		gs.reset_campaign()
		gs.campaign_seed = 1000 + m * 31
		gs.mission_index = m
		var game = await _load_game_scene()
		if not (game is Game):
			check(false, "mission %d loads" % m)
			continue
		game.player.invuln = 100000.0
		# The bot validates level geometry, so it ignores enemy bodies.
		game.player.collision_mask = 1
		for d in game.doors:
			if not d.sealed:
				d.complete_hack()
		await _frames(2)
		var ok_data: bool = await _bot_objectives(game, m)
		check(ok_data, "mission %d: bot completed objectives" % m)
		if not ok_data:
			continue
		var ok_evac: bool = await _bot_walk(game, game.extraction.global_position, 10.0, 60 * 90)
		check(ok_evac, "mission %d: bot reached EVAC" % m)
		await _frames(100)
		if m < 12:
			check(game.mission_over and gs.mission_index == m + 1, "mission %d: completed via EVAC" % m)
		else:
			check(game.mission_over and gs.campaign_complete, "finale completed -> campaign complete")
		get_tree().paused = false


## Visits and downloads every core the mission needs, fighting the WARDEN
## on the finale (damage is applied directly; the bot tests flow, not aim).
func _bot_objectives(game, m: int) -> bool:
	for core in game.cores:
		if core.role == "archive":
			continue
		if not await _bot_walk(game, core.global_position, 40.0, 60 * 90):
			printerr("  mission %d: could not reach %s" % [m, core.display_name])
			return false
		core.complete_hack()
	if game.boss != null:
		for d in game.vault_doors:
			if d.sealed or not d.hacked_done:
				printerr("  vault door still sealed after uplinks")
				return false
		if not await _bot_walk(game, game.boss.global_position + Vector2(0, 130), 60.0, 60 * 90):
			printerr("  could not reach the WARDEN arena")
			return false
		await _frames(10)
		if not game.boss.active:
			printerr("  WARDEN did not activate")
			return false
		for i in 200:
			if game.boss.is_dead():
				break
			game.boss.take_damage(60.0, game.player.global_position)
			await _frames(3)
		if not game.boss.is_dead() or not game.boss_defeated:
			printerr("  WARDEN not defeated")
			return false
		await _frames(70)
		if game.data_core.sealed:
			printerr("  archive still sealed")
			return false
		if not await _bot_walk(game, game.data_core.global_position, 40.0, 60 * 60):
			return false
		game.data_core.complete_hack()
		await _frames(5)
		if not game.hud.is_story_open():
			printerr("  truth reveal did not open")
			return false
		game.hud.close_story()
		await _frames(5)
		if not game.lockdown or game.alarm.level != AlarmSystem.Level.ALARM:
			printerr("  lockdown did not start")
			return false
	elif game.cores.size() == 1:
		pass
	return game.has_data


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


func test_combat(gs) -> void:
	section("combat")
	gs.reset_campaign()
	gs.campaign_seed = 77
	gs.mission_index = 5
	var game = await _load_game_scene()
	if not (game is Game):
		check(false, "game loads")
		return
	var guard: Enemy = null
	var hunter: EnemyHunter = null
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en is EnemyGuard and guard == null:
			guard = en
		if en is EnemyHunter and hunter == null:
			hunter = en
	check(guard != null and hunter != null, "guard and hunter present")
	if guard == null or hunter == null:
		return
	# Player bullets damage enemies.
	var hp0 := guard.hp
	var from := guard.global_position + Vector2(-80, 0)
	game.spawn_bullet(from, Vector2(1100, 0), 20.0, true, Palette.CYAN)
	await _frames(10)
	check(guard.hp < hp0 or not game.facility.has_los(from, guard.global_position), "player bullet damages guard")
	check(guard.state == Enemy.State.CHASE or guard.hp == hp0, "shot guard reacts")
	# Hunter shield absorbs first damage.
	var h_hp := hunter.hp
	hunter.take_damage(30.0, hunter.global_position + Vector2(10, 0))
	check(hunter.hp == h_hp and hunter.shield < EnemyHunter.SHIELD_MAX, "hunter shield absorbs")
	hunter.take_damage(80.0, hunter.global_position + Vector2(10, 0))
	check(hunter.hp < h_hp, "damage passes after shield breaks")
	# Enemies shoot back and hurt the cat.
	var spot := Vector2.INF
	for a in 16:
		var cand: Vector2 = guard.global_position + Vector2.from_angle(TAU * a / 16.0) * 150.0
		if game.facility.is_walkable(game.facility.cell_of(cand)) and game.facility.has_los(guard.global_position, cand):
			spot = cand
			break
	check(spot != Vector2.INF, "found a firing position")
	if spot != Vector2.INF:
		game.player.global_position = spot
		game.alarm.raise_alarm(spot, "TEST")
		var p_hp: float = game.player.hp
		for i in 60 * 6:
			if game.player.hp < p_hp or game.player.dead:
				break
			game.player.global_position = spot
			await get_tree().physics_frame
		check(game.player.hp < p_hp, "enemy fire damages the cat")
	get_tree().paused = false


func test_weapons(gs) -> void:
	section("weapons")
	gs.reset_campaign()
	gs.mission_index = 1
	check(gs.owned_weapons() == ["pistol"], "mission 1: pistol only")
	gs.mission_index = 3
	check("smg" in gs.owned_weapons() and not ("shotgun" in gs.owned_weapons()), "mission 3: SMG unlocked")
	gs.mission_index = 5
	check(gs.owned_weapons().size() == 3, "mission 5: all three weapons")
	var game = await _load_game_scene()
	if not (game is Game):
		check(false, "game loads")
		return
	var p: Player = game.player
	p.invuln = 100000.0
	check(p.weapon_id == "pistol", "starts with pistol")
	p.switch_weapon("smg")
	check(p.weapon_id == "smg" and p.mag == gs.weapon_mag("smg"), "switch to SMG with its own magazine")
	p.fire_timer = 0.0
	p._try_fire()
	check(p.mag == gs.weapon_mag("smg") - 1, "SMG fires one round")
	p.switch_weapon("pistol")
	check(p.mag == gs.weapon_mag("pistol"), "pistol ammo kept separately")
	p.switch_weapon("smg")
	check(p.mag == gs.weapon_mag("smg") - 1, "SMG ammo state remembered")
	p.switch_weapon("shotgun")
	var before: int = game.bullets.get_child_count()
	p.fire_timer = 0.0
	p._try_fire()
	check(game.bullets.get_child_count() - before == int(Weapons.get_data("shotgun")["pellets"]), "shotgun fires a pellet spread")
	p.mag = 0
	p.reserve = 6
	p.reloading = false
	p.start_reload()
	check(p.reloading, "reload starts")
	await _frames(int(60 * float(Weapons.get_data("shotgun")["reload"])) + 10)
	check(p.mag == 6 and not p.reloading, "shotgun reload completes")
	p.reserve = 0
	check(p.add_ammo_pack(1.0), "ammo pack refills reserves")
	check(p.reserve > 0, "current weapon reserve increased")
	gs.upgrades["magazine"] = 2
	check(gs.weapon_mag("pistol") > 10, "Extended Mags enlarge magazines")
	gs.upgrades["magazine"] = 0
	# Sneak-attack bonus with the pistol.
	var guard: Enemy = null
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en is EnemyGuard:
			guard = en
			break
	if guard != null:
		guard.state = Enemy.State.PATROL
		var hp0 := guard.hp
		var b := Bullet.new()
		b.game = game
		b.damage = 20.0
		b.sneak_bonus = 2.0
		b.velocity = Vector2(1000, 0)
		b._on_hit({"position": guard.global_position, "normal": Vector2.LEFT, "collider": guard})
		check(hp0 - guard.hp >= 39.0 or guard.is_dead(), "pistol sneak bonus doubles damage vs unaware")
	# Enforcer frontal armour.
	var enf: EnemyEnforcer = null
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en is EnemyEnforcer:
			enf = en
	check(enf != null, "enforcer spawned in act II")
	if enf != null:
		enf.facing = 0.0
		var h0 := enf.hp
		enf.take_damage(50.0, enf.global_position + Vector2(100, 0))
		var front := h0 - enf.hp
		var h1 := enf.hp
		enf.take_damage(50.0, enf.global_position + Vector2(-100, 0))
		var back := h1 - enf.hp
		check(front < back * 0.5, "enforcer front armour blocks (front %.0f vs back %.0f)" % [front, back])
		check(enf.state == Enemy.State.CHASE, "shot enforcer engages")
	get_tree().paused = false


func test_stealth_features(gs) -> void:
	section("stealth: shadows, bodies, decoys")
	gs.reset_campaign()
	gs.campaign_seed = 4242
	gs.mission_index = 2
	var game = await _load_game_scene()
	if not (game is Game):
		check(false, "game loads")
		return
	var p: Player = game.player
	p.invuln = 100000.0
	var f: Facility = game.facility
	# Shadows.
	if not f.shadow_cells.is_empty():
		p.global_position = f.cell_center(f.shadow_cells[0])
		p.velocity = Vector2.ZERO
		var lit_vis: float = gs.detection_multiplier() * 0.8
		check(p.visibility() < lit_vis * 0.5, "standing in shadow lowers visibility")
	else:
		check(true, "no shadows in this layout")
	# Decoy lures an idle guard.
	var guard: Enemy = null
	for en in game.get_tree().get_nodes_in_group("enemies"):
		if en is EnemyGuard:
			guard = en
			break
	check(guard != null, "guard present")
	if guard != null:
		guard.state = Enemy.State.PATROL
		guard.awareness = 0.0
		var lure := guard.global_position + Vector2(60, 0)
		game.spawn_decoy(lure, lure)
		await _frames(30)
		check(guard.state == Enemy.State.SUSPICIOUS, "decoy makes guard suspicious (%s)" % Enemy.STATE_NAMES[guard.state])
		check(guard.investigate_pos.distance_to(lure) < 80.0, "guard investigates the decoy")
		check(p.decoys == Player.DECOY_CHARGES, "spawn_decoy itself does not consume charges")
		p.throw_decoy(p.global_position + Vector2(50, 0))
		check(p.decoys == Player.DECOY_CHARGES - 1, "throwing consumes a charge")
	# Body discovery.
	var enemies: Array = game.get_tree().get_nodes_in_group("enemies")
	if enemies.size() >= 2:
		var victim: Enemy = enemies[0]
		var witness: Enemy = enemies[1]
		var spot := Vector2.INF
		for a in 16:
			var cand: Vector2 = witness.global_position + Vector2.from_angle(TAU * a / 16.0) * 90.0
			if f.is_walkable(f.cell_of(cand)) and not f.is_shadow(cand) and f.has_los(witness.global_position, cand):
				spot = cand
				break
		if spot != Vector2.INF:
			victim.global_position = spot
			await _frames(2)
			victim.take_damage(9999.0, victim.global_position, true)
			witness.state = Enemy.State.PATROL
			witness.awareness = 0.0
			witness.patrol_points = [witness.global_position]
			witness.facing = (spot - witness.global_position).angle()
			witness.look_base = witness.facing
			await _frames(40)
			check(game.bodies_found >= 1, "witness discovers the body")
			check(game.alarm.level >= AlarmSystem.Level.CAUTION, "body discovery raises caution")
	# Intel fragment exists and is collectible.
	var frag: IntelFragment = null
	for n in game.get_tree().get_nodes_in_group("interactables"):
		if n is IntelFragment:
			frag = n
	check(frag != null, "intel fragment placed")
	if frag != null:
		game.focus = frag
		game._hack_cooldown = 0.0
		game.request_interact()
		await _frames(2)
		check(gs.has_intel(frag.intel_id), "intel collected")
		check(game.hud.is_story_open(), "intel reader opened")
		game.hud.close_story()
		await _frames(2)
		check(not get_tree().paused, "game resumes after reading")
	get_tree().paused = false


func test_progression_and_modes(gs) -> void:
	section("campaign completion, endless mode, scenes")
	gs.reset_campaign()
	gs.mission_index = 12
	gs.finale_checkpoint = true
	var fin = await _load_game_scene()
	if fin is Game:
		var all_up := true
		for c in fin.cores:
			if c.role == "uplink" and not c.hacked_done:
				all_up = false
		check(all_up, "finale checkpoint keeps uplinks breached")
		await _frames(3)
		var open := true
		for d in fin.vault_doors:
			if d.sealed or fin.facility.astar.is_point_solid(d.cells[0]):
				open = false
		check(open and fin.vault_doors.size() > 0, "finale checkpoint opens the vault")
		check(fin.boss != null and not fin.boss.active, "WARDEN waits in the vault")
	gs.finale_checkpoint = false
	gs.mission_index = 12
	gs.complete_mission({"total": 2000, "kills": 3})
	check(gs.campaign_complete, "finishing mission 12 completes the campaign")
	check(gs.mission_index == 12, "mission index stays on the finale")
	check(gs.owned_weapons().size() == 3, "all weapons after campaign")
	gs.start_endless()
	check(gs.is_endless(), "endless mode enabled")
	var d1: Dictionary = gs.get_mission_def()
	check(d1["mode"] == "endless" and int(d1["depth"]) == 1, "endless contract 1")
	gs.complete_mission({"total": 700})
	check(gs.endless_depth == 2 and gs.endless_best == 1, "endless depth advances, best recorded")
	var game = await _load_game_scene()
	check(game is Game and String(game.def["mode"]) == "endless", "endless mission loads")
	if game is Game:
		game.player.invuln = 100000.0
		for c in game.cores:
			c.complete_hack()
		check(game.has_data, "endless objectives complete")
		for en in game.get_tree().get_nodes_in_group("enemies"):
			en.process_mode = Node.PROCESS_MODE_DISABLED
		game.player.global_position = game.extraction.global_position
		await _frames(100)
		check(game.mission_over and gs.endless_depth == 3, "endless contract completes")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hideout.tscn")
	await _frames(10)
	check(get_tree().current_scene.name == "Hideout", "hideout loads in endless mode")
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
	await _frames(10)
	check(get_tree().current_scene.name == "Ending", "ending scene loads")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	gs.reset_campaign()


func test_save_robustness(gs) -> void:
	section("save robustness")
	gs.reset_campaign()
	# Version 1 save past the old open-ended campaign is migrated.
	gs.from_save_dict({"version": 1, "mission_index": 20, "credits": 50, "upgrades": {"armor": 2}})
	check(gs.campaign_complete and gs.mission_index == 12, "v1 save migrated")
	check(gs.upgrade_level("armor") == 2 and gs.upgrade_level("reflex") == 0, "new upgrades default to 0")
	# Garbage types are rejected.
	gs.from_save_dict({"upgrades": "nope", "intel": {"a": 1}, "stats": 5, "credits": -40, "mode": "endless"})
	check(gs.credits == 0 and gs.intel.is_empty() and not gs.is_endless(), "malformed fields ignored")
	gs.from_save_dict({"intel": [3, 3, 99, -1, 1]})
	check(gs.intel == [1, 3], "intel list sanitised")
	# Real files: corrupt main save falls back to the backup.
	gs.persistence_enabled = true
	var paths: Array = [gs.SAVE_PATH, gs.SAVE_BACKUP_PATH]
	var backups := {}
	for path in paths:
		if FileAccess.file_exists(path):
			backups[path] = FileAccess.get_file_as_string(path)
	gs.delete_save()
	gs.reset_campaign()
	gs.add_credits(111)
	gs.save_game()
	gs.add_credits(111)
	gs.save_game()
	check(FileAccess.file_exists(gs.SAVE_BACKUP_PATH), "backup written on second save")
	var f := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	gs.reset_campaign()
	check(gs.load_game(), "load recovers from corrupt main save")
	check(gs.credits == 111, "backup data restored (%d)" % gs.credits)
	check(gs.last_load_error != "", "player is told the backup was used")
	gs.delete_save()
	check(not gs.has_save(), "delete_save removes everything")
	check(not gs.load_game(), "missing save handled")
	for path in backups.keys():
		var w := FileAccess.open(path, FileAccess.WRITE)
		w.store_string(backups[path])
		w.close()
	gs.persistence_enabled = false
	gs.reset_campaign()
