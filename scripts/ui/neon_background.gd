class_name NeonBackground
extends Control
## Animated menu backdrop: synthwave horizon grid, city skyline, neon rain
## and a giant cat silhouette with glowing eyes. Pure _draw(), no assets.

var _t := 0.0
var _rain: Array = []
var _buildings: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 1337
	for i in 90:
		_rain.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.4, 1.0)))
	var x := 0.0
	while x < 1.0:
		var w := _rng.randf_range(0.03, 0.08)
		_buildings.append(Vector3(x, w, _rng.randf_range(0.08, 0.3)))
		x += w + _rng.randf_range(0.0, 0.01)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var horizon := s.y * 0.58
	# Sky gradient bands.
	var bands := 24
	for i in bands:
		var k := float(i) / bands
		var col := Color(0.02, 0.01, 0.06).lerp(Color(0.22, 0.03, 0.2), pow(k, 2.2))
		draw_rect(Rect2(0, horizon * k, s.x, horizon / bands + 1), col)
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color(0.02, 0.01, 0.05))
	# Sun.
	var sun_c := Vector2(s.x * 0.72, horizon - 10)
	for i in 10:
		var r := 120.0 - i * 2.0
		draw_circle(sun_c, r + 30, Color(1, 0.2, 0.6, 0.012))
	draw_circle(sun_c, 110, Color(1.0, 0.3, 0.55, 0.85))
	for i in 7:
		var y := sun_c.y - 10 + i * 14.0 + fmod(_t * 8.0, 14.0)
		draw_rect(Rect2(sun_c.x - 120, y, 240, 3 + i * 0.8), Color(0.12, 0.02, 0.12))
	draw_rect(Rect2(sun_c.x - 130, horizon, 260, 120), Color(0.02, 0.01, 0.05))
	# Skyline.
	for b in _buildings:
		var bx: float = b.x * s.x
		var bw: float = b.y * s.x
		var bh: float = b.z * s.y
		# Keep the sun visible: buildings in front of it are low-rise.
		if absf(bx + bw * 0.5 - sun_c.x) < 170.0:
			bh *= 0.35
		var r := Rect2(bx, horizon - bh, bw, bh)
		draw_rect(r, Color(0.04, 0.03, 0.09))
		draw_line(r.position, r.position + Vector2(bw, 0), Color(0.3, 0.9, 1.0, 0.35), 1.0)
		var wy := r.position.y + 8
		while wy < horizon - 6:
			var wx := bx + 4
			while wx < bx + bw - 6:
				var on := sin(wx * 0.37 + wy * 0.11) > 0.55
				if on:
					draw_rect(Rect2(wx, wy, 3, 4), Color(0.4, 0.9, 1.0, 0.35) if int(wx + wy) % 3 else Color(1, 0.4, 0.8, 0.35))
				wx += 9
			wy += 12
	# Perspective grid floor.
	var vanish := Vector2(s.x * 0.5, horizon)
	for i in range(-20, 21):
		var x := s.x * 0.5 + i * 90.0
		draw_line(vanish, Vector2(x + (x - vanish.x) * 3.0, s.y), Color(1.0, 0.25, 0.8, 0.28), 1.5)
	for i in 14:
		var k := fmod(i / 14.0 + _t * 0.08, 1.0)
		var y := horizon + pow(k, 2.4) * (s.y - horizon)
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.25, 0.9, 1.0, 0.1 + 0.35 * k), 1.5)
	draw_line(Vector2(0, horizon), Vector2(s.x, horizon), Color(0.25, 0.95, 1.0, 0.8), 2.0)
	# Cat silhouette on the left rooftop.
	_draw_cat(Vector2(s.x * 0.2, horizon - 6), 2.4)
	# Rain.
	for d in _rain:
		var x: float = fmod(d.x * s.x + _t * 60.0 * d.z, s.x)
		var y: float = fmod(d.y * s.y + _t * 520.0 * d.z, s.y)
		draw_line(Vector2(x, y), Vector2(x - 3, y + 16 * d.z), Color(0.5, 0.8, 1.0, 0.18 * d.z), 1.0)
	# Scanlines.
	var y2 := 0.0
	while y2 < s.y:
		draw_line(Vector2(0, y2), Vector2(s.x, y2), Color(0, 0, 0, 0.12), 1.0)
		y2 += 3.0


func _draw_cat(base: Vector2, k: float) -> void:
	var body := PackedVector2Array([
		base + Vector2(-30, 0) * k, base + Vector2(-32, -30) * k, base + Vector2(-24, -48) * k,
		base + Vector2(-20, -66) * k, base + Vector2(-24, -84) * k, base + Vector2(-16, -76) * k,
		base + Vector2(-6, -76) * k, base + Vector2(2, -84) * k, base + Vector2(0, -66) * k,
		base + Vector2(4, -48) * k, base + Vector2(14, -30) * k, base + Vector2(16, 0) * k,
	])
	draw_colored_polygon(body, Color(0.01, 0.0, 0.03))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.25, 0.95, 1.0, 0.5), 2.0, true)
	# Tail.
	var tail := PackedVector2Array()
	for i in 12:
		var u := i / 11.0
		tail.append(base + Vector2(16 + u * 34, -4 - u * 30 + sin(_t * 2.0 + u * 3.0) * 6.0) * k)
	draw_polyline(tail, Color(1, 0.25, 0.78, 0.9), 3.0 * k, true)
	# Eyes.
	var blink := fmod(_t, 4.0) < 0.12
	var eh := 0.6 if blink else 3.0
	for ex in [-15.0, -5.0]:
		var e := base + Vector2(ex, -68) * k
		draw_rect(Rect2(e - Vector2(2.5, eh) * k * 0.5, Vector2(2.5, eh) * k), Color(0.3, 1.0, 1.0))
		draw_circle(e, 8.0 * k, Color(0.3, 1.0, 1.0, 0.08))
