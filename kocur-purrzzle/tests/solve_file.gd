extends SceneTree
# godot --headless --path . -s res://tests/solve_file.gd -- file.txt   (levels separated by blank lines, first line = title)
func _init() -> void:
	var txt := FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])
	for block in txt.split("\n\n"):
		var lines := Array(block.strip_edges().split("\n"))
		if lines.size() < 3:
			continue
		var title: String = lines.pop_front()
		var a := Solver.solve(lines, false, 300000)
		var b := Solver.solve(lines, true, 300000)
		print("%-18s par=%d fishpar=%d states=%d %s" % [title, a.moves, b.moves, a.states, a.path])
	quit()
