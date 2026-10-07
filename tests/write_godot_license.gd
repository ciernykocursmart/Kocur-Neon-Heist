extends SceneTree
## Writes build/windows/LICENSE_GODOT.txt (Godot's MIT licence, which must
## ship with every distributed build). Run:
##   godot --headless --path . -s res://tests/write_godot_license.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/windows"))
	var f := FileAccess.open("res://build/windows/LICENSE_GODOT.txt", FileAccess.WRITE)
	f.store_string("KOCUR: NEON HEIST is built with Godot Engine.\nhttps://godotengine.org/license\n\n" + Engine.get_license_text())
	f.close()
	quit()
