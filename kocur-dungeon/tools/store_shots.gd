extends SceneTree
## Captures one Microsoft Store screenshot of the real game at 1920x1080 on a
## mid-game save (13 levels cleared, 8 cats rescued, some upgrades). Needs a
## display; tools/store_shots.sh runs the whole set under xvfb-run.
##   godot --path . -s res://tools/store_shots.gd -- <out.png> <scene.tscn|level id> [steps...]
## Steps: tp:x,y (teleport to tile), wait:N (physics frames), <action>:N (hold
## an input action for N frames), tab:<camp tab>.
## The save is written to this machine's user data folder (KocurDungeon).

var _args: PackedStringArray


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var progress: Node = root.get_node("Progress")
	var data: Dictionary = progress.defaults()
	data["started"] = true
	data["intro_seen"] = true
	data["coins"] = 1240
	data["unlocked"] = 13
	var catalog: GDScript = load("res://scripts/data/level_catalog.gd")
	for i in 13:
		var rec: Dictionary = progress.new_record()
		rec["completed"] = true
		rec["best_time"] = 140.0 + i * 23.0
		data["levels"][catalog.LEVELS[i]["id"]] = rec
	data["rescued"] = ["pip", "bramble", "soot", "cinder", "nibbles", "flurry", "whisper", "inkblot"]
	data["upgrades"] = {"heart": 2, "claws": 1, "pounce": 1, "remedy": 1, "whiskers": 1}
	data["stats"]["play_time"] = 7300.0
	progress.data = data
	progress.save_game()

	var out := _args[0]
	var target := _args[1]
	var lvl: Node = null
	if target.ends_with(".tscn"):
		change_scene_to_file(target)
	else:
		root.get_node("Transition").next_level_id = target
		change_scene_to_file("res://scenes/level.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene
	for s in _args.slice(2):
		if s.begins_with("tp:"):
			var xy := s.substr(3).split(",")
			lvl.player.global_position = Vector2(float(xy[0]) * 16 + 8, float(xy[1]) * 16 + 16)
			lvl.camera.reset_smoothing()
			continue
		if s.begins_with("tab:"):
			lvl.show_tab(s.substr(4))
			continue
		var parts := s.split(":")
		var act := parts[0]
		var f := int(parts[1]) if parts.size() > 1 else 10
		if act != "wait":
			Input.action_press(act)
		for i in f:
			await physics_frame
		if act != "wait":
			Input.action_release(act)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
