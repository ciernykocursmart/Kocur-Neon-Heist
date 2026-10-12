extends RefCounted
## Helpers shared by level objects.

const PLAYER_MASK := 2


## Adds an Area2D that detects the player body. Returns it.
static func player_area(parent: Node, size: Vector2, offset := Vector2.ZERO) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = PLAYER_MASK
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	a.add_child(cs)
	parent.add_child(a)
	return a


## Wires an area so the player registers `target` as an interactable.
static func make_interactable(target: Node, area: Area2D) -> void:
	area.body_entered.connect(func(b: Node) -> void:
		if b.has_method("add_interactable"):
			b.add_interactable(target))
	area.body_exited.connect(func(b: Node) -> void:
		if b.has_method("remove_interactable"):
			b.remove_interactable(target))


static func is_player(b: Node) -> bool:
	return b != null and b.is_in_group("player")
