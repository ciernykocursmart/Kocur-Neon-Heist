extends SceneTree
## Renders Microsoft Store promo art from the menu backdrop. Run under Xvfb
## with --resolution WxH and env KOCUR_ART=<name>, KOCUR_TITLE=0/1.


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_ctrl)
	var bg = load("res://scripts/ui/neon_background.gd").new()
	root_ctrl.add_child(bg)
	if OS.get_environment("KOCUR_TITLE") == "1":
		var theme_script = load("res://scripts/core/ui_theme.gd")
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		var vp := root_ctrl.get_viewport_rect().size
		box.offset_left = -vp.x * 0.5
		box.offset_right = vp.x * 0.5
		box.offset_top = vp.y * 0.12
		box.offset_bottom = vp.y * 0.12 + 300
		box.alignment = BoxContainer.ALIGNMENT_BEGIN
		root_ctrl.add_child(box)
		var big := int(minf(vp.x, vp.y) * 0.17)
		box.add_child(theme_script.make_title("KOCUR", big, Color(0.25, 0.95, 1.0)))
		box.add_child(theme_script.make_title("N E O N   H E I S T", int(big * 0.32), Color(1.0, 0.25, 0.78)))
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://store_art/%s.png" % OS.get_environment("KOCUR_ART")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://store_art"))
	root.get_texture().get_image().save_png(path)
	print("saved ", path, " ", root.get_texture().get_size())
	quit()
