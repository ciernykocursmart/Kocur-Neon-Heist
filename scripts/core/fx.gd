class_name FX
extends RefCounted
## Stateless helpers that spawn short-lived visual effects: additive light
## blobs, particle bursts, expanding rings and floating combat text.

static var _light_tex: Texture2D
static var _add_mat: CanvasItemMaterial
static var _font: Font


static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.42))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_light_tex = t
	return _light_tex


static func add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func font() -> Font:
	if _font == null:
		_font = UITheme.font()
	return _font


## Creates (but does not parent) an additive light sprite.
static func make_light(color: Color, radius: float, energy := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = light_texture()
	s.material = add_material()
	s.modulate = Color(color.r, color.g, color.b, energy)
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	return s


static func flash(parent: Node, pos: Vector2, color: Color, radius: float, duration := 0.12, energy := 0.9) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := make_light(color, radius, energy)
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.tween_callback(s.queue_free)


static func burst(parent: Node, pos: Vector2, color: Color, amount := 12, speed := 220.0, lifetime := 0.4, size := 3.0, dir := Vector2.ZERO, spread_deg := 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.local_coords = false
	p.gravity = Vector2.ZERO
	if dir == Vector2.ZERO:
		p.direction = Vector2.RIGHT
		p.spread = 180.0
	else:
		p.direction = dir.normalized()
		p.spread = spread_deg
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.4
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.material = add_material()
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


## Expanding circle outline (noise pings, shockwaves, pickups).
static func ring(parent: Node, pos: Vector2, color: Color, radius: float, duration := 0.45, width := 2.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var r := RingEffect.new()
	r.color = color
	r.max_radius = radius
	r.duration = duration
	r.width = width
	parent.add_child(r)
	r.global_position = pos


static func float_text(parent: Node, pos: Vector2, text: String, color: Color, size := 16) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	l.size = Vector2(240, 24)
	parent.add_child(l)
	l.global_position = pos - Vector2(120, 12)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 42.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Ejected shell casing: a small spinning tick that bounces out and fades.
static func shell(parent: Node, pos: Vector2, dir: Vector2, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Line2D.new()
	l.points = PackedVector2Array([Vector2(-2, 0), Vector2(2, 0)])
	l.width = 2.0
	l.default_color = Palette.with_alpha(color, 0.9)
	l.z_index = 3
	parent.add_child(l)
	l.global_position = pos
	var target := pos + dir.normalized() * randf_range(14.0, 24.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", randf_range(4.0, 9.0), 0.25)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)
