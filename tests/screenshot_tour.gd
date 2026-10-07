extends Node
## Visual smoke test: visits each screen and saves screenshots to
## user://screenshots (requires a real display / Xvfb, not --headless).

var out_dir := "user://screenshots"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var gs = get_node("/root/GameState")
	gs.persistence_enabled = false
	gs.reset_campaign()
	await _go("res://scenes/main_menu.tscn", 40)
	await _shot("01_main_menu")
	gs.add_credits(700)
	await _go("res://scenes/hideout.tscn", 30)
	await _shot("02_hideout")
	gs.reset_campaign()
	gs.mission_index = int(OS.get_environment("KOCUR_MISSION")) if OS.get_environment("KOCUR_MISSION") != "" else 2
	await _go("res://scenes/game.tscn", 90)
	var game = get_tree().current_scene
	game.player.invuln = 1000.0
	await _shot("03_game_start")
	# Walk the cat toward the first guard to show cones/detection.
	var target: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		target = e
		break
	if target:
		game.player.global_position = target.global_position + Vector2.from_angle(target.facing) * 130.0
		await _wait(50)
		await _shot("04_detection")
	game.alarm.raise_alarm(game.player.global_position, "TEST")
	await _wait(120)
	await _shot("05_alarm_combat")
	# Hack overlay on the data core.
	game.player.global_position = game.data_core.global_position + Vector2(40, 0)
	await _wait(5)
	game.focus = game.data_core
	game.request_interact()
	await _wait(20)
	await _shot("06_hacking")
	game.hud.abort_hack()
	game.data_core.complete_hack()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.global_position = game.extraction.global_position
	await _wait(100)
	await _shot("07_mission_complete")
	get_tree().paused = false
	gs.reset_campaign()
	await _go("res://scenes/game.tscn", 30)
	game = get_tree().current_scene
	game.player.take_damage(9999.0, game.player.global_position + Vector2(5, 0))
	await _wait(80)
	await _shot("08_game_over")
	get_tree().paused = false
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
