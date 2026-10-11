class_name MenuBackdrop
extends Node3D
## Living 3D background for menus: a decorated circuit with AI karts lapping
## it and a slow cinematic camera.

var track: Track
var karts: Array[Kart] = []
var cam: Camera3D
var _t := 0.0
var _focus := 0
var _switch := 9.0


func build(track_id := "whiskerwood", count := 4) -> void:
	track = Track.new()
	add_child(track)
	track.setup(TrackCatalog.get_track(track_id))
	RaceEnvironment.apply(self, track.theme)
	var ids := ["kocur", "marmalade", "duchess", "tux", "ziggy", "sushi"]
	for i in count:
		var rid: String = ids[i]
		var pers: Dictionary = Catalog.RIVALS[rid]
		var k := KartFactory.create({"racer": rid, "kart": pers["kart"], "paint": pers["paint"], "accessory": "scarf" if i == 0 else "none"})
		k.track = track
		k.controller = AIDriver.new("normal", pers, 40 + i)
		add_child(k)
		k.place(track.respawn_transform(track.length * (0.1 + 0.07 * i), -3.0 + i * 2.0))
		k.control_enabled = true
		karts.append(k)
	for k in karts:
		k.controller.others = karts
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 1500.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	cam.current = true


func _physics_process(_delta: float) -> void:
	for k in karts:
		if k.controller.recover_requested or k.loc.off_track or k.global_position.y < track.kill_y:
			k.controller.recover_requested = false
			k.recover()


func _process(delta: float) -> void:
	if karts.is_empty():
		return
	_t += delta
	_switch -= delta
	if _switch <= 0.0:
		_switch = 9.0
		_focus = (_focus + 1) % karts.size()
	var k := karts[_focus]
	var xf := k.get_global_transform_interpolated()
	var fwd := -xf.basis.z
	var side := fwd.cross(Vector3.UP)
	var orbit := sin(_t * 0.25) * 0.8
	var target := xf.origin + side * (6.5 * cos(orbit)) + fwd * (4.0 * sin(orbit) - 2.0) + Vector3.UP * 2.2
	cam.global_position = cam.global_position.lerp(target, clampf(delta * 2.5, 0.0, 1.0)) if _t > 0.2 else target
	cam.look_at(xf.origin + Vector3.UP * 0.8 + fwd * 1.5, Vector3.UP)
