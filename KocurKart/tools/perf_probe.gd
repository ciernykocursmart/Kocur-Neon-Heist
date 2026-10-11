extends SceneTree
## Measures build time, CPU frame cost and render load of a full race scene.
##   xvfb-run godot --path . -s res://tools/perf_probe.gd -- <track>

var race: Race
var frames := 0
var t_proc := 0.0
var t_phys := 0.0
var max_proc := 0.0
var draw := 0.0
var prims := 0.0
var objs := 0.0
var build_ms := 0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var tid: String = OS.get_cmdline_user_args()[0]
	var t0 := Time.get_ticks_msec()
	race = load("res://scripts/race/race.gd").new()
	race.configure({"track": tid, "mode": "single", "laps": 3, "difficulty": "normal", "autopilot": true, "persist": false,
		"player": {"racer": "kocur", "kart": "alley", "paint": "crimson"}, "seed": 2})
	root.add_child(race)
	build_ms = Time.get_ticks_msec() - t0
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames < 300:
		return
	var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	t_proc += p
	max_proc = maxf(max_proc, p)
	t_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if frames == 600:
		var n := 300.0
		print("PERF %s build %d ms | process %.2f ms avg (max %.2f) | physics %.2f ms | draw calls %.0f | primitives %.0f | objects %.0f | nodes %d" % [
			race.track.def["id"], build_ms, t_proc / n, max_proc, t_phys / n, draw / n, prims / n, objs / n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		quit()
