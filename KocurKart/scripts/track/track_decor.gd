class_name TrackDecor
extends RefCounted
## Scenery: scattered props (MultiMesh per prop variant), themed landmarks,
## corner warning signs, grandstands with crowds and a distant backdrop ring.
## Placement is seeded per track so every launch looks identical.

## [prop, count per km of circuit, min clearance from road edge, max distance]
const SCATTER := {
	"woods": [["pine", 60, 3.0, 120.0], ["oak", 30, 3.5, 110.0], ["bush", 50, 1.0, 45.0], ["mushroom", 9, 1.5, 30.0],
		["rock", 10, 1.5, 80.0], ["flowers", 26, 0.5, 30.0], ["tires", 0, 0.0, 0.0]],
	"pier": [["house", 0, 0.0, 0.0], ["crates", 10, 1.0, 14.0], ["barrels", 8, 1.0, 14.0], ["lamp", 0, 0.0, 0.0],
		["palm", 8, 3.0, 40.0], ["buoy", 14, 6.0, 120.0], ["boat", 6, 14.0, 150.0]],
	"neon": [["tower", 24, 14.0, 170.0], ["neon_sign", 10, 3.0, 30.0], ["billboard", 5, 6.0, 40.0]],
	"snow": [["snow_pine", 80, 2.0, 120.0], ["snow_rock", 12, 2.0, 70.0], ["snowman", 4, 2.0, 25.0], ["ice_crystal", 8, 2.0, 50.0], ["chalet", 3, 12.0, 90.0]],
	"safari": [["acacia", 16, 4.0, 130.0], ["baobab", 5, 6.0, 120.0], ["boulder", 14, 2.0, 90.0], ["grass", 40, 0.5, 50.0],
		["termite", 6, 3.0, 60.0], ["hut", 3, 10.0, 80.0], ["giraffe", 4, 10.0, 90.0]],
	"royal": [["topiary", 30, 1.0, 35.0], ["cone_tree", 36, 2.0, 90.0], ["flag", 16, 0.8, 10.0], ["statue", 5, 3.0, 40.0],
		["flowerbed", 22, 0.8, 25.0], ["catnip", 16, 2.0, 60.0], ["oak", 20, 4.0, 110.0]],
}

var track: Track
var rng := RandomNumberGenerator.new()
var _grid := {}
var _cell := 10.0
var _solid_mat: Material
var _glow_mat: Material


static func decorate(t: Track) -> void:
	var d := TrackDecor.new()
	d.track = t
	d.rng.seed = hash(String(t.def.get("id", "track")))
	d._solid_mat = TrackBuilder.flat_material(0.85)
	d._glow_mat = TrackBuilder.flat_material(0.5, 2.0)
	d._build_grid()
	d._scatter()
	d._landmarks()
	d._gates()
	d._signs()
	d._grandstand()
	d._backdrop()
	d._trackside()


# ---------------------------------------------------------------------------
# Road clearance grid
# ---------------------------------------------------------------------------

func _build_grid() -> void:
	var paths: Array[TrackPath] = [track.main]
	paths.append_array(track.shortcuts)
	for pi in paths.size():
		var p := paths[pi]
		var extra := Track.CURB_W + (track.shoulder if pi == 0 else 1.6) + 0.6
		for i in p.size():
			var pos := p.positions[i]
			var r := p.widths[i] * 0.5 + extra + maxf(pos.y - track.ground_y, 0.0) * 1.3
			var key := Vector2i(floori(pos.x / _cell), floori(pos.z / _cell))
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(Vector3(pos.x, pos.z, r))


## Distance from p (x, z) to the nearest road edge (negative = on the road).
func clearance(p: Vector2, search := 3) -> float:
	var best := INF
	var kx := floori(p.x / _cell)
	var kz := floori(p.y / _cell)
	for dx in range(-search, search + 1):
		for dz in range(-search, search + 1):
			var arr = _grid.get(Vector2i(kx + dx, kz + dz))
			if arr == null:
				continue
			for e in arr:
				var dd: float = Vector2(e.x - p.x, e.y - p.y).length() - e.z
				best = minf(best, dd)
	return best


## Ground height: raised land slabs (quays, plazas) or the base ground/water.
func _ground_at(p: Vector2) -> float:
	for l in track.def.get("land", []):
		if p.x >= l[0] and p.x <= l[2] and p.y >= l[1] and p.y <= l[3]:
			return float(l[4])
	return track.ground_y


func _on_land(p: Vector2) -> bool:
	for l in track.def.get("land", []):
		if p.x >= l[0] + 1.0 and p.x <= l[2] - 1.0 and p.y >= l[1] + 1.0 and p.y <= l[3] - 1.0:
			return true
	return false


# ---------------------------------------------------------------------------
# Scatter
# ---------------------------------------------------------------------------

func _scatter() -> void:
	var theme_id: String = track.def.get("theme", "woods")
	var list: Array = SCATTER.get(theme_id, [])
	var center: Vector2 = track.get_meta("bounds_center")
	var size: Vector2 = track.get_meta("bounds_size")
	var km := track.length / 1000.0
	for entry in list:
		var kind: String = entry[0]
		var count := int(round(float(entry[1]) * km * 2.2))
		if count <= 0:
			continue
		var min_c: float = entry[2]
		var max_d: float = entry[3]
		var xforms: Array[Transform3D] = []
		var attempts := count * 30
		while xforms.size() < count and attempts > 0:
			attempts -= 1
			var p := Vector2(center.x + rng.randf_range(-0.5, 0.5) * (size.x + max_d * 2.0),
				center.y + rng.randf_range(-0.5, 0.5) * (size.y + max_d * 2.0))
			var c := clearance(p, int(ceil(minf(max_d, 30.0) / _cell)) + 1)
			if c < min_c or c > max_d:
				continue
			if track.water:
				var wants_land := kind not in ["buoy", "boat"]
				if wants_land != _on_land(p):
					continue
			var s := rng.randf_range(0.8, 1.3)
			var y := _ground_at(p)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, y, p.y)))
		_emit(kind, xforms, 3)


## Splits instances across a few randomized mesh variants.
func _emit(kind: String, xforms: Array[Transform3D], variants: int, shadows := true) -> void:
	if xforms.is_empty():
		return
	for v in variants:
		var solid := MeshKit.new()
		var glow := MeshKit.new()
		PropLibrary.build(kind, solid, glow, rng)
		var mine: Array[Transform3D] = []
		for i in range(v, xforms.size(), variants):
			mine.append(xforms[i])
		if mine.is_empty():
			continue
		if not solid.is_empty():
			_multimesh(kind, solid.commit(_solid_mat), mine, shadows)
		if not glow.is_empty():
			_multimesh(kind + "_glow", glow.commit(_glow_mat), mine, false)


func _multimesh(name: String, mesh: Mesh, xforms: Array[Transform3D], shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Props_" + name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	track.add_child(mmi)


func _single(kind: String, xf: Transform3D) -> void:
	var arr: Array[Transform3D] = [xf]
	_emit(kind, arr, 1)


# ---------------------------------------------------------------------------
# Landmarks
# ---------------------------------------------------------------------------

func _landmarks() -> void:
	for lm in track.def.get("landmarks", []):
		var kind: String = lm[0]
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(lm[3]) if lm.size() > 3 else 0.0)),
			Vector3(float(lm[1]), track.ground_y, float(lm[2])))
		var sc := float(lm[4]) if lm.size() > 4 else 1.0
		xf = xf.scaled_local(Vector3(sc, sc, sc))
		var solid := MeshKit.new()
		var glow := MeshKit.new()
		Landmarks.build(kind, solid, glow, rng)
		var root := Node3D.new()
		root.name = "Landmark_" + kind
		root.transform = xf
		track.add_child(root)
		if not solid.is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = solid.commit(_solid_mat)
			root.add_child(mi)
		if not glow.is_empty():
			var gi := MeshInstance3D.new()
			gi.mesh = glow.commit(_glow_mat)
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(gi)
		Landmarks.animate_hook(kind, root)


## Structures spanning the road (arches, tunnels, banners) at lap fractions.
func _gates() -> void:
	for g in track.def.get("gates", []):
		var s := float(g[0]) * track.length
		var kind: String = g[1]
		var span := float(g[2]) if g.size() > 2 else 1.0
		var i := track.main.index_at_s(s)
		var half := track.main.widths[i] * 0.5 + Track.CURB_W + track.shoulder + 1.2
		var solid := MeshKit.new()
		var glow := MeshKit.new()
		var count := maxi(1, int(span))
		for k in count:
			var si := track.main.index_at_s(s + k * 6.0)
			var xf := Transform3D(Basis(Vector3.UP, track.main.yaw_at(si)), track.main.positions[si])
			Landmarks.build_gate(kind, solid, glow, xf, half, k, count)
		var root := Node3D.new()
		root.name = "Gate_" + kind
		track.add_child(root)
		if not solid.is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = solid.commit(_solid_mat)
			root.add_child(mi)
		if not glow.is_empty():
			var gi := MeshInstance3D.new()
			gi.mesh = glow.commit(_glow_mat)
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(gi)


# ---------------------------------------------------------------------------
# Corner warning signs: chevron boards on the outside of every real corner.
# ---------------------------------------------------------------------------

func _signs() -> void:
	var p := track.main
	var n := p.size()
	var solid := MeshKit.new()
	var glow := MeshKit.new()
	var last_s := -INF
	var neon := String(track.def.get("theme", "")) == "neon"
	for i in n:
		var k := p.curvature[i]
		if absf(k) < 0.018:
			continue
		# Local curvature peak only.
		if absf(p.curvature[p.wrap_index(i - 3)]) > absf(k) or absf(p.curvature[p.wrap_index(i + 3)]) > absf(k):
			continue
		if p.s_values[i] - last_s < 45.0:
			continue
		last_s = p.s_values[i]
		var j := p.wrap_index(i - 14)
		var side := -1 if k > 0.0 else 1   # outside of the turn
		if track.is_open_side(p.s_values[j], side) or track.is_gap(p.s_values[j]):
			continue
		var dist := p.widths[j] * 0.5 + Track.CURB_W + track.shoulder + 0.9
		var base := p.positions[j] + p.rights[j] * side * dist
		var face := -p.tangents[j]
		face.y = 0.0
		var xf := Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), base)
		var arrows := 2 if absf(k) < 0.03 else 3
		_chevron(solid, glow if neon else solid, xf, arrows, k > 0.0)
	if not solid.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "CornerSigns"
		mi.mesh = solid.commit(_solid_mat)
		track.add_child(mi)
	if neon and not glow.is_empty():
		var gi := MeshInstance3D.new()
		gi.name = "CornerSignsGlow"
		gi.mesh = glow.commit(_glow_mat)
		track.add_child(gi)


func _chevron(solid: MeshKit, arrows_kit: MeshKit, xf: Transform3D, arrows: int, left: bool) -> void:
	var w := 1.2 * arrows + 0.4
	for side in [-1, 1]:
		solid.box(xf.translated_local(Vector3(side * (w * 0.5 - 0.15), 0.9, 0)), Vector3(0.14, 1.8, 0.14), Color(0.25, 0.25, 0.28))
	solid.box(xf.translated_local(Vector3(0, 2.1, 0.02)), Vector3(w, 1.1, 0.08), Color(0.1, 0.1, 0.12))
	var dir := -1.0 if left else 1.0
	for a in arrows:
		var cx := -w * 0.5 + 0.8 + a * 1.2
		var tip := xf * Vector3(cx + dir * 0.35, 2.1, -0.05)
		var top := xf * Vector3(cx - dir * 0.25, 2.5, -0.05)
		var bot := xf * Vector3(cx - dir * 0.25, 1.7, -0.05)
		var top2 := xf * Vector3(cx - dir * 0.05, 2.5, -0.05)
		var bot2 := xf * Vector3(cx - dir * 0.05, 1.7, -0.05)
		var tip2 := xf * Vector3(cx + dir * 0.55, 2.1, -0.05)
		var n := (xf.basis * Vector3(0, 0, -1)).normalized()
		var c := Color(1.0, 0.82, 0.1)
		arrows_kit.quad(top, top2, tip2, tip, c, n)
		arrows_kit.quad(bot, bot2, tip2, tip, c, n)


# ---------------------------------------------------------------------------
# Grandstand with crowd beside the start straight.
# ---------------------------------------------------------------------------

func _grandstand() -> void:
	var p := track.main
	var side := int(track.def.get("stand_side", -1))
	var solid := MeshKit.new()
	var crowd: Array[Transform3D] = []
	var colors := []
	var stand_len := 40.0
	for k in range(-int(stand_len / 2.0), int(stand_len / 2.0), 2):
		var i := p.index_at_s(float(k) - 12.0)
		if track.is_open_side(p.s_values[i], side):
			return
	var mid := p.index_at_s(-12.0)
	var r := p.rights[mid] * side
	var t := p.tangents[mid]
	t.y = 0.0
	t = t.normalized()
	var base := p.positions[mid] + r * (p.widths[mid] * 0.5 + Track.CURB_W + track.shoulder + 3.0)
	base.y = maxf(base.y, track.ground_y)
	var xf := Transform3D(Basis(r, Vector3.UP, r.cross(Vector3.UP)), base)
	if (xf.basis.z).dot(t) < 0.0:
		xf.basis.z = -xf.basis.z
	var steps := 5
	for s in steps:
		var y := 0.6 + s * 0.8
		var x := 1.0 + s * 1.1
		solid.box(xf.translated_local(Vector3(x, y * 0.5, 0)), Vector3(1.1, y, stand_len), Color(0.75, 0.75, 0.8) if s % 2 == 0 else Color(0.62, 0.62, 0.7))
		for c in int(stand_len / 1.1):
			if rng.randf() < 0.82:
				var z := -stand_len * 0.5 + 0.6 + c * 1.1
				crowd.append(xf.translated_local(Vector3(x, y + 0.45, z)))
				colors.append(Color.from_hsv(rng.randf(), 0.55, 0.95))
	var roof := Color(track.theme["curb"]["a"])
	solid.box(xf.translated_local(Vector3(3.2, 6.4, 0)), Vector3(7.5, 0.25, stand_len + 1.0), roof)
	for z in [-stand_len * 0.5, 0.0, stand_len * 0.5]:
		solid.box(xf.translated_local(Vector3(6.6, 3.2, z)), Vector3(0.3, 6.4, 0.3), Color(0.3, 0.3, 0.34))
	var mi := MeshInstance3D.new()
	mi.name = "Grandstand"
	mi.mesh = solid.commit(_solid_mat)
	track.add_child(mi)
	# Crowd: little cat spectators (body + head with ears), coloured per seat.
	var fan := MeshKit.new()
	fan.sphere(Transform3D(Basis().scaled(Vector3(1, 1.2, 0.9)), Vector3(0, 0.0, 0)), 0.3, Color.WHITE, 3, 6)
	fan.sphere(Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.24, Color.WHITE, 3, 6)
	for e in [-1, 1]:
		fan.prism(Transform3D(Basis(Vector3.FORWARD, e * 0.3), Vector3(e * 0.13, 0.62, 0)), 0.14, 0.06, 0.16, Color.WHITE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = fan.commit(_solid_mat)
	mm.instance_count = crowd.size()
	for i in crowd.size():
		mm.set_instance_transform(i, crowd[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crowd"
	mmi.multimesh = mm
	mmi.set_script(preload("res://scripts/track/crowd_bounce.gd"))
	track.add_child(mmi)


# ---------------------------------------------------------------------------
# Distant backdrop: mountains, skyline, islands or hills.
# ---------------------------------------------------------------------------

func _backdrop() -> void:
	var theme_id: String = track.def.get("theme", "woods")
	var center: Vector2 = track.get_meta("bounds_center")
	var size: Vector2 = track.get_meta("bounds_size")
	var radius := maxf(size.x, size.y) * 0.5 + 260.0
	var solid := MeshKit.new()
	var glow := MeshKit.new()
	var count := 26
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.08, 0.08)
		var r := radius + rng.randf_range(0.0, 120.0)
		var pos := Vector3(center.x + cos(a) * r, track.ground_y - 1.0, center.y + sin(a) * r)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos)
		match theme_id:
			"woods", "royal":
				var h := rng.randf_range(40.0, 90.0)
				solid.cone(xf, h * 1.4, h, Color(0.3, 0.5, 0.32).lerp(Color(0.45, 0.55, 0.62), rng.randf() * 0.6), 7)
			"snow":
				var h2 := rng.randf_range(90.0, 170.0)
				solid.cone(xf, h2 * 0.9, h2, Color(0.5, 0.56, 0.66), 6)
				solid.cone(xf.translated(Vector3(0, h2 * 0.55, 0)), h2 * 0.9 * 0.45, h2 * 0.45, Color(0.97, 0.98, 1.0), 6)
			"safari":
				var h3 := rng.randf_range(30.0, 70.0)
				solid.frustum(xf, Vector2(h3 * 1.1, h3 * 0.8), Vector2(h3 * 0.8, h3 * 0.55), h3, Color(0.78, 0.45, 0.32).lerp(Color(0.62, 0.4, 0.45), rng.randf()), Color(0.85, 0.55, 0.35))
			"neon":
				for b in 3:
					var bh := rng.randf_range(50.0, 150.0)
					var bw := rng.randf_range(16.0, 30.0)
					var bx := xf.translated_local(Vector3(b * 32.0 - 32.0, 0, 0))
					solid.box(bx.translated_local(Vector3(0, bh * 0.5, 0)), Vector3(bw, bh, bw), Color(0.07, 0.06, 0.12))
					var wc := Color(1.0, 0.3, 0.8) if rng.randf() < 0.5 else Color(0.2, 0.9, 1.0)
					for row in int(bh / 10.0):
						if rng.randf() < 0.6:
							glow.box(bx.translated_local(Vector3(0, 6.0 + row * 10.0, 0)), Vector3(bw + 0.3, 0.8, bw + 0.3), wc)
			"pier":
				if k % 3 == 0:
					var h4 := rng.randf_range(20.0, 50.0)
					solid.cone(xf, h4 * 2.0, h4, Color(0.35, 0.55, 0.35), 7)
					solid.cylinder(xf, h4 * 2.0, h4 * 2.0, 1.2, Color(0.93, 0.85, 0.62), 7)
	if not solid.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Backdrop"
		mi.mesh = solid.commit(_solid_mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		track.add_child(mi)
	if not glow.is_empty():
		var gi := MeshInstance3D.new()
		gi.name = "BackdropGlow"
		gi.mesh = glow.commit(_glow_mat)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		track.add_child(gi)


# ---------------------------------------------------------------------------
# Regular trackside details: lamps, tyre stacks at corners, pier houses.
# ---------------------------------------------------------------------------

func _trackside() -> void:
	var theme_id: String = track.def.get("theme", "woods")
	var p := track.main
	var lamps: Array[Transform3D] = []
	var tires: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	for i in range(0, p.size(), 1):
		var s := p.s_values[i]
		for side in [-1, 1]:
			if track.is_open_side(s, side) or track.is_gap(s):
				continue
			var edge := p.widths[i] * 0.5 + Track.CURB_W + track.shoulder
			var pos: Vector3 = p.positions[i] + p.rights[i] * side * (edge + 1.6)
			var face := Basis(Vector3.UP, p.yaw_at(i) + (PI * 0.5 if side > 0 else -PI * 0.5))
			if theme_id in ["neon", "pier"] and i % 12 == 0 and side == (1 if (i / 12) % 2 == 0 else -1):
				if clearance(Vector2(pos.x, pos.z), 2) > 0.6:
					lamps.append(Transform3D(face, pos))
			if theme_id == "woods" and absf(p.curvature[i]) > 0.02 and i % 4 == 0 and (p.curvature[i] > 0.0) == (side < 0):
				var tp: Vector3 = pos + p.rights[i] * side * 0.4
				if clearance(Vector2(tp.x, tp.z), 2) > 0.4:
					tires.append(Transform3D(Basis(), tp))
			if theme_id == "pier" and i % 5 == 0:
				var hp: Vector3 = p.positions[i] + p.rights[i] * side * (edge + 9.0)
				var hp2 := Vector2(hp.x, hp.z)
				if _on_land(hp2) and clearance(hp2, 2) > 5.5:
					hp.y = _ground_at(hp2)
					houses.append(Transform3D(face, hp))
	_emit("street_lamp" if theme_id == "neon" else "lamp", lamps, 1, false)
	_emit("tires", tires, 1)
	_emit("house", houses, 4)
