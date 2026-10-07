extends SceneTree
## Entry point for the screenshot tour:
##   godot --path . --rendering-driver opengl3 -s res://tests/run_screenshots.gd


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var tour: Node = (load("res://tests/screenshot_tour.gd") as GDScript).new()
	tour.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(tour)
	tour.run()
