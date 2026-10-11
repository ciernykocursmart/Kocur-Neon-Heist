class_name TrackWalls
extends RefCounted
## Themed barrier visuals. Each style is a cross-section profile extruded
## along the wall line (x = outward, y = up; listed counter-clockwise from
## the outer foot) plus optional repeated posts.


static func build_wall(wd: Dictionary, frames: Array, kit: MeshKit, glow: MeshKit, posts: Array) -> void:
	var col: Color = wd["color"]
	var col2: Color = wd["color2"]
	match String(wd["style"]):
		"fence":
			kit.extrude(frames, _rect(0.0, 0.14, 0.15, 0.95), col)
			kit.extrude(frames, _rect(-0.05, 0.12, 0.98, 1.12), col2)
			_posts(frames, posts, 4, 0.0)
		"rail":
			kit.extrude(frames, _rect(0.0, 0.3, 0.0, 0.32), col2)
			kit.extrude(frames, _rect(0.05, 0.16, 0.8, 0.95), col)
			_posts(frames, posts, 3, 0.1)
		"neon":
			kit.extrude(frames, _rect(0.0, 0.45, 0.0, 0.6), Color(0.1, 0.09, 0.15))
			var c2 := col
			glow.extrude(frames, _rect(0.08, 0.32, 0.6, 0.78), c2)
			glow.extrude(frames, _rect(-0.02, 0.0, 0.18, 0.3), col2)
		"snow":
			var prof := PackedVector2Array([Vector2(1.8, -0.1), Vector2(1.2, 0.85), Vector2(0.55, 1.15), Vector2(0.1, 0.8), Vector2(-0.1, -0.1)])
			kit.extrude(frames, prof, col)
			_posts(frames, posts, 6, 0.0)
		"rock":
			var rf := []
			for k in frames.size():
				var f: Transform3D = frames[k]
				var h := 0.75 + 0.45 * absf(sin(k * 1.7) * cos(k * 0.6))
				rf.append(f)
				rf[k] = f.scaled_local(Vector3(1.0, h, 1.0))
			var prof2 := PackedVector2Array([Vector2(1.5, -0.1), Vector2(1.3, 0.9), Vector2(0.7, 1.35), Vector2(0.15, 1.0), Vector2(-0.05, -0.1)])
			kit.extrude(rf, prof2, col)
		"hedge":
			kit.extrude(frames, _rect(0.0, 0.95, 0.0, 1.2), col)
			kit.extrude(frames, _rect(0.0, 0.95, 1.2, 1.3), col.lightened(0.15))
			_posts(frames, posts, 9, 0.47)
		_:
			kit.extrude(frames, _rect(0.0, 0.3, 0.0, 1.0), col)


## Counter-clockwise rectangle profile from x0..x1, y0..y1.
static func _rect(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1), Vector2(x0, y0)])


static func _posts(frames: Array, posts: Array, every: int, offset: float) -> void:
	for k in range(0, frames.size(), every):
		var f: Transform3D = frames[k]
		posts.append(f.translated_local(Vector3(offset, 0, 0)))


static func build_posts(track: Node3D, wd: Dictionary, posts: Array, mat: Material) -> void:
	var kit := MeshKit.new()
	var col2: Color = wd["color2"]
	var col: Color = wd["color"]
	match String(wd["style"]):
		"fence":
			kit.box(Transform3D(Basis(), Vector3(0.07, 0.65, 0)), Vector3(0.22, 1.3, 0.22), col.darkened(0.25))
			kit.box(Transform3D(Basis(), Vector3(0.07, 1.33, 0)), Vector3(0.28, 0.08, 0.28), col2)
		"rail":
			kit.cylinder(Transform3D(Basis(), Vector3(0, 0, 0)), 0.08, 0.08, 1.0, col, 6)
			kit.sphere(Transform3D(Basis(), Vector3(0, 1.02, 0)), 0.1, col2, 3, 6)
		"snow":
			kit.cylinder(Transform3D(Basis(), Vector3(0.3, 0, 0)), 0.05, 0.05, 2.0, Color(0.15, 0.15, 0.18), 5)
			kit.box(Transform3D(Basis(), Vector3(0.3, 1.8, 0)), Vector3(0.08, 0.4, 0.08), col2)
		"hedge":
			kit.cylinder(Transform3D(Basis(), Vector3(0, 0, 0)), 0.12, 0.12, 1.55, col2, 6)
			kit.sphere(Transform3D(Basis(), Vector3(0, 1.62, 0)), 0.17, col2, 3, 6)
	if kit.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = kit.commit(mat)
	mm.instance_count = posts.size()
	for k in posts.size():
		mm.set_instance_transform(k, posts[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallPosts"
	mmi.multimesh = mm
	track.add_child(mmi)
