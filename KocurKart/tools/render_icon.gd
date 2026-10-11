extends SceneTree
## Rasterises icon.svg to PNGs for the .ico and store art.
##   godot --headless --path . -s res://tools/render_icon.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for s in [16, 24, 32, 48, 64, 128, 256, 512]:
		var img := Image.new()
		img.load_svg_from_string(svg, s / 256.0)
		img.save_png(out.path_join("icon_%d.png" % s))
	quit()
