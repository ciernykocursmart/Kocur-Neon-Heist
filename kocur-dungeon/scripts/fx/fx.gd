extends RefCounted
## One-shot visual effects. Every effect frees itself when finished.

const Sprites := preload("res://scripts/fx/sprites.gd")


static func _parent(level: Node) -> Node:
	if level == null or not is_instance_valid(level):
		return null
	var p: Node = level.get_node_or_null("FX")
	return p if p else level


static func _anim(level: Node, sheet: String, pos: Vector2, flip := false, scale := 1.0) -> AnimatedSprite2D:
	var parent := _parent(level)
	if parent == null:
		return null
	var s := Sprites.make_sprite(sheet)
	s.global_position = pos
	s.flip_h = flip
	s.scale = Vector2(scale, scale)
	s.z_index = 20
	parent.add_child(s)
	s.global_position = pos
	s.animation_finished.connect(s.queue_free)
	return s


static func dust(level: Node, pos: Vector2) -> void:
	_anim(level, "dust", pos + Vector2(0, -6))


static func spark(level: Node, pos: Vector2) -> void:
	_anim(level, "spark", pos)


static func poof(level: Node, pos: Vector2, scale := 1.0) -> void:
	_anim(level, "poof", pos, false, scale)


static func burst(level: Node, pos: Vector2, color: Color, amount := 14, speed := 90.0) -> void:
	var parent := _parent(level)
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.z_index = 20
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static func afterimage(level: Node, sprite: AnimatedSprite2D) -> void:
	var parent := _parent(level)
	if parent == null or sprite == null:
		return
	var s := Sprite2D.new()
	s.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	s.flip_h = sprite.flip_h
	s.modulate = Color(0.7, 0.6, 1.0, 0.55)
	s.z_index = 4
	parent.add_child(s)
	s.global_position = sprite.global_position
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.22)
	tw.tween_callback(s.queue_free)


static func float_text(level: Node, pos: Vector2, text: String, color := Color.WHITE) -> void:
	var parent := _parent(level)
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_font_size_override("font_size", 10)
	l.z_index = 30
	parent.add_child(l)
	l.global_position = pos - Vector2(text.length() * 3, 10)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 18, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


static func warning(level: Node, pos: Vector2, time := 0.6) -> void:
	var parent := _parent(level)
	if parent == null:
		return
	var s := Sprite2D.new()
	s.texture = Sprites.texture("warning.png")
	s.z_index = 25
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.3, 1.3), time * 0.5)
	tw.tween_property(s, "scale", Vector2(1.0, 1.0), time * 0.5)
	tw.tween_callback(s.queue_free)
