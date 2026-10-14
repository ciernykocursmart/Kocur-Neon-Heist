extends SceneTree
# Design aid: godot --headless --path . -s res://tests/tune.gd -- frame.txt k tries minpar
# '?' cells become rocks (k of them, random) or ice. Prints the best solvable layouts. Final levels are stored as fixed data.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var frame := Array(FileAccess.get_file_as_string(a[0]).strip_edges().split("\n"))
	var k := int(a[1])
	var tries := int(a[2])
	var minpar := int(a[3])
	var cells := []
	for y in frame.size():
		for x in frame[y].length():
			if frame[y][x] == "?":
				cells.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var best := -1
	var shown := 0
	for t in tries:
		var pick := {}
		while pick.size() < k:
			pick[cells[rng.randi() % cells.size()]] = true
		var rows := []
		for y in frame.size():
			var s: String = frame[y]
			var r := ""
			for x in s.length():
				var c := s[x]
				if c == "?":
					c = "#" if pick.has(Vector2i(x, y)) else "i"
				r += c
			rows.append(r)
		var res := Solver.solve(rows, false, 20000)
		if res.moves >= minpar and res.moves > best:
			best = res.moves
			print("PAR %d  %s" % [res.moves, res.path])
			print("\n".join(rows))
	quit()
