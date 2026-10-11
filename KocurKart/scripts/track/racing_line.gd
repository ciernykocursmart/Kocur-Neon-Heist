class_name RacingLine
extends RefCounted
## Precomputed racing line and target-speed profile for the AI.
##
## The line is an "elastic band" relaxation of the centreline within the
## usable road width, which naturally cuts apexes. Target speeds come from
## the line's curvature and the kart's real turning ability (Kart.turn_rate),
## followed by a backwards braking pass, so the AI drives the same physics
## as the player and never needs hidden speed bonuses.

var track: Track
var offsets := PackedFloat32Array()
var points := PackedVector3Array()
var curvature := PackedFloat32Array()
var speeds := PackedFloat32Array()


func _init(t: Track) -> void:
	track = t
	_relax()
	_profile()


func _relax() -> void:
	var path := track.main
	var n := path.size()
	offsets.resize(n)
	offsets.fill(0.0)
	var k := 6
	for iter in 120:
		var next := offsets.duplicate()
		for i in n:
			var a := path.positions[path.wrap_index(i - k)] + path.rights[path.wrap_index(i - k)] * offsets[path.wrap_index(i - k)]
			var b := path.positions[path.wrap_index(i + k)] + path.rights[path.wrap_index(i + k)] * offsets[path.wrap_index(i + k)]
			var mid := (a + b) * 0.5
			var target := (mid - path.positions[i]).dot(path.rights[i])
			var lim := path.widths[i] * 0.5 - 2.2
			if track.is_ice(path.s_values[i]):
				lim = path.widths[i] * 0.5 - 3.0
			next[i] = clampf(lerpf(offsets[i], target, 0.5), -lim, lim)
		offsets = next
	# Light smoothing so steering targets never jitter.
	for pass_i in 3:
		var sm := offsets.duplicate()
		for i in n:
			sm[i] = (offsets[path.wrap_index(i - 1)] + offsets[i] * 2.0 + offsets[path.wrap_index(i + 1)]) * 0.25
		offsets = sm
	points.resize(n)
	for i in n:
		points[i] = path.positions[i] + path.rights[i] * offsets[i]


func _profile() -> void:
	var path := track.main
	var n := path.size()
	curvature.resize(n)
	speeds.resize(n)
	var step := path.length / n
	for i in n:
		var a := points[path.wrap_index(i - 3)]
		var b := points[i]
		var c := points[path.wrap_index(i + 3)]
		var ya := atan2(-(b.x - a.x), -(b.z - a.z))
		var yb := atan2(-(c.x - b.x), -(c.z - b.z))
		curvature[i] = wrapf(yb - ya, -PI, PI) / (3.0 * step)
	var top := Kart.BASE_TOP_SPEED
	for i in n:
		var kappa := 0.0
		for j in range(-2, 3):
			kappa = maxf(kappa, absf(curvature[path.wrap_index(i + j)]))
		var v := top
		while v > 6.0 and v * kappa > Kart.turn_rate(v, top) * 0.92:
			v -= 0.25
		if track.is_ice(path.s_values[i]):
			v = minf(v, maxf(top * 0.78, v * 0.85))
		speeds[i] = v
	# Braking pass (twice round the loop handles wrap-around).
	var decel := 22.0
	for pass_i in 2:
		for k in range(n - 1, -1, -1):
			var i := k
			var nxt := speeds[path.wrap_index(i + 1)]
			var lim := sqrt(nxt * nxt + 2.0 * decel * step)
			if speeds[i] > lim:
				speeds[i] = lim


func point(i: int) -> Vector3:
	return points[track.main.wrap_index(i)]


func speed(i: int) -> float:
	return speeds[track.main.wrap_index(i)]


func offset(i: int) -> float:
	return offsets[track.main.wrap_index(i)]
