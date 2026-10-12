extends SceneTree
## Loads every script and scene in the project and reports failures.
func _initialize() -> void:
	var bad := 0
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://scenes", files)
	for f in files:
		var r = load(f)
		if r == null or (r is GDScript and not r.can_instantiate()):
			print("FAIL ", f)
			bad += 1
	print("checked %d files, %d failed" % [files.size(), bad])
	quit(1 if bad else 0)

func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
