extends Node
## Visual smoke test: visits each screen and saves screenshots to
## user://screenshots (requires a real display / Xvfb, not --headless).

var out_dir := "user://screenshots"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var gs = get_node("/root/GameState")
	gs.persistence_enabled = false
	gs.reset_campaign()
	gs.campaign_seed = 2024
	await _go("res://scenes/main_menu.tscn", 40)
	await _shot("01_main_menu")
	gs.add_credits(1400)
	gs.mission_index = 5
	gs.intel = [0, 1, 2, 3]
	await _go("res://scenes/hideout.tscn", 30)
	await _shot("02_hideout")
	get_tree().current_scene._show_tab("armory")
	await _wait(5)
	await _shot("02b_armory")
	get_tree().current_scene._show_tab("intel")
	await _wait(5)
	await _shot("02c_intel")

	gs.mission_index = int(OS.get_environment("KOCUR_MISSION")) if OS.get_environment("KOCUR_MISSION") != "" else 5
	await _go("res://scenes/game.tscn", 40)
	var game = get_tree().current_scene
	game.player.invuln = 100000.0
	await _shot("03_title_card")
	await _wait(120)
	await _shot("03b_game")
	game.pause_menu.open()
	await _wait(10)
	await _shot("03c_pause")
	game.pause_menu.close()
	await _wait(5)
	# Walk into a guard's view to show detection.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EnemyEnforcer or e is EnemyGuard:
			game.player.global_position = e.global_position + Vector2.from_angle(e.facing) * 150.0
			break
	game.player.switch_weapon("smg")
	await _wait(50)
	await _shot("04_detection")
	game.alarm.raise_alarm(game.player.global_position, "CAMERA")
	await _wait(120)
	await _shot("05_alarm_combat")
	var core: Node2D = game.cores[0]
	game.player.global_position = core.global_position + Vector2(40, 0)
	await _wait(5)
	game.focus = core
	game._hack_cooldown = 0.0
	game.request_interact()
	await _wait(20)
	await _shot("06_hacking")
	game.hud.abort_hack()
	for c in game.cores:
		c.complete_hack()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.global_position = game.extraction.global_position
	await _wait(100)
	await _shot("07_mission_complete")

	# Finale: boss fight + archive reveal.
	get_tree().paused = false
	gs.mission_index = 12
	await _go("res://scenes/game.tscn", 40)
	game = get_tree().current_scene
	game.player.invuln = 100000.0
	for c in game.cores:
		if c.role == "uplink":
			c.complete_hack()
	game.player.global_position = game.boss.global_position + Vector2(-260, 90)
	await _wait(150)
	await _shot("09_boss_fight")
	for i in 40:
		if game.boss.is_dead():
			break
		game.boss.take_damage(60.0, game.player.global_position)
	await _wait(90)
	game.data_core.complete_hack()
	await _wait(60)
	await _shot("10_truth")
	game.hud.close_story()
	await _wait(5)

	get_tree().paused = false
	gs.reset_campaign()
	await _go("res://scenes/game.tscn", 30)
	game = get_tree().current_scene
	game.player.take_damage(9999.0, game.player.global_position + Vector2(5, 0))
	await _wait(80)
	await _shot("08_game_over")
	get_tree().paused = false
	gs.campaign_complete = true
	await _go("res://scenes/ending.tscn", 240)
	await _shot("11_ending")
	get_tree().quit(0)


func _go(scene: String, frames: int) -> void:
	get_tree().change_scene_to_file(scene)
	await _wait(frames)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
