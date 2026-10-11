class_name TrackBuilder
extends RefCounted
## Generates the drivable geometry of a Track: road, curbs, shoulders, walls,
## embankments, ground or water, ramps, boost pads and the start gantry, plus
## matching collision. Decoration is handled separately by TrackDecor.

const WALL_COLLISION_HEIGHT := 4.5


static func build(track: Track) -> void:
	var th := track.theme
	var mats := _materials(th)
	var world := StaticBody3D.new()
	world.name = "World"
	world.collision_layer = 1
	world.collision_mask = 0
	track.add_child(world)
	var wall_body := StaticBody3D.new()
	wall_body.name = "Walls"
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	track.add_child(wall_body)

	var paths: Array[TrackPath] = [track.main]
	paths.append_array(track.shortcuts)
	var floor_faces := PackedVector3Array()
	var wall_faces := PackedVector3Array()
	for pi in paths.size():
		var res := _build_path(track, paths, pi, mats)
		floor_faces.append_array(res[0])
		wall_faces.append_array(res[1])
	for r in track.ramps:
		floor_faces.append_array(_build_ramp(track, r))
	_add_shape(world, floor_faces)
	_add_shape(wall_body, wall_faces)
	_build_ground(track, world, mats)
	_build_pads(track)
	_build_start(track)


static func _add_shape(body: StaticBody3D, faces: PackedVector3Array) -> void:
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)


static func _materials(th: Dictionary) -> Dictionary:
	var m := {}
	var road := ShaderMaterial.new()
	road.shader = preload("res://shaders/road.gdshader")
	var rd: Dictionary = th["road"]
	road.set_shader_parameter("base_color", rd["base"])
	road.set_shader_parameter("base_color2", rd["base2"])
	road.set_shader_parameter("line_color", rd["line"])
	road.set_shader_parameter("pattern", rd["pattern"])
	road.set_shader_parameter("line_emission", rd["emission"])
	road.set_shader_parameter("center_dash", rd.get("center", 0.0))
	m["road"] = road
	var sc_road: ShaderMaterial = road.duplicate()
	sc_road.set_shader_parameter("pattern", 3 if rd["pattern"] != 1 else 1)
	sc_road.set_shader_parameter("base_color", Color(rd["base"]).lerp(Color(0.62, 0.45, 0.3), 0.6))
	sc_road.set_shader_parameter("base_color2", Color(rd["base2"]).lerp(Color(0.5, 0.35, 0.22), 0.6))
	sc_road.set_shader_parameter("center_dash", 0.0)
	sc_road.set_shader_parameter("start_line", 0.0)
	m["shortcut"] = sc_road
	if th.has("ice_color"):
		var ice: ShaderMaterial = road.duplicate()
		var ic: Color = th["ice_color"]
		ice.set_shader_parameter("base_color", ic)
		ice.set_shader_parameter("base_color2", ic.darkened(0.15))
		ice.set_shader_parameter("roughness_value", 0.08)
		ice.set_shader_parameter("center_dash", 0.0)
		ice.set_shader_parameter("start_line", 0.0)
		m["ice"] = ice
	var curb := ShaderMaterial.new()
	curb.shader = preload("res://shaders/curb.gdshader")
	var cd: Dictionary = th["curb"]
	curb.set_shader_parameter("color_a", cd["a"])
	curb.set_shader_parameter("color_b", cd["b"])
	curb.set_shader_parameter("plain", cd["plain"])
	curb.set_shader_parameter("emission", cd["emission"])
	m["curb"] = curb
	var terr := ShaderMaterial.new()
	terr.shader = preload("res://shaders/terrain.gdshader")
	var td: Dictionary = th["terrain"]
	terr.set_shader_parameter("color_a", td["a"])
	terr.set_shader_parameter("color_b", td["b"])
	terr.set_shader_parameter("speck", td["speck"])
	terr.set_shader_parameter("speck_amount", td["speck_amount"])
	terr.set_shader_parameter("scale", td["scale"])
	m["terrain"] = terr
	var skirt: ShaderMaterial = terr.duplicate()
	var sk: Color = th["skirt"]
	skirt.set_shader_parameter("color_a", sk)
	skirt.set_shader_parameter("color_b", sk.darkened(0.2))
	skirt.set_shader_parameter("speck_amount", 0.0)
	m["skirt"] = skirt
	m["flat"] = flat_material()
	m["glow"] = flat_material(0.6, 2.2)
	return m


static func flat_material(rough := 0.8, emission := 0.0) -> ShaderMaterial:
	var f := ShaderMaterial.new()
	f.shader = preload("res://shaders/flat.gdshader")
	f.set_shader_parameter("roughness_value", rough)
	f.set_shader_parameter("emission_strength", emission)
	return f


static func _mesh_node(parent: Node, mesh: ArrayMesh, name: String, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Cross-section of one path. Returns [floor_faces, wall_faces].
static func _build_path(track: Track, paths: Array[TrackPath], pi: int, mats: Dictionary) -> Array:
	var path := paths[pi]
	var is_main := pi == 0
	var n := path.size()
	var count := n + 1 if path.closed else n
	var shoulder := track.shoulder if is_main else 1.6
	var y_off := 0.0 if is_main else 0.035
	var road := MeshKit.new()
	road.use_uv2 = true
	var ice := MeshKit.new()
	ice.use_uv2 = true
	var curb := MeshKit.new()
	var verge := MeshKit.new()
	var skirt := MeshKit.new()
	var floor_faces := PackedVector3Array()
	var wall_faces := PackedVector3Array()
	var wall_frames := {-1: [], 1: []}
	var wall_runs := {-1: [], 1: []}

	# Per-sample cross-section data.
	var P := []
	for k in count:
		var i := k % n
		var p := path.positions[i] + Vector3.UP * y_off
		var r := path.rights[i]
		var hw := path.widths[i] * 0.5
		var s := path.s_values[i] if k < n else path.length
		var main_s := s if is_main else path.to_main_s(s)
		var gap := is_main and track.is_gap(main_s)
		var corner := clampf((absf(path.curvature[i]) - 0.006) / 0.012, 0.0, 1.0)
		var side_info := {}
		for side in [-1, 1]:
			var open := is_main and track.is_open_side(main_s, side)
			var sh := 0.8 if open else shoulder
			var wall := not open and not gap and _wall_allowed(track, paths, pi, i, side, hw + Track.CURB_W + sh)
			side_info[side] = {"sh": sh, "wall": wall, "open": open}
		P.append({"p": p, "r": r, "hw": hw, "s": s, "gap": gap, "corner": corner, "side": side_info,
			"n": r.cross(path.tangents[i]).normalized(), "ice": is_main and track.is_ice(main_s)})

	for k in count - 1:
		var A: Dictionary = P[k]
		var B: Dictionary = P[k + 1]
		if A["gap"] or B["gap"]:
			continue
		var target := ice if (A["ice"] and B["ice"] and mats.has("ice")) else road
		# Road surface.
		var pts := [A["p"] - A["r"] * A["hw"], A["p"] + A["r"] * A["hw"], B["p"] + B["r"] * B["hw"], B["p"] - B["r"] * B["hw"]]
		var nr := [A["n"], A["n"], B["n"], B["n"]]
		var uv := [Vector2(-1, A["s"]), Vector2(1, A["s"]), Vector2(1, B["s"]), Vector2(-1, B["s"])]
		var uv2 := [Vector2(A["hw"], 0), Vector2(A["hw"], 0), Vector2(B["hw"], 0), Vector2(B["hw"], 0)]
		var white := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
		target.vtri([pts[0], pts[1], pts[2]], [nr[0], nr[1], nr[2]], [uv[0], uv[1], uv[2]], [uv2[0], uv2[1], uv2[2]], white.slice(0, 3), Vector3.UP)
		target.vtri([pts[0], pts[2], pts[3]], [nr[0], nr[2], nr[3]], [uv[0], uv[2], uv[3]], [uv2[0], uv2[2], uv2[3]], white.slice(0, 3), Vector3.UP)
		floor_faces.append_array(PackedVector3Array([pts[0], pts[1], pts[2], pts[0], pts[2], pts[3]]))
		for side in [-1, 1]:
			var sa: Dictionary = A["side"][side]
			var sb: Dictionary = B["side"][side]
			var ra: Vector3 = A["r"] * side
			var rb: Vector3 = B["r"] * side
			var a0: Vector3 = A["p"] + ra * A["hw"]
			var b0: Vector3 = B["p"] + rb * B["hw"]
			var a1: Vector3 = A["p"] + ra * (A["hw"] + Track.CURB_W) + Vector3.UP * 0.04
			var b1: Vector3 = B["p"] + rb * (B["hw"] + Track.CURB_W) + Vector3.UP * 0.04
			# Curb (UV.y = progress so the shader can stripe it).
			var cc := Color(A["corner"], 0, 0)
			var cn: Vector3 = A["n"]
			_curb_quad(curb, a0, a1, b1, b0, A["s"], B["s"], cc, Color(B["corner"], 0, 0), cn)
			floor_faces.append_array(PackedVector3Array([a0, a1, b1, a0, b1, b0]))
			# Verge / shoulder.
			var a2: Vector3 = A["p"] + ra * (A["hw"] + Track.CURB_W + sa["sh"]) - Vector3.UP * 0.03
			var b2: Vector3 = B["p"] + rb * (B["hw"] + Track.CURB_W + sb["sh"]) - Vector3.UP * 0.03
			verge.quad(a1, a2, b2, b1, Color.WHITE, cn)
			floor_faces.append_array(PackedVector3Array([a1, a2, b2, a1, b2, b1]))
			# Embankment or cliff down to the ground.
			var ga := Vector3(a2.x, track.ground_y, a2.z)
			var gb := Vector3(b2.x, track.ground_y, b2.z)
			if sa["open"] or not is_main:
				if a2.y - track.ground_y > 0.2:
					skirt.quad(a2, ga, gb, b2, Color.WHITE, ra)
			else:
				var drop_a: float = maxf(a2.y - track.ground_y, 0.0)
				var drop_b: float = maxf(b2.y - track.ground_y, 0.0)
				var a3: Vector3 = a2 + ra * (0.6 + drop_a * 1.3)
				var b3: Vector3 = b2 + rb * (0.6 + drop_b * 1.3)
				a3.y = track.ground_y - 0.05
				b3.y = track.ground_y - 0.05
				skirt.quad(a2, a3, b3, b2, Color.WHITE, (ra + Vector3.UP).normalized())
	# Walls, as continuous runs between openings.
	for side in [-1, 1]:
		var run: Array = []
		for k in count:
			var D: Dictionary = P[k]
			var si: Dictionary = D["side"][side]
			if si["wall"]:
				var r: Vector3 = D["r"] * side
				var base: Vector3 = D["p"] + r * (D["hw"] + Track.CURB_W + si["sh"]) - Vector3.UP * 0.03
				run.append(Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), base))
			else:
				if run.size() >= 2:
					wall_runs[side].append(run)
				run = []
		if run.size() >= 2:
			wall_runs[side].append(run)
	var walls := MeshKit.new()
	var wall_glow := MeshKit.new()
	var posts := []
	for side in [-1, 1]:
		for run in wall_runs[side]:
			TrackWalls.build_wall(track.theme["wall"], run, walls, wall_glow, posts)
			for f in run.size() - 1:
				var A3: Transform3D = run[f]
				var B3: Transform3D = run[f + 1]
				var a := A3.origin - Vector3.UP * 0.6
				var b := B3.origin - Vector3.UP * 0.6
				var c := B3.origin + Vector3.UP * WALL_COLLISION_HEIGHT
				var d := A3.origin + Vector3.UP * WALL_COLLISION_HEIGHT
				wall_faces.append_array(PackedVector3Array([a, b, c, a, c, d]))
	var suffix := "Main" if is_main else "Shortcut%d" % pi
	_mesh_node(track, road.commit(mats["shortcut"] if not is_main else mats["road"]), "Road" + suffix, false)
	if not ice.is_empty():
		_mesh_node(track, ice.commit(mats["ice"]), "Ice" + suffix, false)
	_mesh_node(track, curb.commit(mats["curb"]), "Curb" + suffix, false)
	_mesh_node(track, verge.commit(mats["terrain"]), "Verge" + suffix, false)
	if not skirt.is_empty():
		_mesh_node(track, skirt.commit(mats["skirt"]), "Embankment" + suffix, false)
	if not walls.is_empty():
		_mesh_node(track, walls.commit(mats["flat"]), "Walls" + suffix)
	if not wall_glow.is_empty():
		_mesh_node(track, wall_glow.commit(mats["glow"]), "WallGlow" + suffix, false)
	if not posts.is_empty():
		TrackWalls.build_posts(track, track.theme["wall"], posts, mats["flat"])
	return [floor_faces, wall_faces]


static func _curb_quad(kit: MeshKit, a0: Vector3, a1: Vector3, b1: Vector3, b0: Vector3, sa: float, sb: float, ca: Color, cb: Color, n: Vector3) -> void:
	kit.vtri([a0, a1, b1], [n, n, n], [Vector2(0, sa), Vector2(1, sa), Vector2(1, sb)], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [ca, ca, cb], Vector3.UP)
	kit.vtri([a0, b1, b0], [n, n, n], [Vector2(0, sa), Vector2(1, sb), Vector2(0, sb)], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [ca, cb, cb], Vector3.UP)


## A wall is omitted where another path's road passes through that spot
## (shortcut entrances/exits) so junctions open up automatically.
static func _wall_allowed(track: Track, paths: Array[TrackPath], pi: int, i: int, side: int, dist: float) -> bool:
	var path := paths[pi]
	var wp := path.positions[i] + path.rights[i] * side * dist
	for oi in paths.size():
		if oi == pi:
			continue
		var other := paths[oi]
		var reach := (track.shoulder + Track.CURB_W + 1.5) if oi == 0 else (Track.CURB_W + 2.5)
		for j in other.size():
			var op := other.positions[j]
			if absf(op.y - wp.y) > 4.0:
				continue
			var lim := other.widths[j] * 0.5 + reach
			if Vector2(op.x - wp.x, op.z - wp.z).length_squared() < lim * lim:
				return false
	return true


static func _build_ground(track: Track, world: StaticBody3D, mats: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.main.positions:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var center := (lo + hi) * 0.5
	var size := (hi - lo) + Vector2(900, 900)
	var kit := MeshKit.new()
	var y := track.ground_y
	var h := size * 0.5
	# Subdivided so per-vertex fog and lighting stay smooth.
	var cells := 12
	for gx in cells:
		for gz in cells:
			var x0 := center.x - h.x + size.x * gx / cells
			var x1 := center.x - h.x + size.x * (gx + 1) / cells
			var z0 := center.y - h.y + size.y * gz / cells
			var z1 := center.y - h.y + size.y * (gz + 1) / cells
			kit.quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Color.WHITE, Vector3.UP)
	if track.water:
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/water.gdshader")
		var mi := _mesh_node(track, kit.commit(wm), "Water", false)
		mi.position.y = 0.0
	else:
		_mesh_node(track, kit.commit(mats["terrain"]), "Ground", false)
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, 2.0, size.y)
		var cs := CollisionShape3D.new()
		cs.shape = box
		cs.position = Vector3(center.x, y - 1.0, center.y)
		world.add_child(cs)
	# Raised land slabs: quays, plazas, islands.
	for l in track.def.get("land", []):
		var lk := MeshKit.new()
		var x0 := float(l[0])
		var z0 := float(l[1])
		var x1 := float(l[2])
		var z1 := float(l[3])
		var top := float(l[4])
		var bottom := y - 3.0
		lk.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5, (z0 + z1) * 0.5)), Vector3(x1 - x0, top - bottom, z1 - z0), Color.WHITE)
		_mesh_node(track, lk.commit(mats["terrain"]), "Land", false)
		var lb := BoxShape3D.new()
		lb.size = Vector3(x1 - x0, top - bottom, z1 - z0)
		var lcs := CollisionShape3D.new()
		lcs.shape = lb
		lcs.position = Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5, (z0 + z1) * 0.5)
		world.add_child(lcs)
	track.set_meta("bounds_center", center)
	track.set_meta("bounds_size", hi - lo)


static func _build_ramp(track: Track, r: Dictionary) -> PackedVector3Array:
	var s: float = r["s"]
	var i := track.main.index_at_s(s)
	var j := track.main.index_at_s(s + float(r["length"]))
	var p0 := track.main.positions[i] + track.main.rights[i] * float(r["lateral"])
	var p1 := track.main.positions[j] + track.main.rights[j] * float(r["lateral"])
	var right := track.main.rights[i]
	var hw := float(r["width"]) * 0.5
	var h := float(r["height"])
	var top := p1 + Vector3.UP * h
	var a := p0 - right * hw - Vector3.UP * 0.05
	var b := p0 + right * hw - Vector3.UP * 0.05
	var c := top + right * hw
	var d := top - right * hw
	var e := p1 + right * hw - Vector3.UP * 0.05
	var f := p1 - right * hw - Vector3.UP * 0.05
	var kit := MeshKit.new()
	var stripes := 6
	for k in stripes:
		var t0 := float(k) / stripes
		var t1 := float(k + 1) / stripes
		var col := Color(0.98, 0.78, 0.1) if k % 2 == 0 else Color(0.12, 0.12, 0.14)
		kit.quad(a.lerp(d, t0), b.lerp(c, t0), b.lerp(c, t1), a.lerp(d, t1), col, (c - b).cross(right).normalized() * -1.0)
	kit.quad(d, c, e, f, Color(0.3, 0.3, 0.32), (p1 - p0).normalized())
	kit.tri(a, d, f, Color(0.3, 0.3, 0.32), -right)
	kit.tri(b, c, e, Color(0.3, 0.3, 0.32), right)
	_mesh_node(track, kit.commit(flat_material(0.6)), "Ramp")
	return PackedVector3Array([a, b, c, a, c, d, d, c, e, d, e, f])


static func _build_pads(track: Track) -> void:
	if track.pads.is_empty():
		return
	var kit := MeshKit.new()
	var paths: Array[TrackPath] = [track.main]
	paths.append_array(track.shortcuts)
	for pad in track.pads:
		var path := paths[int(pad.z)]
		var own_s := pad.x
		if int(pad.z) > 0:
			own_s = (pad.x - path.main_s_start) / maxf(path.main_s_end - path.main_s_start, 0.01) * path.length
		var i := path.index_at_s(own_s)
		var r := path.rights[i]
		var t := path.tangents[i]
		var base := path.positions[i] + r * pad.y + Vector3.UP * 0.06
		var hw := Track.PAD_WIDTH * 0.5
		# Three chevrons pointing forward.
		for c in 3:
			var o := base + t * (0.6 + c * 1.5)
			var tip := o + t * 1.1
			var col := Color(1.0, 0.55, 0.1) if c != 1 else Color(1.0, 0.85, 0.2)
			kit.quad(o - r * hw, o - r * hw * 0.55, tip, tip - r * 0.35, col, Vector3.UP)
			kit.quad(o + r * hw, o + r * hw * 0.55, tip, tip + r * 0.35, col, Vector3.UP)
		kit.quad(base - r * hw - t * 0.0 - Vector3.UP * 0.01, base + r * hw - Vector3.UP * 0.01,
			base + r * hw + t * Track.PAD_LENGTH - Vector3.UP * 0.01, base - r * hw + t * Track.PAD_LENGTH - Vector3.UP * 0.01,
			Color(0.35, 0.1, 0.45), Vector3.UP)
	var mi := _mesh_node(track, kit.commit(flat_material(0.4, 1.4)), "BoostPads", false)
	mi.set_meta("pads", true)


static func _build_start(track: Track) -> void:
	var i := track.main.index_at_s(0.0)
	var p := track.main.positions[i]
	var r := track.main.rights[i]
	var hw := track.main.widths[i] * 0.5 + Track.CURB_W + 0.6
	var yaw := track.main.yaw_at(i)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var col: Color = track.theme["wall"]["color2"]
	for side in [-1, 1]:
		var base := Transform3D(Basis(Vector3.UP, yaw), p + r * hw * side)
		kit.box(base.translated_local(Vector3(0, 3.2, 0)), Vector3(0.7, 6.4, 0.7), Color(0.2, 0.2, 0.24))
		kit.box(base.translated_local(Vector3(0, 0.25, 0)), Vector3(1.1, 0.5, 1.1), col)
	# Banner with checkered band and countdown lamps.
	var banner := xf.translated_local(Vector3(0, 6.0, 0))
	kit.box(banner, Vector3(hw * 2.0 + 0.7, 1.3, 0.4), Color(0.12, 0.12, 0.15))
	var squares := int(hw * 2.0 / 0.65)
	for k in squares:
		for row in 2:
			var c := Color(0.95, 0.95, 0.95) if (k + row) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var lx := -hw + 0.33 + k * 0.65
			for face in [-1, 1]:
				kit.box(banner.translated_local(Vector3(lx, 0.27 - row * 0.54, 0.21 * face)), Vector3(0.64, 0.53, 0.02), c)
	_mesh_node(track, kit.commit(flat_material(0.7)), "StartGantry")
	var lamps := Node3D.new()
	lamps.name = "StartLamps"
	lamps.transform = xf.translated_local(Vector3(0, 7.35, 0))
	track.add_child(lamps)
	for k in 4:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		sm.radial_segments = 12
		sm.rings = 6
		lamp.mesh = sm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.2, 0.05, 0.05)
		lm.emission_enabled = true
		lm.emission = Color(0, 0, 0)
		lamp.material_override = lm
		lamp.position = Vector3(-1.5 + k, 0, 0)
		lamp.name = "Lamp%d" % k
		lamps.add_child(lamp)
