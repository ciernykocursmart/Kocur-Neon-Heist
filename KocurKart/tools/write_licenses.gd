extends SceneTree
## Writes the Godot engine licence text for the release ZIP.
##   godot --headless --path . -s res://tools/write_licenses.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(out.path_join("LICENSE_GODOT.txt"), FileAccess.WRITE)
	f.store_string(Engine.get_license_text())
	f.store_string("\n\nThird-party components:\n\n")
	var info := Engine.get_copyright_info()
	for c in info:
		f.store_string("- %s\n" % c["name"])
	f.close()
	quit()
