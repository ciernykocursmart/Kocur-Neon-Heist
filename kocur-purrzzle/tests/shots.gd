extends SceneTree
# Needs a display (xvfb-run). Saves screenshots into res://screenshots.
func _initialize() -> void:
	var SaveData = root.get_node("SaveData")
	SaveData.path = "user://shots_save.json"
	DirAccess.remove_absolute("user://shots_save.json")
	SaveData.load_game()
	root.size = Vector2i(1280, 720)
	var main = load("res://scripts/main.tscn").instantiate()
	main.skip_delays = true
	root.add_child(main)
	var out := ProjectSettings.globalize_path("res://screenshots/")
	await _shot("01_menu", out)
	for i in [0, 2, 8, 12, 13, 17, 20, 22, 26, 29]:
		main.start_level(i)
		await create_timer(0.3).timeout
		if i == 2:
			main.try_move("down"); main.try_move("down")
		await _shot("level_%02d" % (i + 1), out)
	main.start_level(10)
	var letters := {"U": "up", "D": "down", "L": "left", "R": "right", "W": "wait"}
	for ch in Levels.pars()["10"].path:
		main.board.snap(); main.board.vis_p = Vector2(main.pz.player)
		if letters[ch] == "wait": main.wait_beat()
		else: main.try_move(letters[ch])
	await create_timer(0.4).timeout
	await _shot("victory", out)
	main.show_select(); await create_timer(0.2).timeout
	await _shot("select", out)
	main.show_settings(); await create_timer(0.2).timeout
	await _shot("settings", out)
	quit()

func _shot(name: String, dir: String) -> void:
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png(dir + name + ".png")
