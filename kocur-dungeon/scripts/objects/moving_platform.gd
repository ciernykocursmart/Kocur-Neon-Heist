extends AnimatableBody2D
## A one-way platform that travels back and forth along a straight path.
## AnimatableBody2D carries the player automatically.

const Sprites := preload("res://scripts/fx/sprites.gd")

var travel := Vector2(64, 0)
var period := 3.0
var _origin := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46, 8)
	cs.shape = r
	cs.one_way_collision = true
	cs.position = Vector2(0, 4)
	add_child(cs)
	var s := Sprite2D.new()
	s.texture = Sprites.texture("platform.png")
	s.position = Vector2(0, 5)
	add_child(s)
	_origin = position
	period = maxf(1.5, travel.length() / 40.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := (1.0 - cos(_t / period * TAU)) * 0.5
	position = _origin + travel * k
