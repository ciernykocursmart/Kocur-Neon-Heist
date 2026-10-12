extends "res://tests/test_case.gd"
## Grid, terrain, line of sight, pathfinding and movement rules.

const Grid = preload("res://scripts/core/grid.gd")

const MAP := [
	"1....#....",
	"..T..#..r.",
	"..~..#....",
	".....,....",
	"..%..#..^.",
]


func test_bounds_and_terrain() -> void:
	var b := make_battle(MAP, [["nox", 1]])
	var g: Grid = b.grid
	eq(g.w, 10, "map width")
	eq(g.h, 5, "map height")
	check(g.in_bounds(Vector2i(0, 0)) and g.in_bounds(Vector2i(9, 4)), "corners in bounds")
	check(not g.in_bounds(Vector2i(-1, 0)) and not g.in_bounds(Vector2i(10, 0)) and not g.in_bounds(Vector2i(0, 5)), "outside is out of bounds")
	eq(g.terrain(Vector2i(5, 0)), "wall", "wall parsed")
	eq(g.terrain(Vector2i(2, 1)), "forest", "forest parsed")
	eq(g.terrain(Vector2i(2, 2)), "water", "water parsed")
	eq(g.terrain(Vector2i(5, 3)), "road", "road parsed")
	eq(g.move_cost(Vector2i(2, 1)), 2, "forest costs 2")
	eq(g.move_cost(Vector2i(2, 4)), 2, "mud costs 2")
	eq(g.move_cost(Vector2i(8, 4)), 2, "hill costs 2")
	check(not g.walkable(Vector2i(5, 0)), "wall not walkable")
	check(not g.walkable(Vector2i(2, 2)), "water not walkable")
	eq(g.defense(Vector2i(2, 1)), 1, "forest gives +1 DEF")
	eq(g.range_bonus(Vector2i(8, 4)), 1, "hill gives +1 range")
	eq(g.terrain(Vector2i(-3, 2)), "wall", "out-of-map reads as wall")


func test_line_of_sight() -> void:
	var b := make_battle(MAP, [["nox", 1]])
	var g: Grid = b.grid
	check(not g.has_los(Vector2i(4, 1), Vector2i(6, 1)), "wall blocks sight")
	check(g.has_los(Vector2i(4, 3), Vector2i(6, 3)), "gap in the wall (road) gives sight")
	check(g.has_los(Vector2i(1, 2), Vector2i(3, 2)), "water does not block sight")
	check(g.has_los(Vector2i(1, 1), Vector2i(3, 1)), "forest does not block sight")
	check(g.has_los(Vector2i(0, 0), Vector2i(0, 4)), "clear column")
	check(not g.has_los(Vector2i(3, 0), Vector2i(7, 1)), "diagonal line through the wall is blocked")
	eq(g.has_los(Vector2i(2, 3), Vector2i(8, 3)), g.has_los(Vector2i(8, 3), Vector2i(2, 3)), "line of sight is symmetric")
	# corner peek: a single blocking corner does not block
	var b2 := make_battle(["1.#", "...", "..."], [["nox", 1]])
	check(b2.grid.has_los(Vector2i(1, 0), Vector2i(2, 1)), "adjacent diagonal past one wall corner is visible")
	var b3 := make_battle(["1#.", "#..", "..."], [["nox", 1]])
	check(not b3.grid.has_los(Vector2i(0, 0), Vector2i(1, 1)), "diagonal between two walls is blocked")


func test_reachable_respects_costs_and_walls() -> void:
	var b := make_battle([
		"1T.......",
		".#.......",
		".#.......",
		".........",
	], [["bramble", 1]])  # Guardian, MOV 3
	var u = unit_named(b, "guardian")
	var cells: Array[Vector2i] = b.reachable_cells(u)
	check(cells.has(Vector2i(0, 3)), "3 straight steps reachable")
	check(not cells.has(Vector2i(1, 3)), "4 steps not reachable")
	check(cells.has(Vector2i(1, 0)), "forest (cost 2) reachable")
	check(cells.has(Vector2i(2, 0)), "beyond forest reachable at cost 3")
	check(not cells.has(Vector2i(3, 0)), "cost 4 not reachable")
	check(not cells.has(Vector2i(1, 1)) and not cells.has(Vector2i(1, 2)), "walls never reachable")
	for c in cells:
		check(b.grid.in_bounds(c), "reachable cell %s inside map" % str(c))
		var p: Array[Vector2i] = b.path_to(u, c)
		check(p.size() >= 2 and p[0] == u.pos and p[p.size() - 1] == c, "path to %s starts at unit and ends at target" % str(c))
		var cost := 0
		for i in range(1, p.size()):
			check(Grid.dist(p[i - 1], p[i]) == 1, "path steps are orthogonal")
			check(b.grid.walkable(p[i]), "path avoids impassable tiles")
			cost += b.grid.move_cost(p[i])
		check(cost <= u.move, "path cost %d within MOV" % cost)


func test_occupancy_rules() -> void:
	var b := make_battle([
		"12r...",
		"......",
	], [["nox", 1], ["bramble", 1]])
	var nox = unit_named(b, "shadowblade")
	var cells: Array[Vector2i] = b.reachable_cells(nox)
	check(not cells.has(Vector2i(1, 0)), "cannot end on an ally's tile")
	check(not cells.has(Vector2i(2, 0)), "cannot end on an enemy's tile")
	check(not b.cmd_move(nox, Vector2i(2, 0)), "move onto enemy rejected")
	check(not b.cmd_move(nox, Vector2i(1, 0)), "move onto ally rejected")
	check(not b.cmd_move(nox, Vector2i(-1, 0)), "move outside the map rejected")
	check(not b.cmd_move(nox, Vector2i(12, 0)), "move far outside the map rejected")
	# corridor: allies can be passed, enemies cannot
	var b2 := make_battle(["12...", "#####"], [["nox", 1], ["bramble", 1]])
	var n2 = unit_named(b2, "shadowblade")
	check(b2.reachable_cells(n2).has(Vector2i(4, 0)), "can walk through an ally in a corridor")
	var b3 := make_battle(["1r...", "#####"], [["nox", 1]])
	var n3 = unit_named(b3, "shadowblade")
	eq(b3.reachable_cells(n3).size(), 0, "an enemy blocks the corridor completely")


func test_move_path_matches_display() -> void:
	var b := make_battle([
		"1.#....",
		"..#.T..",
		".......",
	], [["nox", 1]])
	var nox = unit_named(b, "shadowblade")
	var dest := Vector2i(3, 2)
	var shown: Array[Vector2i] = b.path_to(nox, dest)
	check(b.cmd_move(nox, dest), "move accepted")
	var evs := b.take_events()
	var moved: Array = []
	for e in evs:
		if e["t"] == "move":
			moved = e["path"]
	eq(moved, shown, "the animated path equals the displayed path")
	eq(nox.pos, dest, "unit ends where the player clicked")


func test_astar_finds_paths() -> void:
	var b := make_battle([
		"1....",
		"####.",
		".....",
		".####",
		".....",
	], [["nox", 1]])
	var g: Grid = b.grid
	var pass_fn := func(c: Vector2i) -> bool: return g.walkable(c)
	var cost_fn := func(c: Vector2i) -> int: return g.move_cost(c)
	var p := g.astar(Vector2i(0, 0), Vector2i(4, 4), pass_fn, cost_fn)
	eq(p.size(), 17, "A* finds the long zig-zag path (17 cells)")
	for c in p:
		check(g.walkable(c), "A* path cell walkable")
	var none := g.astar(Vector2i(0, 0), Vector2i(0, 1), pass_fn, cost_fn)
	eq(none.size(), 0, "no path into a wall")


func test_pathfinder_and_chill() -> void:
	var b := make_battle([
		"1TTTTTT.",
		"s.......",
		"........",
	], [["nox", 1]])
	var st = unit_named(b, "stalker")
	var f: Dictionary = b.move_field(st)
	check(f["cost"].has(Vector2i(5, 0)), "stalker ignores forest cost")
	var bramble_like: Dictionary = b.move_field(unit_named(b, "shadowblade"), 6)
	check(not bramble_like["cost"].has(Vector2i(6, 0)) or int(bramble_like["cost"][Vector2i(6, 0)]) > 6, "normal units pay forest cost")
	var nox = unit_named(b, "shadowblade")
	var before: int = nox.effective_move()
	nox.status["chilled"] = 2
	eq(nox.effective_move(), before - 2, "chilled: -2 MOV")
	nox.move = 2
	eq(nox.effective_move(), 1, "movement never drops below 1")
