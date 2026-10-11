class_name TrackPath
extends RefCounted
## A road centreline sampled at uniform arc-length spacing.
##
## Built from control points with a centripetal Catmull-Rom spline. The main
## circuit is closed; shortcuts are open paths whose own arc length is mapped
## linearly onto a range of the main circuit's progress value (`s`), so race
## progress stays continuous when a kart takes the alternative route.

const SPACING := 2.0

var closed := true
var positions := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var widths := PackedFloat32Array()
var s_values := PackedFloat32Array()
var curvature := PackedFloat32Array()   ## signed heading change per metre (+ = left)
var length := 0.0
## Main-circuit progress at the start and end of this path (shortcuts only).
var main_s_start := 0.0
var main_s_end := 0.0


## `points`: Array of [x, z, height, width]. Width may be omitted.
static func build(points: Array, is_closed: bool, default_width: float) -> TrackPath:
	var p := TrackPath.new()
	p.closed = is_closed
	var ctrl: Array[Vector4] = []
	for raw in points:
		var w := default_width if raw.size() < 4 else float(raw[3])
		var h := 0.0 if raw.size() < 3 else float(raw[2])
		ctrl.append(Vector4(float(raw[0]), h, float(raw[1]), w))
	p._sample(ctrl)
	return p


func size() -> int:
	return positions.size()


func _sample(ctrl: Array[Vector4]) -> void:
	var n := ctrl.size()
	var segs := n if closed else n - 1
	var dense: Array[Vector4] = []
	const SUB := 32
	for i in segs:
		var p0 := _ctrl(ctrl, i - 1)
		var p1 := _ctrl(ctrl, i)
		var p2 := _ctrl(ctrl, i + 1)
		var p3 := _ctrl(ctrl, i + 2)
		for k in SUB:
			dense.append(_catmull(p0, p1, p2, p3, float(k) / SUB))
	if not closed:
		dense.append(ctrl[n - 1])
	else:
		dense.append(dense[0])
	# Cumulative horizontal+vertical arc length.
	var cum := PackedFloat32Array()
	cum.resize(dense.size())
	cum[0] = 0.0
	for i in range(1, dense.size()):
		cum[i] = cum[i - 1] + _xyz(dense[i]).distance_to(_xyz(dense[i - 1]))
	var total := cum[cum.size() - 1]
	var count := maxi(4, int(round(total / SPACING)))
	var step := total / count
	length = total
	var j := 0
	var limit := count if closed else count + 1
	for k in limit:
		var target := k * step
		while j < cum.size() - 2 and cum[j + 1] < target:
			j += 1
		var seg_len := maxf(cum[j + 1] - cum[j], 0.0001)
		var t := clampf((target - cum[j]) / seg_len, 0.0, 1.0)
		var v: Vector4 = dense[j].lerp(dense[j + 1], t)
		positions.append(_xyz(v))
		widths.append(v.w)
		s_values.append(target)
	var m := positions.size()
	tangents.resize(m)
	rights.resize(m)
	curvature.resize(m)
	for i in m:
		var a := _pos_wrapped(i - 1)
		var b := _pos_wrapped(i + 1)
		var t3 := (b - a).normalized()
		tangents[i] = t3
		var flat := Vector3(t3.x, 0.0, t3.z).normalized()
		rights[i] = flat.cross(Vector3.UP).normalized()
	for i in m:
		var ya := _yaw_of(tangents[_wrap(i - 2)])
		var yb := _yaw_of(tangents[_wrap(i + 2)])
		var span := 4.0 * step
		if not closed and (i < 2 or i > m - 3):
			curvature[i] = 0.0
		else:
			curvature[i] = wrapf(yb - ya, -PI, PI) / span


func _ctrl(ctrl: Array[Vector4], i: int) -> Vector4:
	var n := ctrl.size()
	if closed:
		return ctrl[posmod(i, n)]
	if i < 0:
		return ctrl[0] * 2.0 - ctrl[1]
	if i >= n:
		return ctrl[n - 1] * 2.0 - ctrl[n - 2]
	return ctrl[i]


static func _xyz(v: Vector4) -> Vector3:
	return Vector3(v.x, v.y, v.z)


static func _catmull(p0: Vector4, p1: Vector4, p2: Vector4, p3: Vector4, t: float) -> Vector4:
	# Centripetal parameterisation (alpha = 0.5) avoids loops and cusps.
	var t0 := 0.0
	var t1 := t0 + pow(maxf(_xyz(p1).distance_to(_xyz(p0)), 0.001), 0.5)
	var t2 := t1 + pow(maxf(_xyz(p2).distance_to(_xyz(p1)), 0.001), 0.5)
	var t3 := t2 + pow(maxf(_xyz(p3).distance_to(_xyz(p2)), 0.001), 0.5)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _wrap(i: int) -> int:
	if closed:
		return posmod(i, positions.size())
	return clampi(i, 0, positions.size() - 1)


func _pos_wrapped(i: int) -> Vector3:
	return positions[_wrap(i)]


func wrap_index(i: int) -> int:
	return _wrap(i)


func yaw_at(i: int) -> float:
	return _yaw_of(tangents[_wrap(i)])


func index_at_s(s: float) -> int:
	var step := length / (positions.size() if closed else positions.size() - 1)
	if closed:
		s = fposmod(s, length)
	return _wrap(int(round(s / step)))


## Main-circuit progress for a position along this path's own arc length.
func to_main_s(own_s: float) -> float:
	if length <= 0.0:
		return main_s_start
	return lerpf(main_s_start, main_s_end, clampf(own_s / length, 0.0, 1.0))


## Nearest sample index searching `before`/`after` samples around `hint`.
## Pass hint < 0 for a full search. Height differences count double so that
## stacked sections (bridges, tunnels) resolve to the right level.
func nearest_index(pos: Vector3, hint: int, before := 30, after := 45) -> int:
	var n := positions.size()
	var best := -1
	var best_d := INF
	if hint < 0 or n <= before + after + 1:
		for i in n:
			var d := _dist2(pos, positions[i])
			if d < best_d:
				best_d = d
				best = i
		return best
	for k in range(-before, after + 1):
		var i := _wrap(hint + k)
		var d := _dist2(pos, positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best


static func _dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dy := (a.y - b.y) * 2.0
	var dz := a.z - b.z
	return dx * dx + dy * dy + dz * dz


## Projects `pos` onto the path near sample `i`.
## Returns Vector3(own_s, lateral_offset, height_above_road).
func project(pos: Vector3, i: int) -> Vector3:
	var rel := pos - positions[i]
	var along := rel.dot(tangents[i])
	var lateral := rel.dot(rights[i])
	var s := s_values[i] + along
	if closed:
		s = fposmod(s, length)
	else:
		s = clampf(s, 0.0, length)
	return Vector3(s, lateral, rel.y)


## Interpolated centre point at progress `s` (own arc length).
func point_at(s: float) -> Vector3:
	var n := positions.size()
	var step := length / (n if closed else n - 1)
	if closed:
		s = fposmod(s, length)
	var f := s / step
	var i := int(floor(f))
	var t := f - i
	return positions[_wrap(i)].lerp(positions[_wrap(i + 1)], t)


func width_at(i: int) -> float:
	return widths[_wrap(i)]
