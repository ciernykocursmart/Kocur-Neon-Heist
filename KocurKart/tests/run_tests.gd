extends SceneTree
## Headless test entry point:
##   godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- [filter] [report_dir]
## The suite is loaded after the first frame so autoloads are registered.


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var suite_script: GDScript = load("res://tests/test_suite.gd")
	if suite_script == null or not suite_script.can_instantiate():
		printerr("Test suite failed to compile.")
		quit(1)
		return
	var suite: Node = suite_script.new()
	suite.name = "TestSuite"
	suite.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(suite)
	suite.run()
