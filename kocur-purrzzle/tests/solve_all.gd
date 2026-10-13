extends SceneTree
# Usage: godot --headless --path . -s res://tests/solve_all.gd [-- write]
func _init() -> void:
	var pars := {}
	var bad := 0
	for i in Levels.LIST.size():
		var L = Levels.LIST[i]
		var a := Solver.solve(L.rows)
		var b := Solver.solve(L.rows, true)
		print("L%02d %-18s par=%d fishpar=%d states=%d/%d %s" % [i + 1, L.name, a.moves, b.moves, a.states, b.states, a.path])
		if a.moves < 0 or (b.moves < 0 and Puzzle.new(L.rows).fish_total > 0):
			bad += 1
		pars[str(i)] = {"par": a.moves, "fishpar": b.moves, "path": a.path, "fishpath": b.path}
	print("UNSOLVABLE/BAD: %d" % bad)
	if OS.get_cmdline_user_args().has("write"):
		var f := FileAccess.open("res://scripts/pars.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(pars, "\t"))
	quit(1 if bad > 0 else 0)
