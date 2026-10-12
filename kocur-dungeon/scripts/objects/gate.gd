extends StaticBody2D
## Iron bars covering a group of tiles. Lever gates start closed and open
## once; boss gates start open and close while a guardian fight is running.

const Sprites := preload("res://scripts/fx/sprites.gd")

var cells: Array[Vector2i] = []
var is_open := false
var _shapes: Array[CollisionShape2D] = []
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	for c in cells:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		cs.shape = r
		cs.position = Vector2(c.x * 16 + 8, c.y * 16 + 8)
		add_child(cs)
		_shapes.append(cs)
		var s := Sprite2D.new()
		s.texture = Sprites.texture("gate.png")
		s.centered = false
		s.position = Vector2(c.x * 16, c.y * 16)
		add_child(s)
		_sprites.append(s)
	_apply(is_open, false)


func open() -> void:
	_apply(true, true)


func close() -> void:
	_apply(false, true)


func _apply(v: bool, animate: bool) -> void:
	is_open = v
	for cs in _shapes:
		cs.set_deferred("disabled", v)
	for s in _sprites:
		if animate:
			var tw := s.create_tween()
			tw.tween_property(s, "modulate:a", 0.0 if v else 1.0, 0.3)
		else:
			s.modulate.a = 0.0 if v else 1.0
	if animate:
		Audio.play("door", -4.0)
