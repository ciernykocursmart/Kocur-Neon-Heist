extends Node2D
## Lightweight effects layer: hit sparks, dust, shock rings, debris, dizzy
## stars and pop-up text. One node draws all particles (cheap and simple).
## Positions are world/ground coordinates; z is folded into y by callers.

var parts: Array = []
var font: Font


func _ready() -> void:
	z_index = 50
	font = ThemeDB.fallback_font


func tick(dt: float) -> void:
	var keep: Array = []
	for p: Dictionary in parts:
		p["t"] += dt
		if p.has("v"):
			p["pos"] += (p["v"] as Vector2) * dt
			p["v"] = (p["v"] as Vector2) + Vector2(0, float(p.get("g", 0.0)) * dt)
		if p.has("follow") and is_instance_valid(p["follow"]):
			var f: Node2D = p["follow"]
			p["pos"] = f.position + Vector2(0, -float(f.get("z")) - float(f.get("body_h")) * float(f.get("scale_k")) - 6.0)
		if p["t"] < p["life"]:
			keep.append(p)
	parts = keep


func _process(_delta: float) -> void:
	queue_redraw()


func spark(pos: Vector2, size := 1.0, col := Color(1.0, 0.95, 0.5)) -> void:
	parts.append({"type": "spark", "pos": pos, "t": 0.0, "life": 0.18, "s": size, "c": col, "rot": randf() * TAU})
	for i in int(4 * size) + 2:
		var a := randf() * TAU
		parts.append({"type": "bit", "pos": pos, "v": Vector2(cos(a), sin(a)) * randf_range(120, 300) * size, "g": 600.0,
			"t": 0.0, "life": 0.3, "c": col})


func dust(ground: Vector2, size := 1.0) -> void:
	for i in 5:
		var dx := randf_range(-26, 26) * size
		parts.append({"type": "dust", "pos": ground + Vector2(dx, -4), "v": Vector2(dx * 2.0, -randf_range(10, 40)),
			"t": 0.0, "life": 0.45, "s": size * randf_range(0.7, 1.2)})


func ring(ground: Vector2, radius: float, col: Color) -> void:
	parts.append({"type": "ring", "pos": ground, "t": 0.0, "life": 0.35, "r": radius, "c": col})


func debris(ground: Vector2, col: Color) -> void:
	for i in 8:
		var a := randf_range(PI * 1.1, PI * 1.9)
		parts.append({"type": "chip", "pos": ground + Vector2(0, -30), "v": Vector2(cos(a), sin(a)) * randf_range(160, 340),
			"g": 900.0, "t": 0.0, "life": 0.7, "c": col, "rot": randf() * TAU})


func text(pos: Vector2, s: String, col := Color.WHITE, size := 22, life := 0.8, rise := 60.0) -> void:
	parts.append({"type": "text", "pos": pos, "v": Vector2(0, -rise), "t": 0.0, "life": life, "s": s, "c": col, "size": size})


func comic(pos: Vector2, s: String, col: Color) -> void:
	parts.append({"type": "comic", "pos": pos, "t": 0.0, "life": 0.45, "s": s, "c": col, "rot": randf_range(-0.25, 0.25)})


func stars(f: Node2D, life := 1.1) -> void:
	parts.append({"type": "stars", "pos": f.position, "follow": f, "t": 0.0, "life": life})


func sparkle(pos: Vector2, col := Color(1, 0.95, 0.6)) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		parts.append({"type": "twinkle", "pos": pos, "v": Vector2(cos(a), sin(a)) * 90.0, "t": 0.0, "life": 0.5, "c": col})


func clear() -> void:
	parts.clear()


func _draw() -> void:
	for p: Dictionary in parts:
		var k: float = float(p["t"]) / float(p["life"])
		var pos: Vector2 = p["pos"]
		match String(p["type"]):
			"spark":
				var s: float = 22.0 * float(p["s"]) * (0.6 + k)
				var pts := PackedVector2Array()
				for i in 16:
					var a: float = float(p["rot"]) + TAU * i / 16.0
					var r := s if i % 2 == 0 else s * 0.4
					pts.append(pos + Vector2(cos(a), sin(a)) * r)
				var c: Color = p["c"]
				draw_colored_polygon(pts, Color(c.r, c.g, c.b, 1.0 - k))
				draw_circle(pos, s * 0.3, Color(1, 1, 1, 1.0 - k))
			"bit":
				var c2: Color = p["c"]
				draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color(c2.r, c2.g, c2.b, 1.0 - k))
			"dust":
				draw_circle(pos, (6.0 + k * 10.0) * float(p["s"]), Color(0.85, 0.82, 0.78, 0.5 * (1.0 - k)))
			"ring":
				var c3: Color = p["c"]
				var r2: float = float(p["r"]) * (0.3 + k * 0.9)
				draw_polyline(CatPainter._ellipse(pos, r2, r2 * 0.32, 0, 32) + PackedVector2Array([pos + Vector2(r2, 0)]), Color(c3.r, c3.g, c3.b, 1.0 - k), 6.0 * (1.0 - k) + 1.0)
			"chip":
				var c4: Color = p["c"]
				draw_set_transform(pos, float(p["rot"]) + k * 10.0, Vector2.ONE)
				draw_rect(Rect2(-6, -3, 12, 6), Color(c4.r, c4.g, c4.b, 1.0 - k * 0.5))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"text":
				var c5: Color = p["c"]
				var a := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
				var sz: int = int(p["size"])
				var w := font.get_string_size(String(p["s"]), HORIZONTAL_ALIGNMENT_CENTER, -1, sz).x
				draw_string_outline(font, pos - Vector2(w * 0.5, 0), String(p["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(0.1, 0.05, 0.12, a))
				draw_string(font, pos - Vector2(w * 0.5, 0), String(p["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(c5.r, c5.g, c5.b, a))
			"comic":
				var c6: Color = p["c"]
				var sc := 1.0 + (1.0 - k) * 0.4
				draw_set_transform(pos, float(p["rot"]), Vector2(sc, sc))
				var w2 := font.get_string_size(String(p["s"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
				var burst := PackedVector2Array()
				for i in 14:
					var a2 := TAU * i / 14.0
					var r3 := (w2 * 0.6 + 10.0) if i % 2 == 0 else (w2 * 0.42 + 4.0)
					burst.append(Vector2(cos(a2) * r3, sin(a2) * r3 * 0.55 - 10.0))
				draw_colored_polygon(burst, Color(1, 1, 1, 1.0 - k))
				draw_string_outline(font, Vector2(-w2 * 0.5, 0), String(p["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.1, 0.05, 0.12, 1.0 - k))
				draw_string(font, Vector2(-w2 * 0.5, 0), String(p["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(c6.r, c6.g, c6.b, 1.0 - k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"stars":
				var tt: float = p["t"]
				for i in 3:
					var a3 := tt * 5.0 + TAU * i / 3.0
					PickupArt._sparkle(self, pos + Vector2(cos(a3) * 22.0, sin(a3) * 7.0), 3.5, Color(1, 0.9, 0.3))
			"twinkle":
				var c7: Color = p["c"]
				PickupArt._sparkle(self, pos, 4.0 * (1.0 - k), Color(c7.r, c7.g, c7.b, 1.0 - k))
