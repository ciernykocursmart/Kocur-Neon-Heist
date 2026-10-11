class_name TrackHazard
extends Node3D
## Moving or static obstacle evaluated analytically from race time, so it is
## deterministic, restart-safe and cheap. Karts query contact() each tick.
##
## Definition keys: type ("sweeper" | "static"), f (lap fraction), lateral,
## amplitude (fraction of half width), period (s), phase, radius, model.

var kind := "sweeper"
var s := 0.0
var base := Vector3.ZERO
var right := Vector3.RIGHT
var lateral := 0.0
var amplitude := 0.0
var period := 4.0
var phase := 0.0
var radius := 1.2
var model := "barrel"
var _pos := Vector3.ZERO
var _spin := 0.0


static func create(track: Track, h: Dictionary) -> TrackHazard:
	var hz := TrackHazard.new()
	hz.kind = String(h.get("type", "sweeper"))
	hz.s = float(h["f"]) * track.length
	var i := track.main.index_at_s(hz.s)
	var hw := track.main.widths[i] * 0.5
	hz.base = track.main.positions[i]
	hz.right = track.main.rights[i]
	hz.lateral = float(h.get("lateral", 0.0))
	hz.amplitude = float(h.get("amplitude", 0.7)) * hw
	hz.period = float(h.get("period", 4.0))
	hz.phase = float(h.get("phase", 0.0))
	hz.radius = float(h.get("radius", 1.2))
	hz.model = String(h.get("model", "barrel"))
	hz.name = "Hazard_%s" % hz.model
	hz._build_visual(track.main.yaw_at(i))
	hz.update(0.0)
	return hz


func update(t: float) -> void:
	var off := lateral
	if kind == "sweeper":
		off += amplitude * sin(TAU * t / period + phase)
		_spin = amplitude * cos(TAU * t / period + phase)
	_pos = base + right * off
	position = _pos


func current_position() -> Vector3:
	return _pos


func contact(pos: Vector3, r: float) -> Vector3:
	var d := Vector3(pos.x - _pos.x, 0.0, pos.z - _pos.z)
	if absf(pos.y - _pos.y) > 2.5:
		return Vector3.ZERO
	var lim := radius + r
	if d.length_squared() >= lim * lim:
		return Vector3.ZERO
	if d.length_squared() < 0.0001:
		d = right
	return d.normalized()


func _build_visual(yaw: float) -> void:
	var kit := MeshKit.new()
	var glow := false
	var r := radius
	match model:
		"crab":
			var shell := Color(0.95, 0.3, 0.2)
			kit.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.55, 0.8)), Vector3(0, r * 0.6, 0)), r * 0.85, shell, 4, 10)
			for side in [-1, 1]:
				kit.sphere(Transform3D(Basis(), Vector3(side * r * 0.95, r * 0.75, -r * 0.35)), r * 0.32, shell.lightened(0.1), 3, 6)
				kit.cylinder(Transform3D(Basis(), Vector3(side * r * 0.3, r * 0.9, -r * 0.4)), 0.05, 0.05, r * 0.35, Color(0.2, 0.1, 0.1), 4)
				kit.sphere(Transform3D(Basis(), Vector3(side * r * 0.3, r * 1.28, -r * 0.4)), 0.12, Color.WHITE, 2, 6)
				for leg in 3:
					kit.box(Transform3D(Basis(Vector3.FORWARD, side * 0.6), Vector3(side * r * 0.85, r * 0.25, -0.3 + leg * 0.3)), Vector3(r * 0.6, 0.1, 0.1), shell.darkened(0.2))
		"snowball":
			kit.sphere(Transform3D(Basis(), Vector3(0, r, 0)), r, Color(0.97, 0.98, 1.0), 5, 10)
		"barrel":
			kit.cylinder(Transform3D(Basis(), Vector3.ZERO), r * 0.8, r * 0.8, r * 1.8, Color(0.62, 0.36, 0.18), 10)
			for band in [0.3, 1.5]:
				kit.cylinder(Transform3D(Basis(), Vector3(0, r * band - 0.06, 0)), r * 0.83, r * 0.83, 0.12, Color(0.3, 0.3, 0.32), 10, false)
		"drone":
			glow = true
			kit.box(Transform3D(Basis(), Vector3(0, r * 0.8, 0)), Vector3(r * 1.6, r * 0.5, r * 1.6), Color(0.15, 0.95, 1.0))
			kit.box(Transform3D(Basis(), Vector3(0, r * 0.4, 0)), Vector3(r * 0.4, r * 0.8, r * 0.4), Color(1.0, 0.2, 0.8))
		"tumbleweed":
			for k in 4:
				kit.sphere(Transform3D(Basis(Vector3(1, 0.3, 0.2).normalized(), k * 0.8), Vector3(0, r, 0)), r * (0.85 + 0.1 * k), Color(0.66, 0.5, 0.3).darkened(k * 0.08), 3, 6)
		"guard":
			var coat := Color(0.55, 0.15, 0.6)
			kit.cylinder(Transform3D(Basis(), Vector3.ZERO), r * 0.6, r * 0.5, r * 1.6, coat, 8)
			kit.sphere(Transform3D(Basis(), Vector3(0, r * 1.9, 0)), r * 0.45, Color(0.98, 0.85, 0.3), 3, 8)
			kit.cylinder(Transform3D(Basis(), Vector3(0, r * 2.2, 0)), r * 0.35, r * 0.4, r * 0.5, Color(0.1, 0.1, 0.12), 8)
		_:
			kit.box(Transform3D(Basis(), Vector3(0, r, 0)), Vector3(r * 2, r * 2, r * 2), Color(0.9, 0.6, 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(TrackBuilder.flat_material(0.6, 1.6 if glow else 0.0))
	mi.rotation.y = yaw
	add_child(mi)
	# Warning ring painted under the obstacle's sweep so it can be read early.
	if kind == "sweeper" and amplitude > 0.1:
		var ring := MeshKit.new()
		var a := -right * amplitude + Vector3.UP * 0.07
		var b := right * amplitude + Vector3.UP * 0.07
		var fwd := right.cross(Vector3.UP)
		var hw := 0.25
		ring.quad(a - fwd * hw, b - fwd * hw, b + fwd * hw, a + fwd * hw, Color(1.0, 0.75, 0.1, 1.0), Vector3.UP)
		var strip := MeshInstance3D.new()
		strip.mesh = ring.commit(TrackBuilder.flat_material(0.6, 0.6))
		strip.top_level = true
		strip.position = base + right * lateral
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)
