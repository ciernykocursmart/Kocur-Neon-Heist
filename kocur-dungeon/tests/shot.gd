extends SceneTree
## Dev aid: renders a scene and saves screenshots (needs a display, e.g. xvfb-run).
## godot --path . -s res://tests/shot.gd -- <scene|level id> <out_prefix> [frames] [script_steps...]

var _args: PackedStringArray


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	var target := _args[0] if _args.size() > 0 else "1-1"
	var out := _args[1] if _args.size() > 1 else "/tmp/shot"
	var frames := int(_args[2]) if _args.size() > 2 else 90
	var tr: Node = root.get_node("Transition")
	if target.ends_with(".tscn"):
		change_scene_to_file(target)
	else:
		tr.next_level_id = target
		change_scene_to_file("res://scenes/level.tscn")
	for i in frames:
		await process_frame
	var lvl := current_scene
	var steps := _args.slice(3)
	var n := 0
	for s in steps:
		# step format: action:frames  (e.g. move_right:60) or shot or tp:x,y
		if s == "shot":
			_save(out + "_%d.png" % n)
			n += 1
			continue
		if s.begins_with("tp:"):
			var xy := s.substr(3).split(",")
			lvl.player.global_position = Vector2(float(xy[0]) * 16 + 8, float(xy[1]) * 16 + 16)
			lvl.camera.reset_smoothing()
			for i in 20:
				await process_frame
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
	_save(out + "_final.png")
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
