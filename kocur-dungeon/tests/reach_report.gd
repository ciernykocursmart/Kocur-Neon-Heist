extends SceneTree
## Dev aid: prints reachability for one or all levels.
## godot --headless --path . -s res://tests/reach_report.gd -- [level_id]

const Reach := preload("res://tests/level_reach.gd")
const LevelCatalog := preload("res://scripts/data/level_catalog.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for lv in LevelCatalog.LEVELS:
		if args.size() > 0 and lv["id"] != args[0]:
			continue
		var t := Time.get_ticks_msec()
		var r := Reach.new()
		r.setup(lv["map"])
		r.analyze(false)
		var exits: Array = r.g.entities_of("X")
		var exit_ok: bool = exits.size() > 0 and r.can_interact(exits[0]["cell"])
		var missing_req: Array = []
		for e in r.g.entities_of("XK!lR"):
			if not r.can_interact(e["cell"]) and not r.can_touch(e["cell"]):
				missing_req.append("%s@%s" % [e["ch"], e["cell"]])
		var goals: Array[Vector2i] = []
		if exits.size() > 0:
			goals = r.goal_nodes(exits[0]["cell"])
		var dead := r.dead_ends(goals)
		var n_nodes := r.nodes.size()
		var r2 := Reach.new()
		r2.setup(lv["map"])
		r2.analyze(true)
		var missing_opt: Array = []
		for e in r2.g.entities_of("ogTf$R"):
			var c: Vector2i = e["cell"]
			if not r2.can_touch(c) and not r2.can_interact(c):
				missing_opt.append("%s@%d,%d" % [e["ch"], c.x, c.y])
		var dead2: Array = r2.dead_ends(r2.goal_nodes(exits[0]["cell"]) if exits.size() > 0 else goals)
		print("%s exit=%s nodes=%d sims=%d dead=%d dead_pounce=%d missing_req=%s missing_opt=%s (%d ms)" % [
			lv["id"], exit_ok, n_nodes, r.sims + r2.sims, dead.size(), dead2.size(), missing_req, missing_opt,
			Time.get_ticks_msec() - t])
		if dead2.size() > 0:
			print("   dead spots (pounce): ", dead2.slice(0, 12))
	quit()
