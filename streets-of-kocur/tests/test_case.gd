extends RefCounted
## Base class for test suites. Each `test_*` method is run by tests/run_tests.gd.
## Assertions record failures instead of aborting, so one run reports everything.

const B = preload("res://scripts/data/balance.gd")
const Levels = preload("res://scripts/data/levels.gd")
const Bot = preload("res://scripts/debug/autoplay_bot.gd")
const DT := 1.0 / 60.0

var tree: SceneTree
var failures: Array[String] = []
var asserts := 0
var notes: Array[String] = []


## Scripted input: the test sets `held` (move/run) and queues button presses.
class Pad:
	var move := Vector2.ZERO
	var run := false
	var presses: Array = []  ## e.g. ["attack"], consumed one per frame

	func press(b: String) -> void:
		presses.append(b)

	func poll(_p: Node) -> Dictionary:
		var d := {"move": move, "jump": false, "attack": false, "special": false, "grab": false, "run": run}
		if not presses.is_empty():
			d[presses.pop_front()] = true
		return d


func before_each() -> void:
	pass


func after_each() -> void:
	game().bot_input = null
	game().god_mode = false


func check(cond: bool, msg: String) -> bool:
	asserts += 1
	if not cond:
		failures.append(msg)
	return cond


func eq(actual: Variant, expected: Variant, msg: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String) -> bool:
	return check(absf(actual - expected) <= tol, "%s (expected %.2f +- %.2f, got %.2f)" % [msg, expected, tol, actual])


func note(text: String) -> void:
	notes.append(text)


func game() -> Node:
	return tree.root.get_node("Game")


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func clear_scene() -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	var cur := tree.current_scene
	if cur and is_instance_valid(cur):
		cur.queue_free()
		tree.current_scene = null
		await frames(2)
	var tr: Node = tree.root.get_node("Transition")
	tr.busy = false


func spawn_scene(path: String) -> Node:
	await clear_scene()
	var s: Node = load(path).instantiate()
	tree.root.add_child(s)
	tree.current_scene = s
	await frames(3)
	return s


## Loads a level ready for scripted play: manual stepping, intro skipped,
## a Pad attached as input. Encounters before `checkpoint` count as cleared.
func start_level(idx: int, checkpoint := 0, pad: Object = null) -> Node:
	var g := game()
	g.begin_level(idx)
	g.checkpoint = checkpoint
	g.bot_input = pad if pad != null else Pad.new()
	var lv: Node = await spawn_scene("res://scenes/level.tscn")
	lv.set_physics_process(false)
	lv.flow = "play"
	lv.player.control_locked = false
	return lv


func step(lv: Node, n: int) -> void:
	for i in n:
		lv._physics_process(DT)


## A bare test arena: level 1 with every encounter already cleared, so the
## test controls exactly which enemies exist.
func arena() -> Node:
	var lv: Node = await start_level(0, 99)
	lv.enc.list = []
	lv.player.position = Vector2(1000, 560)
	lv.cam_x = 1000.0
	lv.lock_arena(1000.0)
	return lv


func add_enemy(lv: Node, kind: String, pos: Vector2, st := "idle") -> Node:
	var e: Node = lv.spawn_enemy(kind, 1, 4242)
	e.position = pos
	e.set_state(st)
	e.facing = -1 if pos.x > lv.player.position.x else 1
	return e
