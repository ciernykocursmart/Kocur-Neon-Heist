extends SceneTree
## Automated test runner.
##   godot --headless --path . -s res://tests/run_tests.gd [-- suite_name ...]
## Runs every tests/suites/test_*.gd (or only the named suites), prints a
## report, writes it to user://test_report.txt and exits with code 1 on any
## failure. Uses its own save/settings files so a real save is never touched.

const SUITE_DIR := "res://tests/suites/"


func _initialize() -> void:
	call_deferred("_run")


func _isolate() -> void:
	var sm: Node = root.get_node("SaveManager")
	var st: Node = root.get_node("Settings")
	var cp: Node = root.get_node("Campaign")
	sm.path = "user://test_save.json"
	st.path = "user://test_settings.cfg"
	for f in ["user://test_save.json", "user://test_save.json.tmp", "user://test_settings.cfg", "user://test_save_corrupt.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	st.reset_defaults()
	cp.data = cp.defaults()
	root.get_node("Transition").battle_request = {}
	root.get_node("Transition").busy = false
	paused = false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var files: Array[String] = []
	for f in DirAccess.get_files_at(SUITE_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			if args.is_empty() or f.get_basename() in args or f.get_basename().trim_prefix("test_") in args:
				files.append(f)
	files.sort()
	var started := Time.get_ticks_msec()
	var total := 0
	var failed := 0
	var asserts := 0
	var lines: Array[String] = []
	for f in files:
		var script: GDScript = load(SUITE_DIR + f)
		if script == null or not script.can_instantiate():
			lines.append("FAIL  %s  (could not load suite)" % f)
			print(lines[-1])
			failed += 1
			total += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and not methods.has(mname):
				methods.append(mname)
		for mname in methods:
			_isolate()
			var suite: RefCounted = script.new()
			suite.tree = self
			var t0 := Time.get_ticks_msec()
			await suite.before_each()
			await suite.call(mname)
			await suite.after_each()
			await suite.clear_scene()
			total += 1
			asserts += suite.asserts
			if suite.asserts == 0:
				suite.failures.append("test made no assertions")
			var ok: bool = suite.failures.is_empty()
			if not ok:
				failed += 1
			var line := "%s  %s.%s  (%d asserts, %d ms)" % ["PASS" if ok else "FAIL", f.get_basename(), mname,
				suite.asserts, Time.get_ticks_msec() - t0]
			lines.append(line)
			print(line)
			for fl: String in suite.failures:
				lines.append("      - " + fl)
				print("      - " + fl)
			for n: String in suite.notes:
				lines.append("      * " + n)
				print("      * " + n)
	var summary := "RESULT: %d tests, %d passed, %d failed, %d assertions, %.1f s" % [total, total - failed, failed,
		asserts, (Time.get_ticks_msec() - started) / 1000.0]
	lines.append(summary)
	print(summary)
	var fa := FileAccess.open("user://test_report.txt", FileAccess.WRITE)
	if fa:
		fa.store_string("\n".join(lines) + "\n")
		fa.close()
	_isolate()
	quit(1 if failed > 0 else 0)
