extends Node
## Test harness: runs every test module, records each assertion with
## evidence, prints a summary and writes JSON + Markdown reports.

const MODULES := [
	"res://tests/test_vehicle.gd",
	"res://tests/test_track.gd",
	"res://tests/test_race.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_ui.gd",
]

var results: Array[Dictionary] = []
var current_module := ""
var filter := ""
var report_dir := "user://test_reports"
var _start_ms := 0


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "all":
		filter = args[0]
	if args.size() > 1:
		report_dir = args[1]
	_start_ms = Time.get_ticks_msec()
	print("Kocur Kart test suite (Godot %s)" % Engine.get_version_info()["string"])
	for path in MODULES:
		if filter != "" and not path.contains(filter):
			continue
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			record(path.get_file(), false, "module failed to compile")
			continue
		current_module = path.get_file().get_basename()
		print("\n## %s" % current_module)
		var mod: Node = script.new()
		mod.name = current_module
		add_child(mod)
		await mod.run(self)
		mod.queue_free()
		await get_tree().process_frame
	_finish()


## Records one check. `evidence` should state the measured values.
func check(condition: bool, test_name: String, evidence := "") -> bool:
	record(test_name, condition, evidence)
	return condition


func record(test_name: String, passed: bool, evidence: String) -> void:
	results.append({"module": current_module, "name": test_name, "passed": passed, "evidence": evidence})
	print("  [%s] %s%s" % ["PASS" if passed else "FAIL", test_name, ("  -- " + evidence) if evidence != "" else ""])


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish() -> void:
	var passed := 0
	for r in results:
		if r["passed"]:
			passed += 1
	var failed := results.size() - passed
	var secs := (Time.get_ticks_msec() - _start_ms) / 1000.0
	print("\n%d checks, %d passed, %d failed (%.1f s)" % [results.size(), passed, failed, secs])
	for r in results:
		if not r["passed"]:
			print("  FAILED: %s / %s -- %s" % [r["module"], r["name"], r["evidence"]])
	DirAccess.make_dir_recursive_absolute(report_dir)
	var f := FileAccess.open(report_dir.path_join("results.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "seconds": secs, "results": results}, "  "))
		f.close()
	var md := FileAccess.open(report_dir.path_join("results.md"), FileAccess.WRITE)
	if md:
		md.store_line("| Module | Test | Result | Evidence |")
		md.store_line("|---|---|---|---|")
		for r in results:
			md.store_line("| %s | %s | %s | %s |" % [r["module"], r["name"], "PASS" if r["passed"] else "**FAIL**", String(r["evidence"]).replace("|", "/")])
		md.close()
	get_tree().quit(0 if failed == 0 else 1)
