extends RefCounted
## Base class for test suites. Each `test_*` method is run by tests/run_tests.gd.
## Assertions record failures instead of aborting, so one run reports everything.

const Battle = preload("res://scripts/core/battle.gd")
const Missions = preload("res://scripts/data/missions.gd")
const UD = preload("res://scripts/data/units_data.gd")

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


func note(text: String) -> void:
	notes.append(text)


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func clear_scene() -> void:
	tree.paused = false
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


## Builds a battle from an inline map. squad: [[hero_id, level], ...]
func make_battle(rows: Array, squad: Array, objective := {"type": "eliminate", "text": "test"}, extra := {}) -> Battle:
	var m := {"id": "test", "name": "Test", "map": rows, "objective": objective, "optional": [], "alert": 0, "slots": 4}
	for k in extra:
		m[k] = extra[k]
	var entries := []
	for p: Array in squad:
		entries.append({"hero_id": p[0], "level": p[1], "upgrades": p[2] if p.size() > 2 else {}})
	var b := Battle.new()
	b.setup(m, entries, "normal")
	b.take_events()
	return b


func unit_named(b: Battle, kind: String) -> RefCounted:
	for u in b.units:
		if u.kind == kind and u.on_field():
			return u
	return null
