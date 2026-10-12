extends RefCounted
## Base class for test suites. Each `test_*` method is run by tests/run_tests.gd.
## Assertions record failures instead of aborting, so one run reports everything.

var tree: SceneTree
var failures: Array[String] = []
var asserts := 0
var notes: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String) -> bool:
	asserts += 1
	if not cond:
		failures.append(msg)
	return cond


func eq(actual: Variant, expected: Variant, msg: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String) -> bool:
	return check(absf(actual - expected) <= tol, "%s (expected %.2f +/- %.2f, got %.2f)" % [msg, expected, tol, actual])


func gt(actual: float, bound: float, msg: String) -> bool:
	return check(actual > bound, "%s (expected > %.2f, got %.2f)" % [msg, bound, actual])


func lt(actual: float, bound: float, msg: String) -> bool:
	return check(actual < bound, "%s (expected < %.2f, got %.2f)" % [msg, bound, actual])


func note(text: String) -> void:
	notes.append(text)


# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------

func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func process_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Loads a level the same way the game does and waits until it is built.
func spawn_level(id: String) -> Node:
	await clear_scene()
	tree.root.get_node("Transition").next_level_id = id
	var lvl: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(lvl)
	tree.current_scene = lvl
	await frames(3)
	return lvl


func spawn_scene(path: String) -> Node:
	await clear_scene()
	var s: Node = load(path).instantiate()
	tree.root.add_child(s)
	tree.current_scene = s
	await process_frames(3)
	return s


func clear_scene() -> void:
	tree.paused = false
	release_all()
	var cur := tree.current_scene
	if cur and is_instance_valid(cur):
		cur.queue_free()
		tree.current_scene = null
		await process_frames(2)


func press(action: String) -> void:
	Input.action_press(action)


func release(action: String) -> void:
	Input.action_release(action)


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "pounce", "interact", "pause"]:
		Input.action_release(a)


## Holds an action for n physics frames.
func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


## Places the player on the floor of a map cell and lets physics settle.
func place_player(lvl: Node, cell: Vector2i) -> void:
	var p: Node2D = lvl.player
	p.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 15)
	p.velocity = Vector2.ZERO
	await frames(4)


## Builds a level from an inline ASCII map (same legend as the real levels).
func spawn_map(map: String, as_level := "1-1") -> Node:
	await clear_scene()
	tree.root.get_node("Transition").next_level_id = as_level
	var lvl: Node = load("res://scenes/level.tscn").instantiate()
	lvl.map_override = map.strip_edges()
	tree.root.add_child(lvl)
	tree.current_scene = lvl
	await frames(3)
	return lvl


func enemies_of(lvl: Node) -> Array[Node]:
	var out: Array[Node] = []
	for e in lvl.enemies_root.get_children():
		out.append(e)
	return out
