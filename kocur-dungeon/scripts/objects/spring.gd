extends Area2D
## Bounce pad: launches the cat high into the air when landed on.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = U.PLAYER_MASK
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 6)
	cs.shape = r
	cs.position = Vector2(0, -4)
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = Sprites.region("spring.png", Rect2(0, 0, 16, 16))
	_sprite.position = Vector2(0, -8)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t = maxf(_t - delta, 0.0)
	if _t <= 0.0:
		_sprite.texture = Sprites.region("spring.png", Rect2(0, 0, 16, 16))
	for b in get_overlapping_bodies():
		if U.is_player(b) and b.velocity.y >= -10.0 and b.is_controllable():
			b.spring_launch()
			_t = 0.25
			_sprite.texture = Sprites.region("spring.png", Rect2(16, 0, 16, 16))
			Audio.play("spring", -4.0)
