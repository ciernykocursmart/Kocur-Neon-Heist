extends SceneTree
## Renders the key art scene (karts drifting in formation) for store art.
##   xvfb-run godot --path . --resolution 3840x2160 -s res://tools/key_art.gd -- <out.png>

var out := ""
var frames := 0
var karts: Array[Kart] = []
var cam: Camera3D


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	call_deferred("_go")


func _go() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var track := Track.new()
	scene.add_child(track)
	track.setup(TrackCatalog.get_track("whiskerwood"))
	RaceEnvironment.apply(scene, track.theme)
	var s := track.length * 0.93
	var lineup := [["kocur", "alley", "crimson", "scarf", 0.0, 0.0], ["marmalade", "thunder", "tangerine", "goggles", -3.4, -4.2],
		["duchess", "pounce", "rose", "crown", 3.2, -5.0], ["tux", "alley", "snow", "headphones", -0.4, -10.0]]
	for l in lineup:
		var k := KartFactory.create({"racer": l[0], "kart": l[1], "paint": l[2], "wheels": "sport", "accessory": l[3]})
		k.track = track
		scene.add_child(k)
		k.place(track.respawn_transform(s + float(l[5]), float(l[4])))
		k.global_position.y -= 0.6   # sit on the road (physics is frozen for the shot)
		k.process_mode = Node.PROCESS_MODE_DISABLED
		k.model.process_mode = Node.PROCESS_MODE_ALWAYS
		k.drifting = true
		k.drift_dir = 1 if l[4] <= 0.0 else -1
		k.drift_level = 2
		k.boost_time = 1.0 if l[0] == "kocur" else 0.0
		k.boost_kind = &"purr"
		k.forward_speed = 26.0
		k.steer = -0.6 * k.drift_dir
		karts.append(k)
	var lead := karts[0]
	var fwd := lead.forward_dir()
	var right := fwd.cross(Vector3.UP)
	cam = Camera3D.new()
	cam.fov = 40.0
	scene.add_child(cam)
	cam.global_position = lead.global_position + fwd * 6.8 + right * 2.2 + Vector3.UP * 0.95
	cam.look_at(lead.global_position + fwd * -3.5 - right * 0.6 + Vector3.UP * 1.25, Vector3.UP)
	cam.current = true
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	for k in karts:
		k.model.animate(k, 1.0 / 60.0)
	if frames == 70:
		root.get_texture().get_image().save_png(out)
		quit()
