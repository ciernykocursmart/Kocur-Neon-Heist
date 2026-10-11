class_name MeshKit
extends RefCounted
## Small procedural mesh accumulator. Triangles are given with an intended
## facing normal and re-ordered automatically to Godot's clockwise front-face
## winding, so builders never have to think about vertex order.
## All game art (karts, cats, props, tracks) is assembled with this.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var colors := PackedColorArray()
var use_uv2 := false


func is_empty() -> bool:
	return verts.is_empty()


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, n := Vector3.ZERO,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var face := (b - a).cross(c - a)
	if n == Vector3.ZERO:
		n = -face.normalized()
	elif face.dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	verts.append_array([a, b, c])
	normals.append_array([n, n, n])
	uvs.append_array([ua, ub, uc])
	colors.append_array([col, col, col])
	if use_uv2:
		uv2s.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## Quad a-b-c-d (any consistent order around the edge) facing `n`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n := Vector3.ZERO) -> void:
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a).normalized()
		if n.y < -0.001:
			n = -n
	tri(a, b, c, col, n)
	tri(a, c, d, col, n)


## Smooth-shaded strip triangle with explicit per-vertex data (roads).
func vtri(p: Array, nrm: Array, uv: Array, uv2: Array, col: Array, facing: Vector3) -> void:
	var face: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var order := [0, 1, 2] if face.dot(facing) <= 0.0 else [0, 2, 1]
	for k in order:
		verts.append(p[k])
		normals.append(nrm[k])
		uvs.append(uv[k])
		uv2s.append(uv2[k])
		colors.append(col[k])


func append_mesh(other: MeshKit, xform := Transform3D.IDENTITY, tint := Color.WHITE) -> void:
	var basis := xform.basis
	for i in other.verts.size():
		verts.append(xform * other.verts[i])
		normals.append((basis * other.normals[i]).normalized())
		uvs.append(other.uvs[i])
		colors.append(other.colors[i] * tint)
		if use_uv2:
			uv2s.append(other.uv2s[i] if i < other.uv2s.size() else Vector2.ZERO)


func commit(material: Material = null, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = colors
	if use_uv2 and uv2s.size() == verts.size():
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func faces() -> PackedVector3Array:
	return verts


# ---------------------------------------------------------------------------
# Primitives. All take a transform and a colour; low-poly by design.
# ---------------------------------------------------------------------------

func box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces_idx := [[0, 1, 2, 3, Vector3.FORWARD], [5, 4, 7, 6, Vector3.BACK], [4, 0, 3, 7, Vector3.LEFT],
		[1, 5, 6, 2, Vector3.RIGHT], [3, 2, 6, 7, Vector3.UP], [4, 5, 1, 0, Vector3.DOWN]]
	for f in faces_idx:
		var n: Vector3 = (xf.basis * f[4]).normalized()
		quad(xf * c[f[0]], xf * c[f[1]], xf * c[f[2]], xf * c[f[3]], col, n)


## Tapered box: bottom size `a`, top size `b` (x, z), height h. Good for
## kart bodies, houses, rocks.
func frustum(xf: Transform3D, a: Vector2, b: Vector2, h: float, col: Color, top_col := Color(0, 0, 0, 0)) -> void:
	if top_col.a == 0.0:
		top_col = col
	var bot := [Vector3(-a.x, 0, -a.y), Vector3(a.x, 0, -a.y), Vector3(a.x, 0, a.y), Vector3(-a.x, 0, a.y)]
	var top := [Vector3(-b.x, h, -b.y), Vector3(b.x, h, -b.y), Vector3(b.x, h, b.y), Vector3(-b.x, h, b.y)]
	var center := xf * Vector3(0, h * 0.5, 0)
	for i in 4:
		var j := (i + 1) % 4
		var p0: Vector3 = xf * bot[i]
		var p1: Vector3 = xf * bot[j]
		var p2: Vector3 = xf * top[j]
		var p3: Vector3 = xf * top[i]
		var mid := (p0 + p1 + p2 + p3) * 0.25
		var n := (p1 - p0).cross(p3 - p0).normalized()
		if n.dot(mid - center) < 0.0:
			n = -n
		quad(p0, p1, p2, p3, col, n)
	quad(xf * top[0], xf * top[1], xf * top[2], xf * top[3], top_col, (xf.basis * Vector3.UP).normalized())
	quad(xf * bot[0], xf * bot[1], xf * bot[2], xf * bot[3], col, (xf.basis * Vector3.DOWN).normalized())


func cylinder(xf: Transform3D, r_bottom: float, r_top: float, h: float, col: Color, sides := 8, caps := true) -> void:
	var center := xf * Vector3(0, h * 0.5, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := xf * Vector3(cos(a0) * r_bottom, 0, sin(a0) * r_bottom)
		var b1 := xf * Vector3(cos(a1) * r_bottom, 0, sin(a1) * r_bottom)
		var t0 := xf * Vector3(cos(a0) * r_top, h, sin(a0) * r_top)
		var t1 := xf * Vector3(cos(a1) * r_top, h, sin(a1) * r_top)
		var mid := (b0 + b1 + t0 + t1) * 0.25
		var n := (mid - center)
		n = (n - (xf.basis * Vector3.UP).normalized() * n.dot((xf.basis * Vector3.UP).normalized())).normalized()
		if r_top <= 0.001:
			tri(b0, b1, t0, col, n)
		else:
			quad(b0, b1, t1, t0, col, n)
		if caps:
			var up := (xf.basis * Vector3.UP).normalized()
			tri(xf * Vector3.ZERO, b0, b1, col, -up)
			if r_top > 0.001:
				tri(xf * Vector3(0, h, 0), t0, t1, col, up)


func cone(xf: Transform3D, r: float, h: float, col: Color, sides := 7) -> void:
	cylinder(xf, r, 0.0, h, col, sides, true)


## Low-poly sphere (UV sphere with few rings). `squash` scales Y.
func sphere(xf: Transform3D, r: float, col: Color, rings := 4, sides := 8) -> void:
	var center := xf.origin
	var pts := []
	for y in rings + 1:
		var row := []
		var phi := PI * y / rings
		for x in sides:
			var th := TAU * x / sides
			row.append(xf * Vector3(sin(phi) * cos(th) * r, cos(phi) * r, sin(phi) * sin(th) * r))
		pts.append(row)
	for y in rings:
		for x in sides:
			var x1 := (x + 1) % sides
			var a: Vector3 = pts[y][x]
			var b: Vector3 = pts[y][x1]
			var c: Vector3 = pts[y + 1][x1]
			var d: Vector3 = pts[y + 1][x]
			var mid := (a + b + c + d) * 0.25
			var n := (mid - center).normalized()
			if y == 0:
				tri(a, c, d, col, n)
			elif y == rings - 1:
				tri(a, b, c, col, n)
			else:
				quad(a, b, c, d, col, n)


## Triangular prism (roofs, ears, ramps). Base width w (x), depth d (z), height h.
func prism(xf: Transform3D, w: float, d: float, h: float, col: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var p := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(0, h, -hd),
		Vector3(-hw, 0, hd), Vector3(hw, 0, hd), Vector3(0, h, hd)]
	for i in 6:
		p[i] = xf * p[i]
	var center: Vector3 = (p[0] + p[1] + p[2] + p[3] + p[4] + p[5]) / 6.0
	tri(p[0], p[1], p[2], col, ((p[0] + p[1] + p[2]) / 3.0 - center).normalized())
	tri(p[3], p[4], p[5], col, ((p[3] + p[4] + p[5]) / 3.0 - center).normalized())
	_side(p[0], p[2], p[5], p[3], col, center)
	_side(p[1], p[2], p[5], p[4], col, center)
	_side(p[0], p[1], p[4], p[3], col, center)


func _side(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, center: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	if n.dot((a + b + c + d) * 0.25 - center) < 0.0:
		n = -n
	quad(a, b, c, d, col, n)


## Extrudes a 2D cross-section (x = outward, y = up) along a list of frames.
## frames: Array of Transform3D (basis.x = outward, basis.y = up).
func extrude(frames: Array, profile: PackedVector2Array, col: Color, closed_profile := false) -> void:
	var segs := profile.size() - (0 if closed_profile else 1)
	for f in frames.size() - 1:
		var A: Transform3D = frames[f]
		var B: Transform3D = frames[f + 1]
		for k in segs:
			var k2 := (k + 1) % profile.size()
			var a := A * Vector3(profile[k].x, profile[k].y, 0)
			var b := A * Vector3(profile[k2].x, profile[k2].y, 0)
			var c := B * Vector3(profile[k2].x, profile[k2].y, 0)
			var d := B * Vector3(profile[k].x, profile[k].y, 0)
			var e := profile[k2] - profile[k]
			var n2 := Vector2(e.y, -e.x).normalized()
			var n := (A.basis.x * n2.x + A.basis.y * n2.y).normalized()
			quad(a, b, c, d, col, n)
