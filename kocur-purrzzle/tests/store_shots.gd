extends SceneTree
# Store screenshots at 1920x1080. Output: store/screenshots/ (store/ has .gdignore, so the folder must exist)
# xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tests/store_shots.gd
func _initialize() -> void:
	var S = root.get_node("SaveData")
	S.path = "user://store_shots_save.json"
	DirAccess.remove_absolute(S.path)
	S.load_game()
	S.data.seen_tutorial = true
	S.data.settings.pad = false
	for i in 14:
		var ft: int = Puzzle.new(Levels.LIST[i].rows).fish_total
		S.record(i, Levels.par(i), ft if i % 3 != 1 else 0, ft)
	var main = load("res://scripts/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var out := ProjectSettings.globalize_path("res://store/screenshots/")
	DirAccess.make_dir_recursive_absolute(out)
	main.show_menu()
	await _shot(out + "01_main_menu.png", 0.5)
	var letters := {"U": "up", "D": "down", "L": "left", "R": "right", "W": "wait"}
	# [level index, steps of the stored solution to play first, file name]
	var plan := [[2, 6, "02_sunny_garden"], [5, 20, "03_sunflower_maze"], [11, 14, "04_moonlit_ruins"], [15, 5, "05_frozen_fishpond"], [23, 6, "06_crystal_catacombs"], [28, 9, "07_warp_vault"], [29, 12, "08_purrfect_finale"]]
	for p in plan:
		main.start_level(p[0])
		await create_timer(2.3).timeout
		var path: String = Levels.pars()[str(p[0])].fishpath
		if path == "":
			path = Levels.pars()[str(p[0])].path
		for k in mini(p[1], path.length() - 1):
			if path[k] == "W":
				main.wait_beat()
			else:
				main.try_move(letters[path[k]])
			main.board.snap()
		await _shot(out + p[2] + ".png", 0.6)
	main.start_level(6)
	await create_timer(0.3).timeout
	for ch in Levels.pars()["6"].fishpath:
		main.try_move(letters[ch])
		main.board.snap()
	await _shot(out + "09_level_complete.png", 1.6)
	main.show_select()
	await _shot(out + "10_level_select.png", 0.5)
	DirAccess.remove_absolute(S.path)
	quit()

func _shot(path: String, wait: float) -> void:
	await create_timer(wait).timeout
	root.get_texture().get_image().save_png(path)
