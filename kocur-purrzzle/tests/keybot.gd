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
	var wall_hits := 0
	var draw_bad := 0
	var checks := 0
	var check_draw := args.size() > 1 and args[1] == "draw"
	for i in Levels.LIST.size():
		main.start_level(i)
		for f in 3:
			await process_frame
		if check_draw and i == Levels.region_start(Levels.LIST[i].region):
			await create_timer(2.2).timeout  # let the region-name banner fade (its dark outline would confuse the pixel check)
		var path: String = Levels.pars()[str(i)].path
		for ch in path:
			_key(keys[ch], true)
			await process_frame
			_key(keys[ch], false)
			for f in gap:
				await process_frame
			if main.pz.tile(main.pz.player) == "#":
				wall_hits += 1
				print("L%02d cat logically inside a wall at %s" % [i + 1, main.pz.player])
			# once the step animation settles, the drawn cat must sit on its logical tile
			# (skipped after the winning step: the cat hops and the victory panel darkens the screen)
			if check_draw and not main.pz.won:
				await create_timer(0.6).timeout  # long ice slides animate for up to ~0.4 s
				checks += 1
				if not _cat_drawn_on_tile(main):
					draw_bad += 1
					print("L%02d step %d: drawn cat is not on logical tile %s" % [i + 1, checks, main.pz.player])
					root.get_texture().get_image().save_png("/tmp/keybot_mismatch_L%02d_%d.png" % [i + 1, checks])
		for f in 10:
			await process_frame
		if main.pz.won:
			won += 1
		else:
			print("L%02d NOT WON: moves=%d of %d, player=%s" % [i + 1, main.pz.moves, path.length(), main.pz.player])
	print("KEYBOT gap=%d: %d/%d levels won, wall entries %d, drawn-position mismatches %d of %d checks" % [gap, won, Levels.LIST.size(), wall_hits, draw_bad, checks])
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

# Centre of near-black (cat) pixels in a 3x3-tile window around the logical tile must be inside that tile.
func _cat_drawn_on_tile(main) -> bool:
	var img := root.get_texture().get_image()
	var m: Dictionary = main.board._metrics()
	var ts: float = m.ts
	var want: Vector2 = m.org + (Vector2(main.pz.player) + Vector2(0.5, 0.5)) * ts
	var sum := Vector2.ZERO
	var n := 0
	for y in range(int(want.y - ts * 1.5), int(want.y + ts * 1.5), 2):
		for x in range(int(want.x - ts * 1.5), int(want.x + ts * 1.5), 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.r < 0.13 and c.g < 0.13 and c.b < 0.16:
				sum += Vector2(x, y)
				n += 1
	return n > 20 and (sum / n).distance_to(want) < ts * 0.3

func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
