extends SceneTree
## Headless test entry point. Run with:
##   godot --headless --path . -s res://tests/run_tests.gd
##
## The actual suite lives in test_suite.gd and is loaded after the first
## frame so the GameState/Sfx autoloads are registered before it compiles.


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
