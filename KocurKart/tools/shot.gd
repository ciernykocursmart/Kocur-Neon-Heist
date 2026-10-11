extends SceneTree
## Renders screenshots of a track from the chase camera for visual review.
##   xvfb-run godot --path . -s res://tools/shot.gd -- <track_id> <out_dir> [s1,s2,...]

var track: Track
var kart: Kart
var cam: ChaseCamera
var out := ""
var shots: Array = []
var idx := 0
var wait := 0
var tid := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	tid = args[0]
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	if args.size() > 2:
		for v in args[2].split(","):
			shots.append(float(v))
	else:
		shots = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9]
	call_deferred("_go")


func _go() -> void:
	var scene := Node3D.new()
	get_root().add_child(scene)
	track = Track.new()
	scene.add_child(track)
	track.setup(TrackCatalog.get_track(tid))
	if ClassDB.class_exists("TrackDecor") or ResourceLoader.exists("res://scripts/track/track_decor.gd"):
		pass
	RaceEnvironment.apply(scene, track.theme)
	kart = KartFactory.create({"racer": "kocur", "kart": "alley", "paint": "crimson", "accessory": "scarf"})
	kart.track = track
	scene.add_child(kart)
	cam = ChaseCamera.new()
	scene.add_child(cam)
	cam.current = true
	_place()
	process_frame.connect(_tick)


func _place() -> void:
	var s: float = shots[idx] * track.length
	kart.place(track.respawn_transform(s))
	cam.follow(kart)
	wait = 0


func _tick() -> void:
	wait += 1
	if wait == 12:
		var img := get_root().get_texture().get_image()
		img.save_png(out.path_join("%s_%02d.png" % [tid, idx]))
		idx += 1
		if idx >= shots.size():
			quit()
			return
		_place()
