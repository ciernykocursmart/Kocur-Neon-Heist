extends SceneTree
## Renders screens to PNG (needs a display, e.g. xvfb-run):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s res://tests/shot.gd -- OUT_DIR what...
## what: size:<w>x<h> (window size, e.g. size:1920x1080 for store shots) | menu | gallery | ending | pause | results | gameover | level:<index>[:x[:enemies[:frames]]]   enemies = comma list, e.g. punk,brawler,boss
## Also used to make the store/readme screenshots.

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var game: Node = root.get_node("Game")
	root.get_node("SaveManager").path = "user://shot_save.json"
	root.get_node("Settings").path = "user://shot_settings.cfg"
	game.data = game.defaults()
	game.data["unlocked"] = 4
	game.data["completed"] = {"alley": true, "market": true, "neon": true}
	game.data["best_scores"] = {"alley": 18420, "market": 23110, "neon": 30550}
	game.data["best_ranks"] = {"alley": "A", "market": "S", "neon": "B"}
	game.data["golden"] = {"alley": true, "neon": true}
	game.data["run"] = {"active": true, "level": 3, "difficulty": "normal", "score": 71880, "lives": 3}
	for w: String in args.slice(1):
		var p := w.split(":")
		match p[0]:
			"size":
				var wh := p[1].split("x")
				root.size = Vector2i(int(wh[0]), int(wh[1]))
				await _wait(5)
			"menu":
				change_scene_to_file("res://scenes/main_menu.tscn")
				await _wait(40)
				await _snap("menu")
			"gallery":
				var g := Gallery.new()
				root.add_child(g)
				await _wait(5)
				await _snap("gallery")
				g.queue_free()
			"ending":
				change_scene_to_file("res://scenes/ending.tscn")
				await _wait(90)
				await _snap("ending")
			"pause", "results", "gameover":
				game.difficulty = "normal"
				game.score = 25480
				game.lives = 2
				game.begin_level(1)
				change_scene_to_file("res://scenes/level.tscn")
				await _wait(10)
				var lv: Node = current_scene
				lv.player.position.x = 900.0
				lv.cam_x = 1100.0
				lv.flow = "play"
				await _wait(20)
				if p[0] == "pause":
					lv.overlays.open_pause()
					await _wait(10)
				elif p[0] == "results":
					game.attempt.merge({"enemies": 29, "food": 3, "damage": 46.0, "time": 188.0, "best_combo": 14, "golden": true}, true)
					lv._finish_level()
					await _wait(30)
				else:
					game.lives = 0
					lv.flow = "gameover"
					lv.overlays.open_game_over()
					await _wait(120)
				await _snap(p[0])
				paused = false
			"level":
				var idx := int(p[1])
				game.difficulty = "normal"
				game.score = 12340 * (idx + 1)
				game.lives = 3
				game.begin_level(idx)
				var x0 := float(p[2]) if p.size() > 2 else 400.0
				var encs: Array = load("res://scripts/data/levels.gd").LEVELS[idx]["encounters"]
				for ei in encs.size():
					if float(encs[ei]["x"]) < x0 - 200.0:
						game.checkpoint = ei + 1
				game.god_mode = true
				change_scene_to_file("res://scenes/level.tscn")
				await _wait(10)
				var lv: Node = current_scene
				var x := float(p[2]) if p.size() > 2 else 400.0
				lv.player.position.x = x
				lv.cam_x = clampf(x + 200.0, lv.HALF_W, lv.length - lv.HALF_W)
				lv.flow = "play"
				lv.player.control_locked = false
				if p.size() > 3 and p[3] != "":
					lv.lock_arena(x + 150.0)
					var i := 0
					for k: String in p[3].split(","):
						if k in ["slick", "bruno", "snowmane", "lardpaw"]:
							var b: Node = lv.spawn_boss(k)
							b.position = Vector2(x + 400.0, 560.0)
							b.set_state("idle")
							b.cd = 4.0
						else:
							var e: Node = lv.spawn_enemy(k, 1, 50 + i)
							e.position = Vector2(x + 140.0 + i * 90.0, 470.0 + (i * 53) % 200)
							e.set_state("approach")
						i += 1
				await _wait(int(p[4]) if p.size() > 4 else 60)
				lv.hud.view.banner_t = 0.0
				lv.hud.view.hint_t = 0.0
				await _snap("level%d_%s" % [idx, p[3] if p.size() > 3 else "empty"])
	quit()


class Gallery extends Node2D:
	const LK = preload("res://scripts/data/looks.gd")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("3a3048"))
		var kinds := ["hero", "punk", "brawler", "runner", "thrower", "enforcer", "slick", "bruno", "snowmane"]
		var scales := [1.0, 1.0, 1.22, 0.95, 1.0, 1.42, 1.12, 1.55, 1.35]
		for i in kinds.size():
			var x := 70.0 + i * 135.0
			draw_set_transform(Vector2(x, 300), 0.0, Vector2(scales[i], scales[i]) * 1.35)
			CatPainter.draw_cat(self, LK.LOOKS[kinds[i]], {"eyes": "angry" if i > 0 else "open", "mouth": "grin"})
			draw_set_transform(Vector2(x, 620), 0.0, Vector2(scales[i], scales[i]) * 1.35)
			CatPainter.draw_cat(self, LK.LOOKS[kinds[i]], {"arm_f": Vector2(32, -4), "lean": 0.25, "leg_f": 0.4, "leg_b": -0.4, "eyes": "angry", "mouth": "open"})
		draw_set_transform(Vector2(1180, 640), 0.0, Vector2(-2.1, 2.1))
		CatPainter.draw_cat(self, LK.LOOKS["lardpaw"], {"eyes": "angry", "mouth": "teeth"})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
