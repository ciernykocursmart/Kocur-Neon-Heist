extends SceneTree
# Screenshot check of the drawn cat position vs. its logical tile, facing right and left (needs xvfb-run).
func _initialize() -> void:
	var S = root.get_node("SaveData")
	S.path = "user://facing_save.json"
	S.load_game()
	root.size = Vector2i(1280, 720)
	var main = load("res://scripts/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_level(1)
	await create_timer(0.3).timeout
	var bad := 0
	for d in ["right", "left", "down", "down", "right", "up"]:
		main.try_move(d)
		await create_timer(0.35).timeout
		var c := _cat_center(main)
		var m: Dictionary = main.board._metrics()
		var want: Vector2 = m.org + (Vector2(main.pz.player) + Vector2(0.5, 0.5)) * m.ts
		var ok: bool = c.distance_to(want) < m.ts * 0.3
		if not ok:
			bad += 1
		print("%-5s logic=%s drawn_center=%s expected=%s %s" % [d, main.pz.player, c.round(), want.round(), "OK" if ok else "MISMATCH"])
		root.get_texture().get_image().save_png("/tmp/facing_%s.png" % d)
	print("FACING CHECK: %s" % ("PASS" if bad == 0 else "FAIL %d" % bad))
	DirAccess.remove_absolute(S.path)
	quit()

# Centre of the cat's darkest pixels (the cat is the only near-black sprite).
func _cat_center(main) -> Vector2:
	var img := root.get_texture().get_image()
	var sum := Vector2.ZERO
	var n := 0
	for y in range(80, img.get_height() - 80, 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r < 0.13 and c.g < 0.13 and c.b < 0.16:
				sum += Vector2(x, y)
				n += 1
	return sum / max(n, 1)
