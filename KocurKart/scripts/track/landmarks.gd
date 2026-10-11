class_name Landmarks
extends RefCounted
## Signature structures that give each circuit its identity, plus gates that
## span the road. Moving parts (windmill sails, lighthouse beam, neon blink)
## are added by animate_hook as small child nodes.

const SPIN_SCRIPT := preload("res://scripts/track/spinner.gd")


static func build(kind: String, s: MeshKit, g: MeshKit, rng: RandomNumberGenerator) -> void:
	var I := Transform3D.IDENTITY
	match kind:
		"windmill":
			s.frustum(I, Vector2(4.5, 4.5), Vector2(2.8, 2.8), 16.0, Color(0.95, 0.92, 0.85))
			s.cone(I.translated(Vector3(0, 16, 0)), 4.2, 5.0, Color(0.7, 0.25, 0.2), 8)
			s.box(I.translated(Vector3(0, 2.2, -4.0)), Vector3(2.2, 4.4, 0.4), Color(0.45, 0.3, 0.18))
			for k in 3:
				s.box(I.translated(Vector3(0, 7.0 + k * 4.0, -3.5 + k * 0.45)), Vector3(1.2, 1.4, 0.3), Color(0.35, 0.55, 0.8))
		"treehouse":
			s.cylinder(I, 3.0, 2.2, 14.0, Color(0.42, 0.28, 0.16), 9)
			var leaf := Color(0.3, 0.58, 0.24)
			s.sphere(I.translated(Vector3(0, 18.0, 0)), 8.0, leaf, 5, 9)
			s.sphere(I.translated(Vector3(5, 15.0, 3)), 5.0, leaf.darkened(0.08), 4, 8)
			s.sphere(I.translated(Vector3(-5, 16.0, -2)), 5.5, leaf.lightened(0.06), 4, 8)
			s.box(I.translated(Vector3(0, 9.5, -3.2)), Vector3(7, 0.4, 5), Color(0.55, 0.38, 0.22))
			s.box(I.translated(Vector3(0, 11.3, -3.4)), Vector3(5, 3.4, 3.6), Color(0.85, 0.6, 0.35))
			s.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 13.0, -3.4)), 4.4, 6.0, 2.2, Color(0.75, 0.25, 0.2))
			for k in 7:
				s.box(I.translated(Vector3(2.8, 1.0 + k * 1.3, -2.2)), Vector3(1.4, 0.15, 0.2), Color(0.5, 0.34, 0.2))
		"cat_totem":
			var wood := Color(0.6, 0.4, 0.24)
			s.cylinder(I, 2.0, 1.8, 7.0, wood, 10)
			s.sphere(Transform3D(Basis().scaled(Vector3(1.1, 0.95, 1.0)), Vector3(0, 8.8, 0)), 2.6, wood.lightened(0.1), 5, 10)
			for side in [-1, 1]:
				s.prism(Transform3D(Basis(Vector3.FORWARD, side * 0.35), Vector3(side * 1.5, 10.8, 0)), 1.6, 0.6, 2.0, wood)
				s.sphere(I.translated(Vector3(side * 0.9, 9.2, -2.3)), 0.5, Color(1.0, 0.85, 0.2), 3, 6)
			s.sphere(I.translated(Vector3(0, 8.2, -2.5)), 0.35, Color(0.9, 0.5, 0.55), 3, 6)
		"lighthouse":
			for k in 6:
				var c := Color(0.95, 0.95, 0.95) if k % 2 == 0 else Color(0.88, 0.2, 0.2)
				s.cylinder(I.translated(Vector3(0, k * 4.0, 0)), 3.2 - k * 0.25, 3.2 - (k + 1) * 0.25, 4.0, c, 12)
			s.cylinder(I.translated(Vector3(0, 24.0, 0)), 2.4, 2.4, 0.4, Color(0.2, 0.2, 0.24), 12)
			g.cylinder(I.translated(Vector3(0, 24.4, 0)), 1.6, 1.6, 2.4, Color(1.0, 0.92, 0.55), 10)
			s.cone(I.translated(Vector3(0, 26.8, 0)), 2.2, 2.2, Color(0.2, 0.2, 0.24), 10)
			s.cylinder(I.translated(Vector3(0, -3.0, 0)), 6.0, 5.5, 3.2, Color(0.5, 0.5, 0.52), 10)
		"crane":
			var y := Color(0.98, 0.75, 0.15)
			for cx in [-1.5, 1.5]:
				for cz in [-1.5, 1.5]:
					s.box(I.translated(Vector3(cx, 11.0, cz)), Vector3(0.4, 22.0, 0.4), y)
			for k in 7:
				s.box(I.translated(Vector3(0, 2.0 + k * 3.0, 0)), Vector3(3.4, 0.25, 3.4), y.darkened(0.2))
			s.box(I.translated(Vector3(0, 22.5, -8.0)), Vector3(1.6, 1.4, 26.0), y)
			s.box(I.translated(Vector3(0, 21.5, 3.5)), Vector3(3.0, 3.0, 3.0), Color(0.3, 0.3, 0.35))
			s.cylinder(I.translated(Vector3(0, 12.0, -18.0)), 0.06, 0.06, 10.0, Color(0.15, 0.15, 0.15), 4)
			s.box(I.translated(Vector3(0, 11.0, -18.0)), Vector3(3.0, 2.4, 6.0), Color(0.2, 0.5, 0.8))
		"ship":
			s.frustum(I.translated(Vector3(0, -2.0, 0)), Vector2(4.0, 14.0), Vector2(6.0, 18.0), 5.0, Color(0.15, 0.25, 0.45), Color(0.75, 0.6, 0.4))
			s.box(I.translated(Vector3(0, 5.0, 5.0)), Vector3(9.0, 4.0, 8.0), Color(0.95, 0.95, 0.95))
			s.cylinder(I.translated(Vector3(0, 7.0, 6.0)), 1.2, 1.2, 6.0, Color(0.88, 0.25, 0.2), 10)
			for k in 4:
				s.box(I.translated(Vector3(0, 4.0, -8.0 + k * 3.2)), Vector3(7.5, 2.6, 2.8), [Color(0.9, 0.4, 0.2), Color(0.2, 0.6, 0.85), Color(0.95, 0.8, 0.2), Color(0.4, 0.75, 0.4)][k])
		"fish_market":
			s.box(I.translated(Vector3(0, 3.0, 0)), Vector3(18, 6, 10), Color(0.55, 0.75, 0.9))
			s.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 6.0, 0)), 11.0, 19.0, 3.0, Color(0.95, 0.95, 0.95))
			s.box(I.translated(Vector3(0, 8.6, -5.4)), Vector3(9, 2.4, 0.3), Color(0.95, 0.95, 0.9))
			# Giant fish sign.
			s.sphere(Transform3D(Basis().scaled(Vector3(2.4, 1.0, 0.25)), Vector3(-0.5, 8.6, -5.7)), 1.2, Color(0.95, 0.55, 0.2), 4, 8)
			s.prism(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(2.6, 8.6, -5.7)), 1.8, 0.25, 1.2, Color(0.95, 0.55, 0.2))
			for k in 5:
				s.box(I.translated(Vector3(-7.2 + k * 3.6, 1.2, -5.2)), Vector3(2.4, 2.4, 0.2), Color(0.85, 0.3, 0.25) if k % 2 == 0 else Color(0.95, 0.95, 0.95))
		"neon_cat":
			s.box(I.translated(Vector3(0, 6.0, 0.5)), Vector3(1.0, 12.0, 1.0), Color(0.12, 0.12, 0.18))
			s.box(I.translated(Vector3(0, 18.0, 0.6)), Vector3(18.0, 13.0, 0.6), Color(0.06, 0.05, 0.1))
			var pink := Color(1.0, 0.25, 0.8)
			var cyan := Color(0.2, 0.95, 1.0)
			_ring(g, Transform3D(Basis(), Vector3(0, 17.0, 0.2)), 5.0, 0.35, pink, 20)
			for side in [-1, 1]:
				g.prism(Transform3D(Basis(Vector3.FORWARD, side * 0.35), Vector3(side * 3.2, 21.5, 0.2)), 3.0, 0.3, 3.2, pink)
				g.sphere(Transform3D(Basis().scaled(Vector3(1.0, 1.3, 0.2)), Vector3(side * 1.9, 17.8, 0.1)), 0.8, cyan, 3, 8)
				for w in 3:
					g.box(Transform3D(Basis(Vector3.FORWARD, side * (0.1 - w * 0.12)), Vector3(side * 6.8, 15.6 - w * 0.6, 0.1)), Vector3(3.2, 0.18, 0.1), cyan)
			g.prism(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0, 16.2, 0.1)), 0.9, 0.2, 0.7, pink)
			g.box(I.translated(Vector3(0, 11.0, 0.2)), Vector3(16.0, 0.4, 0.2), Color(1.0, 0.8, 0.3))
		"cable_car":
			for k in 3:
				var x := -30.0 + k * 30.0
				s.frustum(I.translated(Vector3(x, 0, 0)), Vector2(1.6, 1.6), Vector2(0.6, 0.6), 22.0, Color(0.45, 0.45, 0.5))
				s.box(I.translated(Vector3(x, 22.0, 0)), Vector3(1.0, 0.6, 5.0), Color(0.3, 0.3, 0.35))
			for side in [-2.0, 2.0]:
				s.box(I.translated(Vector3(0, 21.6, side)), Vector3(64.0, 0.1, 0.1), Color(0.15, 0.15, 0.18))
			for k in 2:
				var cx := -14.0 + k * 30.0
				s.box(I.translated(Vector3(cx, 17.5, 2.0)), Vector3(3.2, 2.6, 2.4), Color(0.9, 0.2, 0.2) if k == 0 else Color(0.2, 0.5, 0.9))
				s.box(I.translated(Vector3(cx, 20.0, 2.0)), Vector3(0.15, 2.6, 0.15), Color(0.2, 0.2, 0.22))
				g.box(I.translated(Vector3(cx, 17.8, 0.78)), Vector3(2.6, 1.0, 0.05), Color(1.0, 0.9, 0.6))
		"observatory":
			s.cylinder(I, 8.0, 8.0, 8.0, Color(0.85, 0.85, 0.88), 14)
			s.sphere(Transform3D(Basis().scaled(Vector3(1, 0.8, 1)), Vector3(0, 8.0, 0)), 8.2, Color(0.75, 0.78, 0.85), 5, 14)
			s.box(Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 12.0, -3.0)), Vector3(2.0, 1.6, 9.0), Color(0.3, 0.32, 0.38))
			g.box(I.translated(Vector3(0, 3.0, -8.05)), Vector3(3.0, 2.0, 0.1), Color(1.0, 0.85, 0.5))
		"cat_rock":
			var r := Color(0.78, 0.48, 0.32)
			s.sphere(Transform3D(Basis().scaled(Vector3(1.6, 1.0, 1.2)), Vector3(0, 6.0, 0)), 9.0, r, 5, 10)
			s.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.9, 0.9)), Vector3(0, 16.0, -4.0)), 6.0, r.lightened(0.05), 5, 10)
			for side in [-1, 1]:
				s.prism(Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 3.8, 20.0, -4.0)), 4.0, 2.0, 5.0, r.darkened(0.05))
				s.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.6, 0.5)), Vector3(side * 2.2, 16.5, -9.2)), 1.2, Color(0.35, 0.2, 0.12), 3, 6)
		"watchtower":
			for cx in [-2.0, 2.0]:
				for cz in [-2.0, 2.0]:
					s.cylinder(I.translated(Vector3(cx, 0, cz)), 0.25, 0.2, 9.0, Color(0.5, 0.35, 0.2), 5)
			s.box(I.translated(Vector3(0, 9.0, 0)), Vector3(5.5, 0.4, 5.5), Color(0.55, 0.4, 0.24))
			s.box(I.translated(Vector3(0, 10.0, 2.6)), Vector3(5.5, 1.6, 0.2), Color(0.55, 0.4, 0.24))
			s.cone(I.translated(Vector3(0, 12.0, 0)), 4.6, 2.6, Color(0.82, 0.68, 0.35), 4)
		"castle":
			var stone := Color(0.86, 0.82, 0.86)
			var roof := Color(0.5, 0.22, 0.7)
			s.box(I.translated(Vector3(0, 9.0, 0)), Vector3(34.0, 18.0, 18.0), stone)
			for k in 9:
				s.box(I.translated(Vector3(-16.0 + k * 4.0, 18.8, -9.0)), Vector3(2.0, 1.6, 1.0), stone)
			for t in [[-18.0, -10.0], [18.0, -10.0], [-18.0, 10.0], [18.0, 10.0]]:
				s.cylinder(I.translated(Vector3(t[0], 0, t[1])), 4.2, 4.0, 26.0, stone.darkened(0.05), 10)
				s.cone(I.translated(Vector3(t[0], 26.0, t[1])), 5.0, 9.0, roof, 10)
				g.box(I.translated(Vector3(t[0], 18.0, t[1] - 4.1)), Vector3(1.2, 2.0, 0.1), Color(1.0, 0.85, 0.45))
			s.cylinder(I.translated(Vector3(0, 0, 2.0)), 6.0, 5.5, 36.0, stone.lightened(0.04), 12)
			s.cone(I.translated(Vector3(0, 36.0, 2.0)), 7.0, 12.0, roof, 12)
			s.box(I.translated(Vector3(0, 5.0, -9.1)), Vector3(7.0, 10.0, 0.4), Color(0.45, 0.28, 0.18))
			for k in 8:
				g.box(I.translated(Vector3(-12.0 + k * 3.4, 12.0, -9.1)), Vector3(1.2, 2.4, 0.1), Color(1.0, 0.85, 0.45))
			s.cylinder(I.translated(Vector3(0, 48.0, 2.0)), 0.15, 0.15, 6.0, Color(0.85, 0.75, 0.35), 5)
			s.box(I.translated(Vector3(2.0, 52.5, 2.0)), Vector3(4.0, 2.4, 0.1), Color(0.95, 0.3, 0.35))
		"throne_cat":
			var gold := Color(0.95, 0.78, 0.25)
			s.box(I.translated(Vector3(0, 2.0, 0)), Vector3(8, 4, 8), Color(0.9, 0.88, 0.86))
			s.sphere(Transform3D(Basis().scaled(Vector3(1.2, 1.3, 1.0)), Vector3(0, 7.5, 0)), 3.0, gold, 5, 10)
			s.sphere(I.translated(Vector3(0, 12.3, -0.6)), 2.4, gold, 5, 10)
			for side in [-1, 1]:
				s.prism(Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 1.3, 14.2, -0.6)), 1.4, 0.5, 1.8, gold)
			s.cylinder(I.translated(Vector3(0, 14.6, -0.6)), 1.2, 1.4, 0.8, Color(1.0, 0.85, 0.3), 8, false)
			s.cylinder(Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, 5.2, 2.6)), 0.4, 0.3, 5.0, gold, 6)
		"fountain_big":
			s.cylinder(I, 9.0, 9.0, 1.2, Color(0.9, 0.88, 0.86), 16)
			g.cylinder(I.translated(Vector3(0, 1.15, 0)), 8.4, 8.4, 0.08, Color(0.35, 0.7, 0.95), 16)
			s.cylinder(I, 1.2, 1.0, 6.0, Color(0.9, 0.88, 0.86), 10)
			s.cylinder(I.translated(Vector3(0, 6.0, 0)), 3.6, 3.0, 0.6, Color(0.9, 0.88, 0.86), 12)
			g.sphere(I.translated(Vector3(0, 7.2, 0)), 1.2, Color(0.55, 0.85, 1.0), 4, 8)
		_:
			PropLibrary.build(kind, s, g, rng)


static func _ring(kit: MeshKit, xf: Transform3D, r: float, thick: float, col: Color, segs: int) -> void:
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		var mid := (p0 + p1) * 0.5
		var len := p0.distance_to(p1)
		var b := Basis(Vector3.FORWARD, atan2(p1.y - p0.y, p1.x - p0.x))
		kit.box(xf * Transform3D(b, mid), Vector3(len + thick * 0.5, thick, thick), col)


## Moving parts for landmarks.
static func animate_hook(kind: String, root: Node3D) -> void:
	match kind:
		"windmill":
			var sails := Node3D.new()
			sails.position = Vector3(0, 14.0, -3.4)
			sails.set_script(SPIN_SCRIPT)
			sails.set("axis", Vector3(0, 0, 1))
			sails.set("speed", 0.6)
			var kit := MeshKit.new()
			for k in 4:
				var b := Basis(Vector3(0, 0, 1), TAU * k / 4.0)
				kit.box(Transform3D(b, b * Vector3(0, 5.0, 0)), Vector3(0.4, 10.0, 0.2), Color(0.5, 0.35, 0.2))
				kit.box(Transform3D(b, b * Vector3(0.9, 5.5, -0.05)), Vector3(1.6, 8.0, 0.08), Color(0.97, 0.95, 0.9))
			var mi := MeshInstance3D.new()
			mi.mesh = kit.commit(TrackBuilder.flat_material(0.8))
			sails.add_child(mi)
			root.add_child(sails)
		"lighthouse":
			var beam := Node3D.new()
			beam.position = Vector3(0, 25.6, 0)
			beam.set_script(SPIN_SCRIPT)
			beam.set("axis", Vector3.UP)
			beam.set("speed", 0.9)
			var kit2 := MeshKit.new()
			kit2.frustum(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Vector2(0.4, 0.4), Vector2(2.5, 2.5), 16.0, Color(1.0, 0.95, 0.7, 0.35))
			var mi2 := MeshInstance3D.new()
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi2.mesh = kit2.commit(mat)
			mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.add_child(mi2)
			root.add_child(beam)


## Structure spanning the road at transform xf (origin on the centreline).
## `half` = distance from centre to just outside the walls.
static func build_gate(kind: String, s: MeshKit, g: MeshKit, xf: Transform3D, half: float, index: int, count: int) -> void:
	match kind:
		"wood_arch":
			for side in [-1, 1]:
				s.cylinder(xf.translated_local(Vector3(side * half, 0, 0)), 0.6, 0.5, 8.0, Color(0.45, 0.3, 0.18), 7)
			s.box(xf.translated_local(Vector3(0, 7.6, 0)), Vector3(half * 2.0 + 1.2, 0.8, 0.8), Color(0.5, 0.34, 0.2))
			s.box(xf.translated_local(Vector3(0, 6.4, -0.1)), Vector3(half * 1.2, 1.8, 0.2), Color(0.95, 0.88, 0.65))
			for k in 6:
				var x := -half * 0.5 + k * half * 0.2
				s.box(xf.translated_local(Vector3(x, 6.4, -0.22)), Vector3(half * 0.12, 0.5, 0.05), Color(0.35, 0.6, 0.3) if k % 2 == 0 else Color(0.9, 0.4, 0.2))
			for k in 9:
				var x2 := -half + k * half * 0.25
				s.prism(Transform3D(xf.basis * Basis(Vector3.RIGHT, PI), xf * Vector3(x2, 7.2, 0)), 0.9, 0.05, 1.1, [Color(0.95, 0.3, 0.3), Color(0.98, 0.85, 0.25), Color(0.35, 0.7, 0.95)][k % 3])
		"pier_banner":
			for side in [-1, 1]:
				s.box(xf.translated_local(Vector3(side * half, 4.5, 0)), Vector3(0.6, 9.0, 0.6), Color(0.95, 0.95, 0.95))
			s.box(xf.translated_local(Vector3(0, 8.4, 0)), Vector3(half * 2.0, 1.6, 0.3), Color(0.2, 0.45, 0.8))
			for k in 8:
				s.box(xf.translated_local(Vector3(-half * 0.8 + k * half * 0.23, 8.4, -0.17)), Vector3(half * 0.11, 1.0, 0.04), Color(0.98, 0.98, 0.98) if k % 2 == 0 else Color(0.95, 0.3, 0.25))
		"neon_arch":
			var c := Color(1.0, 0.25, 0.8) if index % 2 == 0 else Color(0.2, 0.95, 1.0)
			var segs := 12
			for k in segs:
				var a0 := PI * k / segs
				var a1 := PI * (k + 1) / segs
				var p0 := Vector3(cos(a0) * half, sin(a0) * half * 0.7 + 0.5, 0)
				var p1 := Vector3(cos(a1) * half, sin(a1) * half * 0.7 + 0.5, 0)
				var mid := (p0 + p1) * 0.5
				var b := Basis(Vector3.FORWARD, atan2(p1.y - p0.y, p1.x - p0.x))
				g.box(xf * Transform3D(b, mid), Vector3(p0.distance_to(p1) + 0.2, 0.4, 0.4), c)
		"ice_tunnel":
			var segs2 := 10
			var ice := Color(0.62, 0.85, 0.98)
			for k in segs2:
				var a0 := PI * k / segs2
				var a1 := PI * (k + 1) / segs2
				var p0 := Vector3(cos(a0) * half, sin(a0) * 8.5, 0)
				var p1 := Vector3(cos(a1) * half, sin(a1) * 8.5, 0)
				var mid := (p0 + p1) * 0.5 + Vector3(0, 0, 0)
				var b := Basis(Vector3.FORWARD, atan2(p1.y - p0.y, p1.x - p0.x))
				s.box(xf * Transform3D(b, mid + Vector3(0, 0, 0)), Vector3(p0.distance_to(p1) + 0.3, 1.2, 6.2), ice.darkened(0.06 * (k % 2)))
			if index % 2 == 0:
				for side in [-1, 1]:
					g.sphere(xf.translated_local(Vector3(side * (half - 1.5), 4.5, 0)), 0.35, Color(0.6, 0.95, 1.0), 3, 6)
		"rock_arch":
			var rc := Color(0.75, 0.45, 0.3)
			for side in [-1, 1]:
				s.frustum(xf.translated_local(Vector3(side * (half + 1.5), 0, 0)), Vector2(2.6, 2.6), Vector2(2.0, 2.2), 11.0, rc)
			s.sphere(Transform3D(xf.basis.scaled(Vector3(half * 0.62, 0.5, 0.45)), xf * Vector3(0, 12.0, 0)), 5.0, rc.lightened(0.05), 4, 10)
		"royal_gate":
			var stone := Color(0.88, 0.84, 0.88)
			for side in [-1, 1]:
				s.box(xf.translated_local(Vector3(side * (half + 1.0), 6.0, 0)), Vector3(3.0, 12.0, 3.0), stone)
				s.cone(xf.translated_local(Vector3(side * (half + 1.0), 12.0, 0)), 2.2, 4.0, Color(0.5, 0.22, 0.7), 8)
				s.box(xf.translated_local(Vector3(side * (half + 1.0), 7.0, -1.55)), Vector3(1.6, 3.0, 0.1), Color(0.55, 0.2, 0.75))
			s.box(xf.translated_local(Vector3(0, 10.5, 0)), Vector3(half * 2.0, 2.2, 2.0), stone)
			g.box(xf.translated_local(Vector3(0, 10.5, -1.05)), Vector3(half * 1.4, 0.5, 0.1), Color(1.0, 0.85, 0.35))
			s.cylinder(xf.translated_local(Vector3(0, 11.6, 0)), 0.9, 1.1, 0.6, Color(1.0, 0.82, 0.3), 8, false)
