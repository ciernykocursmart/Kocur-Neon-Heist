extends SceneTree
## Loads every script and scene in the project; exits non-zero on failure.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://scenes", files)
	for f in files:
		var r: Resource = load(f)
		if r == null or (r is GDScript and not (r as GDScript).can_instantiate()):
			printerr("LOAD FAIL: ", f)
			failures += 1
	print("Loaded %d files, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)
