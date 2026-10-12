extends Node2D
## Illusory wall hiding a secret. Looks like stone, but the cat can walk
## through; it turns see-through while she is inside.

const U := preload("res://scripts/objects/obj_util.gd")

var cells: Array[Vector2i] = []
var shimmer := false
var grid: RefCounted
var atlas: Texture2D
var _inside := 0
var _t := 0.0


func _ready() -> void:
	z_index = 3
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = U.PLAYER_MASK
	area.monitorable = false
	for c in cells:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		cs.shape = r
		cs.position = Vector2(c.x * 16 + 8, c.y * 16 + 8)
		area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b: Node) -> void:
		if U.is_player(b):
			_inside += 1)
	area.body_exited.connect(func(b: Node) -> void:
		if U.is_player(b):
			_inside = maxi(0, _inside - 1))


func _process(delta: float) -> void:
	_t += delta
	var target := 0.25 if _inside > 0 else 1.0
	modulate.a = move_toward(modulate.a, target, delta * 3.0)
	if shimmer and _inside == 0:
		modulate = Color(1.0 + 0.25 * maxf(0.0, sin(_t * 2.5)), 1.0, 1.0 + 0.4 * maxf(0.0, sin(_t * 2.5)), modulate.a)


func _draw() -> void:
	if atlas == null:
		return
	for c in cells:
		var mask := 0
		if not _solidish(c.x, c.y - 1):
			mask |= 1
		if not _solidish(c.x + 1, c.y):
			mask |= 2
		if not _solidish(c.x, c.y + 1):
			mask |= 4
		if not _solidish(c.x - 1, c.y):
			mask |= 8
		draw_texture_rect_region(atlas, Rect2(c.x * 16, c.y * 16, 16, 16), Rect2(mask * 16, 0, 16, 16))


func _solidish(x: int, y: int) -> bool:
	var ch: String = grid.ch(x, y)
	return ch == "#" or ch == "%" or ch == "I"
