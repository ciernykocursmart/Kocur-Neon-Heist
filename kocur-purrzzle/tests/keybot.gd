extends SceneTree
# Real-input bot (needs a display: xvfb-run). Sends actual key press/release events through Godot's input
# pipeline for every level's stored solution and checks the level is won. Arg: frames between taps.
func _initialize() -> void:
	var S = root.get_node("SaveData")
	S.path = "user://keybot_save.json"
	DirAccess.remove_absolute(S.path)
	S.load_game()
	S.data.seen_tutorial = true
	var gap := 6
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		gap = int(args[0])
	var main = load("res://scripts/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var keys := {"U": KEY_UP, "D": KEY_DOWN, "L": KEY_A, "R": KEY_RIGHT, "W": KEY_SPACE}
	var won := 0
	for i in Levels.LIST.size():
		main.start_level(i)
		for f in 3:
			await process_frame
		var path: String = Levels.pars()[str(i)].path
		for ch in path:
			_key(keys[ch], true)
			await process_frame
			_key(keys[ch], false)
			for f in gap:
				await process_frame
		for f in 10:
			await process_frame
		if main.pz.won:
			won += 1
		else:
			print("L%02d NOT WON: moves=%d of %d, player=%s" % [i + 1, main.pz.moves, path.length(), main.pz.player])
	print("KEYBOT gap=%d: %d/%d levels won" % [gap, won, Levels.LIST.size()])
	# Hold tests on level 1 (row 1 is a corridor from x=1 to x=6).
	main.start_level(0)
	await process_frame
	var ok := true
	for step in [[KEY_RIGHT, Vector2i(6, 1)], [KEY_LEFT, Vector2i(1, 1)], [KEY_D, Vector2i(6, 1)], [KEY_A, Vector2i(1, 1)]]:
		_key(step[0], true)
		for f in 90:
			await process_frame
		_key(step[0], false)
		for f in 5:
			await process_frame
		if main.pz.player != step[1]:
			ok = false
			print("HOLD %s ended at %s, expected %s" % [OS.get_keycode_string(step[0]), main.pz.player, step[1]])
	# Switch direction while still holding the first key: the newest key wins, release returns to the held one.
	_key(KEY_RIGHT, true)
	for f in 4:
		await process_frame
	var before: Vector2i = main.pz.player
	_key(KEY_LEFT, true)
	for f in 2:
		await process_frame
	var moved_left: bool = main.pz.player.x < before.x or main.pz.player == Vector2i(1, 1)
	_key(KEY_LEFT, false)
	_key(KEY_RIGHT, false)
	for f in 5:
		await process_frame
	if not moved_left:
		ok = false
		print("SWITCH right->left did not move left (before %s, now %s)" % [before, main.pz.player])
	print("HOLD/SWITCH tests: %s" % ("PASS" if ok else "FAIL"))
	DirAccess.remove_absolute(S.path)
	quit()

func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
