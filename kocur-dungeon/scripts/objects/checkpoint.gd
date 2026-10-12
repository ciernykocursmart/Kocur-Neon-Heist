extends Area2D
## Catnip lantern checkpoint. Lights up on touch and becomes the respawn point.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var active := false
var index := 0
var _sprite: AnimatedSprite2D
var _light: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = U.PLAYER_MASK
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 40)
	cs.shape = r
	cs.position = Vector2(0, -16)
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation("off")
	sf.add_animation("on")
	sf.set_animation_speed("on", 6)
	sf.add_frame("off", Sprites.region("checkpoint.png", Rect2(0, 0, 16, 32)))
	for i in range(1, 4):
		sf.add_frame("on", Sprites.region("checkpoint.png", Rect2(i * 16, 0, 16, 32)))
	_sprite.sprite_frames = sf
	_sprite.position = Vector2(0, -16)
	_sprite.play("off")
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = Sprites.texture("light.png")
	_light.texture_scale = 2.5
	_light.color = Color(0.5, 1.0, 0.6)
	_light.energy = 0.0
	_light.position = Vector2(0, -24)
	add_child(_light)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if not U.is_player(b) or active:
		return
	activate()
	if level and level.has_method("on_checkpoint"):
		level.on_checkpoint(self, b)


func activate() -> void:
	active = true
	_sprite.play("on")
	var tw := create_tween()
	tw.tween_property(_light, "energy", 1.0, 0.4)


func deactivate() -> void:
	active = false
	_sprite.play("off")
	_light.energy = 0.0


func respawn_position() -> Vector2:
	return global_position + Vector2(14, 0)
