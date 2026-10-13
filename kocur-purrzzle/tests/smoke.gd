extends SceneTree
# Plays every campaign level through the real UI (try_move) using the stored solutions.
func _initialize() -> void:
	var SaveData = root.get_node("SaveData")
	SaveData.path = "user://smoke_save.json"
	DirAccess.remove_absolute("user://smoke_save.json")
	SaveData.load_game()
	var main = load("res://scripts/main.tscn").instantiate()
	main.skip_delays = true
	root.add_child(main)
	await process_frame
	var fails := 0
	var letters := {"U": "up", "D": "down", "L": "left", "R": "right", "W": "wait"}
	var sum_stars := 0
	for i in Levels.LIST.size():
		main.start_level(i)
		await process_frame
		var info = Levels.pars()[str(i)]
		var path: String = info.fishpath if int(info.fishpar) > 0 else info.path
		for ch in path:
			var d: String = letters[ch]
			main.board.snap()
			main.board.vis_p = Vector2(main.pz.player)
			if d == "wait":
				main.wait_beat()
			else:
				main.try_move(d)
		if not main.pz.won or SaveData.stars(i) < 1:
			printerr("FAIL level %d not won via UI" % (i + 1))
			fails += 1
		sum_stars += SaveData.stars(i)
		await process_frame
	print("UI playthrough: %d/%d levels won, stars %d, fails %d" % [Levels.LIST.size() - fails, Levels.LIST.size(), sum_stars, fails])
	main.show_menu(); await process_frame
	main.show_select(); await process_frame
	main.show_settings(); await process_frame
	main.show_credits(); await process_frame
	main.start_level(0); await process_frame
	main.show_pause(); await process_frame
	print("screens ok")
	quit(1 if fails > 0 else 0)
