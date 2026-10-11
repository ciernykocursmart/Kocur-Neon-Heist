extends SceneTree
## Screenshots of real scenes (menus, garage, races) for visual review.
##   xvfb-run godot --path . -s res://tools/scene_shot.gd -- <scene> <out.png> <frames> [track] [mode]

var frames := 120
var out := ""
var n := 0
var shots := []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1]
	frames = int(a[2])
	var scene: String = a[0]
	if scene.ends_with("race.tscn"):
		var g = root.get_node("Game")
		g.race_config = {"track": a[3] if a.size() > 3 else "whiskerwood", "mode": a[4] if a.size() > 4 else "single",
			"laps": 3, "difficulty": "normal", "player": {"racer": "kocur", "kart": "alley", "paint": "crimson", "accessory": "scarf"},
			"autopilot": true, "persist": false, "seed": 4}
	change_scene_to_file.call_deferred(scene)
	process_frame.connect(_tick)


func _tick() -> void:
	n += 1
	if n == frames:
		root.get_texture().get_image().save_png(out)
		quit()
