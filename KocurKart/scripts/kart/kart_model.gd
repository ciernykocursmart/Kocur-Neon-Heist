class_name KartModel
extends Node3D
## Procedural low-poly kart and cat driver, plus all per-kart visual feedback
## (body lean, drift slide angle, wheel spin/steer, hop, landing squash,
## hazard spin, respawn flicker, drift sparks, boost flames, dust).
## Animated from Kart.step() on physics ticks; physics interpolation smooths
## the result on high refresh-rate displays.

const WHEEL_R := 0.3
const SPARK_COLORS := [Color(0, 0, 0, 0), Color(0.3, 0.75, 1.0), Color(1.0, 0.55, 0.12)]

var appearance := {}
var pivot: Node3D
var body: MeshInstance3D
var head: Node3D
var tail: Node3D
var wheels: Array[Node3D] = []
var sparks: Array[CPUParticles3D] = []
var flames: Array[CPUParticles3D] = []
var dust: CPUParticles3D
var trail: CPUParticles3D

var _slide := 0.0
var _lean := 0.0
var _pitch := 0.0
var _hop := 0.0
var _hop_v := 0.0
var _squash := 0.0
var _wheel_spin := 0.0
var _steer_vis := 0.0
var _spin_vis := 0.0
var _tail_t := 0.0
var _time := 0.0


static func create(app: Dictionary) -> KartModel:
	var m := KartModel.new()
	m.name = "Model"
	m.appearance = app
	m.build()
	return m


func build() -> void:
	for c in get_children():
		c.queue_free()
	wheels.clear()
	sparks.clear()
	flames.clear()
	var racer: Dictionary = Catalog.RACERS.get(appearance.get("racer", "kocur"), Catalog.RACERS["kocur"])
	var kart_id: String = appearance.get("kart", "alley")
	var paint: Color = Catalog.PAINTS.get(appearance.get("paint", "crimson"), Catalog.PAINTS["crimson"])["color"]
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	var kit := MeshKit.new()
	_build_body(kit, kart_id, paint)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = kit.commit(TrackBuilder.flat_material(0.45))
	pivot.add_child(body)
	_build_cat(racer, String(appearance.get("accessory", "none")))
	_build_wheels(kart_id, String(appearance.get("wheels", "classic")), paint)
	_build_fx()


func _build_body(kit: MeshKit, kart_id: String, paint: Color) -> void:
	var dark := Color(0.13, 0.13, 0.16)
	var trim := paint.lightened(0.35)
	var metal := Color(0.72, 0.74, 0.78)
	match kart_id:
		"pounce":
			kit.frustum(Transform3D(Basis(), Vector3(0, 0.18, 0.05)), Vector2(0.55, 0.95), Vector2(0.42, 0.75), 0.28, paint)
			kit.frustum(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.3, -0.9)), Vector2(0.38, 0.12), Vector2(0.08, 0.06), 0.55, paint)
			kit.box(Transform3D(Basis(), Vector3(0, 0.22, -1.32)), Vector3(1.3, 0.06, 0.32), trim)
			for side in [-1, 1]:
				kit.box(Transform3D(Basis(), Vector3(side * 0.55, 0.62, 0.95)), Vector3(0.06, 0.45, 0.2), dark)
			kit.box(Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.86, 0.98)), Vector3(1.25, 0.06, 0.38), paint)
			kit.box(Transform3D(Basis(), Vector3(0, 0.4, 0.75)), Vector3(0.6, 0.3, 0.4), dark)
			for side in [-1, 1]:
				kit.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.18, 0.42, 0.95)), 0.06, 0.07, 0.2, metal, 6)
		"thunder":
			kit.frustum(Transform3D(Basis(), Vector3(0, 0.16, 0.0)), Vector2(0.72, 1.0), Vector2(0.6, 0.85), 0.36, paint)
			kit.box(Transform3D(Basis(), Vector3(0, 0.3, -1.08)), Vector3(1.45, 0.3, 0.28), dark)
			kit.box(Transform3D(Basis(), Vector3(0, 0.47, -0.7)), Vector3(1.0, 0.18, 0.5), paint.darkened(0.15))
			for side in [-1, 1]:
				kit.box(Transform3D(Basis(), Vector3(side * 0.74, 0.3, 0.0)), Vector3(0.2, 0.24, 1.2), trim)
				kit.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.3, 0.55, 0.9)), 0.11, 0.13, 0.35, metal, 8)
			kit.box(Transform3D(Basis(), Vector3(0, 0.62, 0.72)), Vector3(0.8, 0.36, 0.45), dark)
			kit.box(Transform3D(Basis(), Vector3(0, 0.95, 0.95)), Vector3(1.2, 0.08, 0.3), trim)
		_:
			kit.frustum(Transform3D(Basis(), Vector3(0, 0.17, 0.0)), Vector2(0.6, 0.95), Vector2(0.5, 0.8), 0.32, paint)
			kit.frustum(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.33, -0.8)), Vector2(0.45, 0.15), Vector2(0.25, 0.1), 0.42, paint)
			kit.box(Transform3D(Basis(), Vector3(0, 0.22, -1.25)), Vector3(1.2, 0.12, 0.25), dark)
			for side in [-1, 1]:
				kit.box(Transform3D(Basis(), Vector3(side * 0.62, 0.28, 0.05)), Vector3(0.18, 0.2, 0.9), trim)
				kit.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.22, 0.5, 0.92)), 0.07, 0.08, 0.25, metal, 6)
			kit.box(Transform3D(Basis(), Vector3(0, 0.55, 0.72)), Vector3(0.7, 0.32, 0.4), dark)
			kit.box(Transform3D(Basis(), Vector3(0, 0.82, 0.9)), Vector3(1.0, 0.07, 0.26), paint)
	# Seat, steering column and wheel shared by all bodies.
	kit.box(Transform3D(Basis(), Vector3(0, 0.55, 0.32)), Vector3(0.62, 0.12, 0.5), dark)
	kit.box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.78, 0.55)), Vector3(0.6, 0.5, 0.1), dark)
	kit.cylinder(Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, 0.55, -0.32)), 0.04, 0.04, 0.45, metal, 5)
	kit.cylinder(Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(0, 0.83, -0.18)), 0.17, 0.17, 0.04, dark, 10)
	# Number plate stripe in the paint's complementary tint.
	kit.box(Transform3D(Basis(), Vector3(0, 0.51, -0.55)), Vector3(0.36, 0.02, 0.3), Color(0.97, 0.97, 0.95))


func _build_cat(racer: Dictionary, accessory: String) -> void:
	var fur: Color = racer["fur"]
	var fur2: Color = racer["fur2"]
	var eyes: Color = racer["eyes"]
	var pattern: String = racer["pattern"]
	var kit := MeshKit.new()
	# Torso and arms reaching for the wheel.
	var chest := fur2 if pattern in ["tuxedo"] else fur
	kit.sphere(Transform3D(Basis().scaled(Vector3(1.0, 1.15, 0.85)), Vector3(0, 0.88, 0.32)), 0.3, fur, 4, 8)
	kit.sphere(Transform3D(Basis().scaled(Vector3(0.8, 1.0, 0.5)), Vector3(0, 0.9, 0.12)), 0.22, chest, 3, 8)
	for side in [-1, 1]:
		kit.cylinder(Transform3D(Basis(Vector3.RIGHT, 1.25), Vector3(side * 0.22, 0.95, 0.25)), 0.07, 0.06, 0.42, fur, 6)
		kit.sphere(Transform3D(Basis(), Vector3(side * 0.15, 0.86, -0.15)), 0.075, fur2 if pattern != "solid" else fur.lightened(0.1), 3, 6)
	var torso := MeshInstance3D.new()
	torso.mesh = kit.commit(TrackBuilder.flat_material(0.85))
	pivot.add_child(torso)
	# Head (separate node so it can look into corners).
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.28, 0.25)
	pivot.add_child(head)
	var hk := MeshKit.new()
	var face := fur
	if pattern == "points":
		face = fur2
	hk.sphere(Transform3D(Basis().scaled(Vector3(1.1, 0.95, 1.0)), Vector3.ZERO), 0.3, fur, 5, 10)
	hk.sphere(Transform3D(Basis().scaled(Vector3(1.2, 0.8, 0.8)), Vector3(0, -0.08, -0.22)), 0.13, fur2 if pattern != "points" else face, 3, 8)
	for side in [-1, 1]:
		var ear_xf := Transform3D(Basis(Vector3.FORWARD, side * 0.35), Vector3(side * 0.18, 0.2, 0.02))
		hk.prism(ear_xf, 0.2, 0.08, 0.24, face if pattern == "points" else fur)
		hk.prism(ear_xf.translated_local(Vector3(0, 0.02, -0.03)), 0.12, 0.04, 0.15, Color(0.98, 0.65, 0.7))
		hk.sphere(Transform3D(Basis().scaled(Vector3(1.0, 1.15, 0.6)), Vector3(side * 0.11, 0.04, -0.26)), 0.07, eyes, 3, 8)
		hk.sphere(Transform3D(Basis().scaled(Vector3(0.45, 1.0, 0.5)), Vector3(side * 0.11, 0.04, -0.3)), 0.045, Color(0.04, 0.04, 0.05), 3, 6)
		hk.sphere(Transform3D(Basis(), Vector3(side * 0.095, 0.075, -0.32)), 0.015, Color.WHITE, 2, 4)
		for w in 2:
			var wy := -0.08 - w * 0.035
			hk.box(Transform3D(Basis(Vector3.FORWARD, side * (0.12 - w * 0.2)), Vector3(side * 0.2, wy, -0.28)), Vector3(0.22, 0.008, 0.008), Color(0.95, 0.95, 0.95) if fur.v < 0.5 else Color(0.25, 0.25, 0.25))
	hk.sphere(Transform3D(Basis().scaled(Vector3(1.3, 0.8, 0.8)), Vector3(0, -0.03, -0.31)), 0.035, Color(0.95, 0.5, 0.6), 2, 6)
	if pattern == "tabby":
		for k in 3:
			hk.box(Transform3D(Basis(Vector3.RIGHT, -0.4 + k * 0.25), Vector3(0, 0.27 - k * 0.02, -0.08 + k * 0.1)), Vector3(0.05 + 0.03 * (1 - absf(k - 1)), 0.02, 0.12), fur.darkened(0.35))
	elif pattern == "calico":
		hk.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)), Vector3(0.14, 0.17, 0.0)), 0.16, fur2, 3, 6)
		hk.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)), Vector3(-0.15, 0.12, 0.08)), 0.13, Color(0.15, 0.12, 0.1), 3, 6)
	_accessory(hk, accessory, fur)
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit(TrackBuilder.flat_material(0.75))
	head.add_child(hm)
	# Tail curling up behind the seat.
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.75, 0.62)
	pivot.add_child(tail)
	var tk := MeshKit.new()
	for k in 6:
		var t := float(k) / 5.0
		var p := Vector3(0, t * 0.55, t * 0.32 - t * t * 0.18)
		var tc := fur
		if pattern == "points" or (pattern == "tabby" and k % 2 == 1):
			tc = fur2 if pattern == "points" else fur.darkened(0.3)
		tk.sphere(Transform3D(Basis(), p), 0.07 - t * 0.015, tc, 3, 6)
	var tm := MeshInstance3D.new()
	tm.mesh = tk.commit(TrackBuilder.flat_material(0.85))
	tail.add_child(tm)


func _accessory(hk: MeshKit, id: String, fur: Color) -> void:
	match id:
		"scarf":
			var red := Color(0.9, 0.15, 0.2)
			hk.cylinder(Transform3D(Basis(), Vector3(0, -0.3, 0.02)), 0.24, 0.22, 0.09, red, 10)
			hk.box(Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.12, -0.36, 0.25)), Vector3(0.1, 0.03, 0.3), red)
		"goggles":
			hk.box(Transform3D(Basis(), Vector3(0, 0.15, -0.05)), Vector3(0.62, 0.05, 0.5), Color(0.3, 0.2, 0.12))
			for side in [-1, 1]:
				hk.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.12, 0.17, -0.3)), 0.08, 0.08, 0.06, Color(0.4, 0.8, 1.0), 8)
		"headphones":
			hk.box(Transform3D(Basis(), Vector3(0, 0.3, 0.0)), Vector3(0.6, 0.05, 0.08), Color(0.1, 0.1, 0.12))
			for side in [-1, 1]:
				hk.cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 0.33, 0.02, 0.0)), 0.11, 0.11, 0.08, Color(0.95, 0.25, 0.75), 8)
		"flower":
			for k in 5:
				var a := TAU * k / 5.0
				hk.sphere(Transform3D(Basis(), Vector3(-0.2 + cos(a) * 0.06, 0.27 + sin(a) * 0.06, 0.0)), 0.05, Color(0.85, 0.45, 0.95), 2, 5)
			hk.sphere(Transform3D(Basis(), Vector3(-0.2, 0.27, -0.02)), 0.04, Color(1.0, 0.9, 0.3), 2, 5)
		"crown":
			var gold := Color(1.0, 0.8, 0.2)
			hk.cylinder(Transform3D(Basis(), Vector3(0, 0.24, 0.02)), 0.16, 0.18, 0.1, gold, 10, false)
			for k in 5:
				var a := TAU * k / 5.0
				hk.cone(Transform3D(Basis(), Vector3(cos(a) * 0.16, 0.34, 0.02 + sin(a) * 0.16)), 0.045, 0.12, gold, 4)
			hk.sphere(Transform3D(Basis(), Vector3(0, 0.3, -0.16)), 0.035, Color(0.9, 0.1, 0.3), 2, 5)


func _build_wheels(kart_id: String, style: String, paint: Color) -> void:
	var front_z := -0.72
	var rear_z := 0.68
	var half := 0.72 if kart_id != "thunder" else 0.8
	var width := 0.3 if style != "chunky" else 0.42
	var r := WHEEL_R if style != "chunky" else WHEEL_R + 0.04
	var rim := Color(0.75, 0.77, 0.8)
	var glow := false
	match style:
		"sport": rim = paint.lightened(0.2)
		"chunky": rim = Color(0.95, 0.75, 0.2)
		"neon":
			rim = Color(0.2, 0.95, 1.0)
			glow = true
	for k in 4:
		var front := k < 2
		var side := -1 if k % 2 == 0 else 1
		var holder := Node3D.new()
		holder.name = "Wheel%d" % k
		holder.position = Vector3(side * half, r, front_z if front else rear_z)
		pivot.add_child(holder)
		var kit := MeshKit.new()
		var rw := width * (1.15 if not front else 1.0)
		var axis := Basis(Vector3.FORWARD, PI * 0.5)
		kit.cylinder(Transform3D(axis, Vector3(-rw * 0.5, 0, 0)), r, r, rw, Color(0.1, 0.1, 0.11), 10)
		var cap_x := rw * 0.5 if side > 0 else -rw * 0.5 - 0.03
		kit.cylinder(Transform3D(axis, Vector3(cap_x, 0, 0)), r * 0.58, r * 0.58, 0.03, rim, 8)
		kit.box(Transform3D(Basis(), Vector3(cap_x + 0.015, 0, 0)), Vector3(0.04, r * 0.9, 0.08), rim.darkened(0.3))
		var spin := MeshInstance3D.new()
		spin.name = "Spin"
		spin.mesh = kit.commit(TrackBuilder.flat_material(0.6, 1.5 if glow else 0.0))
		holder.add_child(spin)
		wheels.append(holder)


func _build_fx() -> void:
	for side in [-1, 1]:
		var p := _particles(Vector3(side * 0.72, 0.08, 0.78), 26, 0.35, true, 0.1)
		p.direction = Vector3(side * 0.6, 0.9, 0.6)
		p.spread = 35.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.5
		p.gravity = Vector3(0, -9, 0)
		sparks.append(p)
		var fl := _particles(Vector3(side * 0.22, 0.48, 1.08), 22, 0.22, true, 0.22)
		fl.direction = Vector3(0, 0.15, 1)
		fl.spread = 10.0
		fl.initial_velocity_min = 3.0
		fl.initial_velocity_max = 5.0
		fl.gravity = Vector3.ZERO
		fl.color = Color(1.0, 0.55, 0.15)
		flames.append(fl)
	dust = _particles(Vector3(0, 0.15, 0.9), 24, 0.6, false, 0.35)
	dust.direction = Vector3(0, 0.7, 1)
	dust.spread = 40.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.5
	dust.gravity = Vector3(0, -2, 0)
	dust.color = Color(0.75, 0.65, 0.5, 0.35)


func _particles(pos: Vector3, amount: int, life: float, glow := true, size := 0.15) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	# Size lives on the mesh: per-particle scale is not reliably applied to
	# billboarded CPU particles in the Compatibility renderer.
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if glow:
		mat.albedo_color = Color(1.6, 1.6, 1.6)
	qm.material = mat
	p.mesh = qm
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pivot.add_child(p)
	return p


func reset_pose() -> void:
	_slide = 0.0
	_lean = 0.0
	_pitch = 0.0
	_hop = 0.0
	_hop_v = 0.0
	_squash = 0.0
	_spin_vis = 0.0
	visible = true
	for s in sparks:
		s.emitting = false
	for f in flames:
		f.emitting = false
	if dust:
		dust.emitting = false


func hop() -> void:
	_hop_v = 2.6


func squash(amount: float) -> void:
	_squash = clampf(amount, 0.0, 0.35)


func animate(kart: Kart, delta: float) -> void:
	_time += delta
	var k := 1.0 - exp(-10.0 * delta)
	# Align to the ground under the kart (visual only; collision stays upright).
	var nl := Basis(Vector3.UP, kart.yaw).inverse() * kart.ground_normal
	var pitch_t := atan2(nl.z, nl.y)
	var roll_t := atan2(-nl.x, nl.y)
	_pitch = lerpf(_pitch, pitch_t, k)
	var slide_t := 0.0
	if kart.drifting:
		slide_t = kart.drift_dir * 0.42
	_slide = lerpf(_slide, slide_t, 1.0 - exp(-8.0 * delta))
	var lean_t := kart.steer * clampf(absf(kart.forward_speed) / 20.0, 0.0, 1.0) * 0.06
	if kart.drifting:
		lean_t = -kart.drift_dir * 0.09
	_lean = lerpf(_lean, lean_t + roll_t, k)
	# Hop and squash springs.
	_hop_v -= 22.0 * delta
	_hop = maxf(_hop + _hop_v * delta, 0.0)
	if _hop <= 0.0:
		_hop_v = 0.0
	_squash = move_toward(_squash, 0.0, delta * 1.6)
	if kart.spin_time > 0.0:
		_spin_vis += delta * TAU / 0.45
	else:
		_spin_vis = 0.0
	pivot.position = Vector3(0, _hop, 0)
	pivot.basis = Basis.from_euler(Vector3(_pitch, _slide + _spin_vis, _lean))
	pivot.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.3)
	# Wheels.
	_wheel_spin += kart.forward_speed * delta / WHEEL_R
	_steer_vis = lerpf(_steer_vis, -kart.steer * 0.45, k)
	for i in wheels.size():
		var w := wheels[i]
		w.rotation = Vector3(0, _steer_vis if i < 2 else 0.0, 0)
		w.get_node("Spin").rotation = Vector3(-_wheel_spin, 0, 0)
	if head:
		head.rotation.y = lerpf(head.rotation.y, -kart.steer * 0.35 + _slide * -0.6, k)
		head.position.y = 1.28 + sin(_time * 9.0) * 0.008 * clampf(kart.forward_speed / 10.0, 0.0, 1.0)
	if tail:
		_tail_t += delta * (2.0 + absf(kart.forward_speed) * 0.15)
		tail.rotation = Vector3(-0.3 - clampf(kart.forward_speed / 30.0, 0.0, 1.0) * 0.6, sin(_tail_t) * 0.25, 0)
	# Feedback particles.
	var spark_on := kart.drifting and kart.drift_level > 0 and kart.is_on_floor()
	for s in sparks:
		s.emitting = spark_on
		if spark_on:
			s.color = SPARK_COLORS[kart.drift_level]
	var boosting := kart.boost_time > 0.0
	for f in flames:
		f.emitting = boosting
		f.color = Color(0.3, 0.8, 1.0) if kart.boost_kind == &"purr" else Color(1.0, 0.55, 0.15)
	dust.emitting = kart.surface == &"offroad" and absf(kart.forward_speed) > 5.0 and kart.is_on_floor()
	# Respawn flicker.
	visible = kart.ghost_time <= 0.0 or int(kart.ghost_time * 12.0) % 2 == 0
