class_name PropLibrary
extends RefCounted
## Low-poly prop meshes built with MeshKit. Each builder fills a solid kit
## and optionally a glow kit (emissive parts). Props sit on y = 0, face -Z.


static func build(kind: String, solid: MeshKit, glow: MeshKit, rng: RandomNumberGenerator) -> void:
	var I := Transform3D.IDENTITY
	match kind:
		# --- Woods ---------------------------------------------------------
		"pine":
			solid.cylinder(I, 0.35, 0.28, 1.6, Color(0.42, 0.28, 0.16), 6)
			var g := Color(0.16, 0.42, 0.2)
			solid.cone(I.translated(Vector3(0, 1.2, 0)), 2.4, 3.2, g, 7)
			solid.cone(I.translated(Vector3(0, 2.8, 0)), 1.9, 2.8, g.lightened(0.08), 7)
			solid.cone(I.translated(Vector3(0, 4.3, 0)), 1.3, 2.4, g.lightened(0.16), 7)
		"oak":
			solid.cylinder(I, 0.4, 0.3, 2.4, Color(0.45, 0.3, 0.18), 6)
			var c := Color(0.32, 0.6, 0.22)
			solid.sphere(I.translated(Vector3(0, 3.6, 0)), 2.2, c, 4, 7)
			solid.sphere(I.translated(Vector3(1.2, 3.0, 0.4)), 1.4, c.darkened(0.08), 3, 6)
			solid.sphere(I.translated(Vector3(-1.0, 3.2, -0.6)), 1.5, c.lightened(0.06), 3, 6)
		"bush":
			var b := Color(0.28, 0.55, 0.22)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), Vector3(0, 0.5, 0)), 0.9, b, 3, 7)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), Vector3(0.7, 0.4, 0.3)), 0.6, b.lightened(0.1), 3, 6)
		"mushroom":
			solid.cylinder(I, 0.25, 0.2, 0.9, Color(0.95, 0.92, 0.85), 6)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1, 0.55, 1)), Vector3(0, 0.95, 0)), 0.7, Color(0.88, 0.15, 0.15), 3, 8)
			for k in 5:
				var a := TAU * k / 5.0
				solid.sphere(I.translated(Vector3(cos(a) * 0.42, 1.18, sin(a) * 0.42)), 0.1, Color.WHITE, 2, 4)
		"rock":
			var rc := Color(0.55, 0.55, 0.58)
			solid.sphere(Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), rng.randf() * 3.0).scaled(Vector3(1.3, 0.75, 1.0)), Vector3(0, 0.3, 0)), 1.0, rc, 3, 6)
		"flowers":
			var cols := [Color(0.98, 0.85, 0.2), Color(0.95, 0.4, 0.6), Color(0.6, 0.5, 0.95), Color(1, 1, 1)]
			for k in 7:
				var p := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
				solid.cylinder(I.translated(p), 0.03, 0.03, 0.35, Color(0.25, 0.5, 0.2), 3, false)
				solid.sphere(I.translated(p + Vector3(0, 0.38, 0)), 0.12, cols[k % cols.size()], 2, 5)
		"cabin":
			solid.box(I.translated(Vector3(0, 1.4, 0)), Vector3(5, 2.8, 4), Color(0.6, 0.4, 0.24))
			solid.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2.8, 0)), 4.8, 5.6, 1.8, Color(0.75, 0.25, 0.2))
			solid.box(I.translated(Vector3(0, 0.9, -2.02)), Vector3(1.0, 1.8, 0.05), Color(0.35, 0.22, 0.12))
			for side in [-1, 1]:
				solid.box(I.translated(Vector3(side * 1.5, 1.6, -2.02)), Vector3(0.9, 0.8, 0.05), Color(0.95, 0.85, 0.5))
			solid.box(I.translated(Vector3(1.5, 3.8, 0.8)), Vector3(0.5, 1.4, 0.5), Color(0.5, 0.45, 0.42))
		"tires":
			for k in 3:
				solid.cylinder(I.translated(Vector3(0, k * 0.32, 0)), 0.5, 0.5, 0.3, Color(0.12, 0.12, 0.13) if k != 1 else Color(0.9, 0.9, 0.9), 8)
		# --- Pier ----------------------------------------------------------
		"house":
			var wall_cols := [Color(0.95, 0.6, 0.45), Color(0.55, 0.78, 0.95), Color(0.98, 0.9, 0.55), Color(0.7, 0.9, 0.7), Color(0.98, 0.75, 0.8)]
			var wc: Color = wall_cols[rng.randi() % wall_cols.size()]
			var h := rng.randf_range(4.0, 8.0)
			solid.box(I.translated(Vector3(0, h * 0.5, 0)), Vector3(6, h, 5), wc)
			solid.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, h, 0)), 5.4, 6.4, 2.2, Color(0.75, 0.3, 0.22))
			for row in int(h / 2.5):
				for col in 3:
					solid.box(I.translated(Vector3(-1.8 + col * 1.8, 1.6 + row * 2.4, -2.53)), Vector3(0.8, 1.0, 0.06), Color(0.25, 0.4, 0.6))
		"crates":
			solid.box(I.translated(Vector3(0, 0.6, 0)), Vector3(1.2, 1.2, 1.2), Color(0.7, 0.52, 0.3))
			solid.box(I.translated(Vector3(1.0, 0.45, 0.6)), Vector3(0.9, 0.9, 0.9), Color(0.62, 0.45, 0.26))
			solid.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.3, 1.6, 0.2)), Vector3(0.9, 0.8, 0.9), Color(0.75, 0.56, 0.32))
		"barrels":
			for k in 3:
				solid.cylinder(I.translated(Vector3(k * 0.9 - 0.9, 0, (k % 2) * 0.5)), 0.42, 0.42, 1.1, Color(0.2, 0.45, 0.75) if k != 1 else Color(0.85, 0.3, 0.2), 8)
		"boat":
			var hull := Color(0.92, 0.92, 0.95) if rng.randf() < 0.5 else Color(0.85, 0.35, 0.25)
			solid.frustum(I.translated(Vector3(0, -0.4, 0)), Vector2(1.0, 3.0), Vector2(1.6, 4.0), 1.4, hull, Color(0.65, 0.5, 0.35))
			solid.cylinder(I.translated(Vector3(0, 1.0, 0.5)), 0.08, 0.06, 6.0, Color(0.5, 0.35, 0.2), 5)
			solid.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 1.6, 0.2)), 0.05, 2.4, 4.6, Color(0.98, 0.98, 0.95))
		"lamp":
			solid.cylinder(I, 0.1, 0.08, 4.5, Color(0.2, 0.22, 0.28), 6)
			solid.box(I.translated(Vector3(0, 4.5, -0.5)), Vector3(0.12, 0.12, 1.1), Color(0.2, 0.22, 0.28))
			glow.box(I.translated(Vector3(0, 4.35, -0.95)), Vector3(0.4, 0.2, 0.4), Color(1.0, 0.88, 0.6))
		"buoy":
			solid.cylinder(I.translated(Vector3(0, -0.3, 0)), 0.5, 0.35, 1.2, Color(0.95, 0.25, 0.2), 8)
			solid.box(I.translated(Vector3(0, 0.45, 0)), Vector3(0.5, 0.25, 0.5), Color.WHITE)
		"palm":
			var trunk := Color(0.6, 0.45, 0.3)
			for k in 6:
				solid.cylinder(Transform3D(Basis(Vector3.FORWARD, 0.05 * k), Vector3(0.12 * k, k * 1.0, 0)), 0.3 - k * 0.02, 0.28 - k * 0.02, 1.05, trunk.darkened(0.05 * (k % 2)), 6)
			for k in 6:
				var a := TAU * k / 6.0
				solid.box(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.35), Vector3(0.7, 6.0, 0)).translated_local(Vector3(0, 0, -1.4)), Vector3(0.7, 0.08, 2.8), Color(0.25, 0.62, 0.25))
		# --- Neon ----------------------------------------------------------
		"tower":
			var h := rng.randf_range(18.0, 45.0)
			var w := rng.randf_range(8.0, 14.0)
			var body := Color(0.1, 0.09, 0.16).lerp(Color(0.18, 0.14, 0.26), rng.randf())
			solid.box(I.translated(Vector3(0, h * 0.5, 0)), Vector3(w, h, w), body)
			var wcols := [Color(0.2, 0.9, 1.0), Color(1.0, 0.3, 0.8), Color(1.0, 0.8, 0.3)]
			var wcol: Color = wcols[rng.randi() % 3]
			for row in int(h / 3.0) - 1:
				for col in int(w / 2.5):
					if rng.randf() < 0.45:
						var x := -w * 0.5 + 1.4 + col * 2.5
						glow.box(I.translated(Vector3(x, 2.5 + row * 3.0, -w * 0.5 - 0.03)), Vector3(1.2, 1.4, 0.05), wcol)
						glow.box(I.translated(Vector3(-w * 0.5 - 0.03, 2.5 + row * 3.0, x)), Vector3(0.05, 1.4, 1.2), wcol)
			glow.box(I.translated(Vector3(0, h + 0.2, 0)), Vector3(w * 0.9, 0.3, w * 0.9), wcols[(rng.randi() + 1) % 3])
		"neon_sign":
			solid.cylinder(I, 0.12, 0.12, 4.0, Color(0.15, 0.15, 0.2), 5)
			solid.box(I.translated(Vector3(0, 5.0, 0)), Vector3(4.2, 2.2, 0.3), Color(0.08, 0.07, 0.12))
			var nc := Color(1.0, 0.25, 0.8) if rng.randf() < 0.5 else Color(0.2, 0.95, 1.0)
			glow.box(I.translated(Vector3(0, 5.0, -0.18)), Vector3(3.8, 0.15, 0.05), nc)
			glow.box(I.translated(Vector3(0, 5.8, -0.18)), Vector3(3.8, 0.15, 0.05), nc)
			glow.box(I.translated(Vector3(0, 4.2, -0.18)), Vector3(3.8, 0.15, 0.05), nc)
			glow.sphere(I.translated(Vector3(-1.2, 5.0, -0.2)), 0.45, nc.lightened(0.3), 3, 6)
			glow.prism(I.translated(Vector3(1.0, 4.6, -0.2)), 0.8, 0.05, 0.8, nc.lightened(0.3))
		"street_lamp":
			solid.cylinder(I, 0.12, 0.1, 6.0, Color(0.18, 0.18, 0.24), 6)
			glow.sphere(I.translated(Vector3(0, 6.2, 0)), 0.4, Color(0.6, 0.95, 1.0), 3, 6)
		"billboard":
			for side in [-1, 1]:
				solid.cylinder(I.translated(Vector3(side * 3.0, 0, 0)), 0.2, 0.2, 6.0, Color(0.2, 0.2, 0.25), 6)
			solid.box(I.translated(Vector3(0, 8.0, 0)), Vector3(9.0, 4.4, 0.4), Color(0.06, 0.05, 0.1))
			var bc := Color(1.0, 0.75, 0.2)
			glow.box(I.translated(Vector3(0, 8.0, -0.23)), Vector3(8.4, 0.2, 0.05), Color(0.2, 0.95, 1.0))
			glow.sphere(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.1)), Vector3(-2.0, 8.2, -0.25)), 1.3, bc, 4, 8)
			glow.prism(Transform3D(Basis(), Vector3(-2.7, 9.2, -0.26)), 0.6, 0.05, 0.7, bc)
			glow.prism(Transform3D(Basis(), Vector3(-1.3, 9.2, -0.26)), 0.6, 0.05, 0.7, bc)
			glow.box(I.translated(Vector3(1.8, 8.6, -0.25)), Vector3(3.2, 0.5, 0.05), Color(1.0, 0.3, 0.8))
			glow.box(I.translated(Vector3(1.8, 7.6, -0.25)), Vector3(3.2, 0.5, 0.05), Color(1.0, 0.3, 0.8))
		# --- Snow ----------------------------------------------------------
		"snow_pine":
			solid.cylinder(I, 0.3, 0.25, 1.2, Color(0.4, 0.28, 0.18), 6)
			var g2 := Color(0.14, 0.34, 0.26)
			for k in 3:
				var y := 0.9 + k * 1.5
				var r := 2.2 - k * 0.55
				solid.cone(I.translated(Vector3(0, y, 0)), r, 2.4, g2, 7)
				solid.cone(I.translated(Vector3(0, y + 1.2, 0)), r * 0.55, 1.25, Color(0.96, 0.97, 1.0), 7)
		"snowman":
			solid.sphere(I.translated(Vector3(0, 0.7, 0)), 0.75, Color(0.97, 0.98, 1.0), 4, 8)
			solid.sphere(I.translated(Vector3(0, 1.75, 0)), 0.5, Color(0.97, 0.98, 1.0), 4, 8)
			solid.sphere(I.translated(Vector3(0, 2.5, 0)), 0.35, Color(0.97, 0.98, 1.0), 4, 8)
			solid.cone(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 2.5, -0.3)), 0.07, 0.35, Color(1.0, 0.5, 0.1), 5)
			solid.cylinder(I.translated(Vector3(0, 2.75, 0)), 0.3, 0.3, 0.45, Color(0.12, 0.12, 0.14), 8)
			solid.cylinder(I.translated(Vector3(0, 2.1, 0)), 0.4, 0.42, 0.15, Color(0.85, 0.15, 0.2), 8)
		"ice_crystal":
			var ic := Color(0.55, 0.9, 1.0)
			glow.cone(I, 0.6, 3.2, ic, 5)
			glow.cone(Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0.5, 0, 0)), 0.4, 2.0, ic.lightened(0.2), 5)
			glow.cone(Transform3D(Basis(Vector3.FORWARD, -0.45), Vector3(-0.4, 0, 0.2)), 0.35, 1.7, ic, 5)
		"snow_rock":
			solid.sphere(Transform3D(Basis().scaled(Vector3(1.4, 0.8, 1.1)), Vector3(0, 0.4, 0)), 1.1, Color(0.45, 0.47, 0.52), 3, 6)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1.3, 0.35, 1.0)), Vector3(0, 1.1, 0)), 0.95, Color(0.96, 0.97, 1.0), 3, 6)
		"chalet":
			solid.box(I.translated(Vector3(0, 1.6, 0)), Vector3(6, 3.2, 5), Color(0.5, 0.32, 0.2))
			solid.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 3.2, 0)), 6.0, 7.0, 2.6, Color(0.96, 0.97, 1.0))
			for side in [-1, 1]:
				glow.box(I.translated(Vector3(side * 1.6, 1.8, -2.52)), Vector3(1.0, 1.0, 0.05), Color(1.0, 0.8, 0.4))
		# --- Safari --------------------------------------------------------
		"acacia":
			var tc := Color(0.45, 0.32, 0.2)
			solid.cylinder(I, 0.35, 0.25, 3.0, tc, 6)
			solid.cylinder(Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0, 2.6, 0)), 0.2, 0.15, 2.0, tc, 5)
			solid.cylinder(Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(0, 2.6, 0)), 0.2, 0.15, 2.0, tc, 5)
			var leaf := Color(0.42, 0.55, 0.2)
			solid.cylinder(I.translated(Vector3(0, 4.0, 0)), 3.2, 2.6, 0.8, leaf, 8)
			solid.cylinder(I.translated(Vector3(1.2, 4.5, 0.4)), 1.8, 1.4, 0.6, leaf.lightened(0.08), 7)
		"baobab":
			solid.cylinder(I, 1.3, 1.0, 5.0, Color(0.6, 0.48, 0.38), 8)
			for k in 5:
				var a := TAU * k / 5.0
				solid.cylinder(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.7), Vector3(cos(a) * 0.6, 4.8, sin(a) * 0.6)), 0.25, 0.12, 2.0, Color(0.58, 0.45, 0.35), 5)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1.4, 0.5, 1.4)), Vector3(0, 6.8, 0)), 1.8, Color(0.45, 0.58, 0.25), 3, 7)
		"boulder":
			var bcol := Color(0.72, 0.45, 0.3).darkened(rng.randf() * 0.2)
			solid.sphere(Transform3D(Basis(Vector3.UP, rng.randf() * 3.0).scaled(Vector3(1.6, 1.0, 1.2)), Vector3(0, 0.9, 0)), 1.6, bcol, 3, 7)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1.0, 0.8, 0.9)), Vector3(1.4, 0.6, 0.8)), 1.0, bcol.lightened(0.08), 3, 6)
		"grass":
			for k in 6:
				var p2 := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				solid.cone(Transform3D(Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized() if k % 2 else Vector3.UP, 0.2), p2), 0.12, rng.randf_range(0.8, 1.4), Color(0.75, 0.68, 0.35), 3)
		"hut":
			solid.cylinder(I, 2.2, 2.2, 2.4, Color(0.78, 0.6, 0.42), 9)
			solid.cone(I.translated(Vector3(0, 2.4, 0)), 3.0, 2.6, Color(0.82, 0.68, 0.35), 9)
			solid.box(I.translated(Vector3(0, 0.9, -2.15)), Vector3(1.0, 1.8, 0.1), Color(0.35, 0.22, 0.12))
		"giraffe":
			var gy := Color(0.95, 0.75, 0.35)
			var gs := Color(0.62, 0.38, 0.18)
			for leg in 4:
				solid.cylinder(I.translated(Vector3(-0.45 + (leg % 2) * 0.9, 0, -0.7 + (leg / 2) * 1.4)), 0.12, 0.1, 2.2, gy, 5)
			solid.box(I.translated(Vector3(0, 2.6, 0)), Vector3(1.1, 0.9, 2.0), gy)
			solid.box(Transform3D(Basis(Vector3.RIGHT, 0.45), Vector3(0, 3.9, -0.9)), Vector3(0.35, 2.6, 0.4), gy)
			solid.box(I.translated(Vector3(0, 5.1, -1.6)), Vector3(0.45, 0.45, 0.9), gy)
			for k in 6:
				solid.box(I.translated(Vector3((k % 2) * 0.56 - 0.28, 2.7 + (k % 3) * 0.12, -0.7 + k * 0.3)), Vector3(0.02, 0.3, 0.3), gs)
			for side in [-1, 1]:
				solid.cylinder(I.translated(Vector3(side * 0.12, 5.3, -1.4)), 0.04, 0.04, 0.35, gs, 4)
		"termite":
			solid.cone(I, 1.1, 3.6, Color(0.74, 0.46, 0.28), 6)
			solid.cone(I.translated(Vector3(0.6, 0, 0.3)), 0.6, 2.0, Color(0.7, 0.42, 0.26), 6)
		# --- Royal ---------------------------------------------------------
		"topiary":
			solid.cylinder(I, 0.55, 0.7, 0.9, Color(0.75, 0.42, 0.3), 8)
			solid.sphere(I.translated(Vector3(0, 1.7, 0)), 0.9, Color(0.22, 0.52, 0.24), 4, 8)
			solid.sphere(I.translated(Vector3(0, 2.9, 0)), 0.6, Color(0.24, 0.56, 0.26), 4, 8)
			solid.cone(I.translated(Vector3(0, 3.4, 0)), 0.35, 0.8, Color(0.26, 0.6, 0.28), 6)
		"cone_tree":
			solid.cylinder(I, 0.6, 0.6, 0.7, Color(0.95, 0.92, 0.88), 8)
			solid.cone(I.translated(Vector3(0, 0.7, 0)), 1.1, 4.2, Color(0.2, 0.48, 0.24), 8)
		"flag":
			solid.cylinder(I, 0.08, 0.06, 7.0, Color(0.85, 0.75, 0.35), 5)
			var fc := Color(0.55, 0.2, 0.75) if rng.randf() < 0.5 else Color(0.95, 0.3, 0.35)
			solid.box(I.translated(Vector3(0.9, 6.2, 0)), Vector3(1.8, 1.1, 0.04), fc)
			solid.sphere(I.translated(Vector3(0, 7.05, 0)), 0.12, Color(1.0, 0.85, 0.3), 2, 5)
		"statue":
			solid.box(I.translated(Vector3(0, 0.75, 0)), Vector3(1.6, 1.5, 1.6), Color(0.9, 0.88, 0.85))
			var gold := Color(0.95, 0.75, 0.25)
			solid.sphere(Transform3D(Basis().scaled(Vector3(1, 1.2, 0.9)), Vector3(0, 2.3, 0)), 0.6, gold, 4, 8)
			solid.sphere(I.translated(Vector3(0, 3.25, -0.1)), 0.45, gold, 4, 8)
			for side in [-1, 1]:
				solid.prism(Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 0.25, 3.55, -0.1)), 0.3, 0.1, 0.35, gold)
			solid.cylinder(Transform3D(Basis(Vector3.RIGHT, -1.0), Vector3(0, 1.8, 0.5)), 0.08, 0.06, 1.2, gold, 5)
		"fountain":
			solid.cylinder(I, 3.0, 3.0, 0.7, Color(0.88, 0.86, 0.84), 12)
			glow.cylinder(I.translated(Vector3(0, 0.66, 0)), 2.7, 2.7, 0.06, Color(0.35, 0.7, 0.95), 12, true)
			solid.cylinder(I.translated(Vector3(0, 0.7, 0)), 0.4, 0.3, 1.8, Color(0.88, 0.86, 0.84), 8)
			solid.cylinder(I.translated(Vector3(0, 2.4, 0)), 1.2, 1.0, 0.3, Color(0.88, 0.86, 0.84), 10)
			glow.sphere(I.translated(Vector3(0, 2.9, 0)), 0.4, Color(0.55, 0.85, 1.0), 3, 6)
		"flowerbed":
			solid.box(I.translated(Vector3(0, 0.2, 0)), Vector3(3.0, 0.4, 1.4), Color(0.45, 0.3, 0.2))
			var fcols := [Color(0.95, 0.35, 0.55), Color(0.98, 0.85, 0.25), Color(0.7, 0.45, 0.95)]
			for k in 10:
				solid.sphere(I.translated(Vector3(-1.2 + (k % 5) * 0.6, 0.5, -0.3 + (k / 5) * 0.6)), 0.22, fcols[k % 3], 2, 5)
		"catnip":
			for k in 5:
				var a := TAU * k / 5.0 + rng.randf()
				solid.cylinder(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.25), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3)), 0.12, 0.06, 3.2, Color(0.35, 0.62, 0.3), 5)
				solid.sphere(Transform3D(Basis().scaled(Vector3(1, 1.6, 1)), Vector3(cos(a) * 1.1, 3.2, sin(a) * 1.1)), 0.3, Color(0.75, 0.55, 0.95), 3, 6)
		_:
			solid.box(I.translated(Vector3(0, 0.5, 0)), Vector3(1, 1, 1), Color.MAGENTA)
