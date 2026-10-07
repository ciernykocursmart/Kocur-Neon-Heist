extends Node
## Curated Microsoft Store screenshots (1920x1080). Run under Xvfb:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 -s res://tests/run_store_tour.gd

var out_dir := "user://store_shots"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var gs = get_node("/root/GameState")
	gs.persistence_enabled = false
	gs.settings["tutorial_tips"] = false
	gs.reset_campaign()
	gs.campaign_seed = 3141

	# 1. Stealth: an unaware-turning-suspicious guard, cat in his peripheral cone.
	gs.mission_index = 4
	await _go("res://scenes/game.tscn", 150)
	var game = get_tree().current_scene
	game.player.invuln = 100000.0
	var guard = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EnemyGuard:
			guard = e
			break
	if guard:
		# Freeze everyone else so the moment stays a clean stealth scene.
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != guard:
				e.process_mode = Node.PROCESS_MODE_DISABLED
		for c in get_tree().get_nodes_in_group("cameras"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
		var spot: Vector2 = guard.global_position + Vector2.from_angle(guard.facing + 0.45) * 230.0
		game.player.global_position = spot
		game.player.sneaking = true
		guard.awareness = 0.45
		guard._enter_suspicious(spot)
		await _wait(10)
		game.alarm.reset_alarm()
	await _shot("02_stealth")

	# 2. Hacking a security door.
	if not game.doors.is_empty():
		var door = game.doors[0]
		game.player.global_position = door.global_position + Vector2(0, 50) if door.horizontal else door.global_position + Vector2(50, 0)
		await _wait(5)
		game.focus = door
		game._hack_cooldown = 0.0
		game.request_interact()
		await _wait(25)
		await _shot("04_hacking")
		game.hud.abort_hack()

	# 3. Act II firefight under full alarm with the SMG.
	gs.mission_index = 7
	await _go("res://scenes/game.tscn", 120)
	game = get_tree().current_scene
	game.player.invuln = 100000.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EnemyEnforcer or e is EnemyGuard:
			game.player.global_position = e.global_position + Vector2.from_angle(e.facing) * 170.0
			break
	game.player.switch_weapon("smg")
	game.alarm.raise_alarm(game.player.global_position, "CAMERA")
	for i in 90:
		await _wait(1)
		if i % 6 == 0:
			game.player.aim_angle = randf() * TAU
			game.player._try_fire()
	await _shot("03_firefight")

	# 4. WARDEN boss with a bullet ring in the air.
	gs.mission_index = 12
	gs.finale_checkpoint = true
	await _go("res://scenes/game.tscn", 120)
	game = get_tree().current_scene
	game.player.invuln = 100000.0
	game.player.global_position = game.boss.global_position + Vector2(-230, 120)
	for i in 600:
		await _wait(1)
		var hostile := 0
		for b in game.bullets.get_children():
			if not b.from_player:
				hostile += 1
		if game.boss.active and hostile > 16:
			break
	game.player.switch_weapon("shotgun")
	game.player.aim_angle = (game.boss.global_position - game.player.global_position).angle()
	game.player.fire_timer = 0.0
	game.player._try_fire()
	await _wait(3)
	await _shot("05_warden_boss")
	gs.finale_checkpoint = false

	# 5. Hideout upgrades.
	get_tree().paused = false
	gs.mission_index = 8
	gs.add_credits(2350)
	for k in ["armor", "plasma", "servos", "camo"]:
		gs.upgrades[k] = 1
	gs.intel = [0, 1, 2, 3, 4, 5, 6]
	await _go("res://scenes/hideout.tscn", 40)
	await _shot("06_hideout_upgrades")

	# 6. Mission complete.
	gs.mission_index = 3
	await _go("res://scenes/game.tscn", 90)
	game = get_tree().current_scene
	game.player.invuln = 100000.0
	game.credits_found = 85
	game.takedowns = 2
	game.kills = 3
	for c in game.cores:
		c.complete_hack()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	game.alarm.reset_alarm()
	game.alarm.times_raised = 0
	game.player.global_position = game.extraction.global_position
	await _wait(150)
	await _shot("07_mission_complete")
	get_tree().paused = false

	# 7. Main menu last (no save present -> clean title screen).
	await _go("res://scenes/main_menu.tscn", 60)
	await _shot("01_title")
	get_tree().quit(0)


func _go(scene: String, frames: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)
	await _wait(frames)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
