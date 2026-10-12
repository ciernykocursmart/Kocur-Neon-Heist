extends Area2D
## Level exit. Locked during a guardian fight; press Interact to go through.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var locked := false
var used := false
var _sprite: Sprite2D
var _label: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = U.PLAYER_MASK
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 30)
	cs.shape = r
	cs.position = Vector2(0, -15)
	add_child(cs)
	U.make_interactable(self, self)
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -16)
	_sprite.z_index = -1
	add_child(_sprite)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.position = Vector2(-20, -46)
	_label.visible = false
	add_child(_label)
	set_locked(locked)


func set_locked(v: bool) -> void:
	locked = v
	_sprite.texture = Sprites.region("door.png", Rect2(0 if v else 32, 0, 32, 32))


func can_interact() -> bool:
	return not locked and not used


func interact(p: Node) -> void:
	if not can_interact():
		return
	used = true
	Audio.play("door")
	if level and level.has_method("complete_level"):
		level.complete_level()
