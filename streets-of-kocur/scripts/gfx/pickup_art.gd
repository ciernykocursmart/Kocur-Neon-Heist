class_name PickupArt
extends RefCounted
## Food, score items and breakable props, drawn with outlined primitives so
## each one has a clear, distinct silhouette.

const OL := Color("2a2235")


static func draw_item(ci: CanvasItem, kind: String, at: Vector2, s := 1.0, t := 0.0) -> void:
	match kind:
		"fish":
			_fish(ci, at, s, Color("6fb8e8"), Color("3a7ab0"))
		"golden":
			_fish(ci, at, s * 1.15, Color("ffd23a"), Color("e0951a"))
			for i in 4:
				var a := t * 2.0 + i * TAU / 4.0
				var p := at + Vector2(cos(a) * 26.0 * s, sin(a) * 14.0 * s - 4.0)
				_sparkle(ci, p, 4.0 * s * (0.6 + 0.4 * sin(t * 6.0 + i)), Color(1, 0.95, 0.6))
		"chicken":
			CatPainter._capsule(ci, at + Vector2(6, -6) * s, at + Vector2(18, -18) * s, 6.0 * s, Color("f4ecd8"), OL, 2.0)
			ci.draw_circle(at + Vector2(20, -21) * s, 5.0 * s, OL)
			ci.draw_circle(at + Vector2(20, -21) * s, 3.5 * s, Color("f4ecd8"))
			CatPainter._poly(ci, CatPainter._ellipse(at + Vector2(-4, 0) * s, 17.0 * s, 12.0 * s, -0.5), Color("c8702a"), OL, 2.5)
			ci.draw_colored_polygon(CatPainter._ellipse(at + Vector2(-8, -4) * s, 7.0 * s, 4.0 * s, -0.5), Color("e8a050"))
		"can":
			var r := Rect2(at + Vector2(-13, -26) * s, Vector2(26, 28) * s)
			ci.draw_rect(r.grow(2.0), OL)
			ci.draw_rect(r, Color("d8dde6"))
			ci.draw_rect(Rect2(r.position + Vector2(0, 6 * s), Vector2(r.size.x, 15 * s)), Color("e8413c"))
			_fish(ci, at + Vector2(0, -12) * s, s * 0.45, Color("ffd23a"), Color("e0951a"))
			ci.draw_line(r.position + Vector2(0, 2 * s), r.position + Vector2(r.size.x, 2 * s), Color("9aa3ad"), 2.0)
		"yarn":
			CatPainter._circle(ci, at + Vector2(0, -14) * s, 14.0 * s, Color("ff6fae"), OL, 2.5)
			for i in 4:
				ci.draw_arc(at + Vector2(-4 + i * 3, -14) * s, (12.0 - i * 2.5) * s, -1.0 + i, 1.5 + i, 8, Color("c23a7a"), 2.0)
			ci.draw_line(at + Vector2(10, -6) * s, at + Vector2(22, 0) * s, Color("ff6fae"), 2.0)


static func _fish(ci: CanvasItem, at: Vector2, s: float, body: Color, fin: Color) -> void:
	var c := at + Vector2(0, -12) * s
	CatPainter._tri(ci, c + Vector2(-14, 0) * s, c + Vector2(-26, -10) * s, c + Vector2(-26, 10) * s, fin, OL, 2.0)
	CatPainter._poly(ci, CatPainter._ellipse(c, 17.0 * s, 9.0 * s), body, OL, 2.5)
	ci.draw_colored_polygon(CatPainter._ellipse(c + Vector2(2, 3) * s, 11.0 * s, 4.0 * s), body.lightened(0.35))
	ci.draw_circle(c + Vector2(9, -2) * s, 2.6 * s, OL)
	ci.draw_circle(c + Vector2(9.5, -2.5) * s, 0.9 * s, Color.WHITE)


static func _sparkle(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 2), p + Vector2(r * 0.4, 0), p + Vector2(0, r * 2), p + Vector2(-r * 0.4, 0)]), col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 2, 0), p + Vector2(0, r * 0.4), p + Vector2(r * 2, 0), p + Vector2(0, -r * 0.4)]), col)


## Breakable props. `dmg` (0..1) adds cracks as the prop takes hits.
static func draw_prop(ci: CanvasItem, kind: String, dmg: float, t: float) -> void:
	match kind:
		"crate":
			var r := Rect2(-30, -54, 60, 54)
			ci.draw_rect(r.grow(3.0), OL)
			ci.draw_rect(r, Color("b07a3a"))
			for i in 3:
				ci.draw_line(Vector2(-30, -54 + i * 18 + 9), Vector2(30, -54 + i * 18 + 9), Color("8a5a28"), 2.0)
			ci.draw_line(Vector2(-28, -52), Vector2(28, -2), Color("8a5a28"), 5.0)
			ci.draw_rect(Rect2(-30, -54, 60, 6), Color("c8924a"))
		"barrel":
			CatPainter._poly(ci, PackedVector2Array([Vector2(-22, 0), Vector2(-26, -28), Vector2(-22, -58), Vector2(22, -58), Vector2(26, -28), Vector2(22, 0)]), Color("9a5a2a"), OL, 3.0)
			for y in [-12.0, -46.0]:
				ci.draw_line(Vector2(-25, y), Vector2(25, y), Color("4a4a58"), 4.0)
			ci.draw_line(Vector2(-6, -56), Vector2(-8, -2), Color("7a4520"), 2.0)
			ci.draw_line(Vector2(8, -56), Vector2(9, -2), Color("7a4520"), 2.0)
		"drum":
			var r2 := Rect2(-24, -60, 48, 60)
			ci.draw_rect(r2.grow(3.0), OL)
			ci.draw_rect(r2, Color("2f6ab0"))
			for y in [-48.0, -14.0]:
				ci.draw_line(Vector2(-24, y), Vector2(24, y), Color("1e4a80"), 4.0)
			ci.draw_rect(Rect2(-10, -38, 20, 14), Color("f2c230"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -36), Vector2(7, -26), Vector2(-7, -26)]), OL)
		"trashcan":
			CatPainter._poly(ci, PackedVector2Array([Vector2(-20, 0), Vector2(-23, -46), Vector2(23, -46), Vector2(20, 0)]), Color("8a94a0"), OL, 3.0)
			for i in 4:
				ci.draw_line(Vector2(-14 + i * 9, -42), Vector2(-13 + i * 8.5, -4), Color("6a7480"), 2.0)
			CatPainter._poly(ci, PackedVector2Array([Vector2(-27, -46), Vector2(-24, -54), Vector2(24, -54), Vector2(27, -46)]), Color("a8b2be"), OL, 3.0)
			ci.draw_rect(Rect2(-6, -60, 12, 6), Color("6a7480"))
		"stall":
			# Fruit stand with a striped awning.
			ci.draw_rect(Rect2(-70, -44, 140, 44).grow(3.0), OL)
			ci.draw_rect(Rect2(-70, -44, 140, 44), Color("a8703a"))
			ci.draw_line(Vector2(-66, -100), Vector2(-66, -44), OL, 5.0)
			ci.draw_line(Vector2(66, -100), Vector2(66, -44), OL, 5.0)
			for i in 7:
				var x := -76.0 + i * 22.0
				var col := Color("e8413c") if i % 2 == 0 else Color("f4f0e6")
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -112), Vector2(x + 22, -112), Vector2(x + 22, -96), Vector2(x + 11, -90), Vector2(x, -96)]), col)
			ci.draw_line(Vector2(-76, -112), Vector2(78, -112), OL, 3.0)
			var fruit := [Color("ff7a2a"), Color("8adf3a"), Color("ff3a5a"), Color("ffd23a")]
			for i in 9:
				ci.draw_circle(Vector2(-56 + i * 14, -50 - (i % 2) * 6), 7.0, OL)
				ci.draw_circle(Vector2(-56 + i * 14, -50 - (i % 2) * 6), 5.5, fruit[i % 4])
	if dmg > 0.0:
		var c := Color(0.1, 0.05, 0.05, 0.8)
		ci.draw_line(Vector2(-12, -40), Vector2(2, -26), c, 2.0)
		ci.draw_line(Vector2(2, -26), Vector2(-4, -14), c, 2.0)
		if dmg > 0.5:
			ci.draw_line(Vector2(10, -48), Vector2(16, -30), c, 2.0)
