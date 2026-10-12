extends Area2D
## Invisible trigger covering a hidden area. Entering it counts the secret.

const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var key := ""
var found := false
var cells: Array[Vector2i] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = U.PLAYER_MASK
	monitorable = false
	for c in cells:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		cs.shape = r
		cs.position = Vector2(c.x * 16 + 8, c.y * 16 + 8)
		add_child(cs)
	body_entered.connect(func(b: Node) -> void:
		if U.is_player(b) and not found:
			found = true
			if level and level.has_method("on_secret"):
				level.on_secret(self))
