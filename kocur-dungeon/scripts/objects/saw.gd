extends Area2D
## A spinning saw blade that rolls along its rail, reversing at walls/edges.

const Sprites := preload("res://scripts/fx/sprites.gd")
const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var speed := 50.0
var dir := 1.0
var damage := 2
var vertical := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = U.PLAYER_MASK
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	add_child(cs)
	add_child(Sprites.make_sprite("saw"))
	body_entered.connect(func(b: Node) -> void:
		if U.is_player(b):
			b.hurt(damage, global_position))


func _physics_process(delta: float) -> void:
	if level == null:
		return
	var g: RefCounted = level.grid
	var step := Vector2(0, dir) if vertical else Vector2(dir, 0)
	var ahead: Vector2 = global_position + step * 9.0
	var c: Vector2i = g.cell_of(ahead)
	var blocked: bool = g.is_solid(c.x, c.y)
	if not vertical and not blocked:
		# Saws roll along the ground; turn at ledges if they have one.
		var below: Vector2i = g.cell_of(ahead + Vector2(0, 12))
		var cur_below: Vector2i = g.cell_of(global_position + Vector2(0, 12))
		if g.is_solid(cur_below.x, cur_below.y) and not g.is_solid(below.x, below.y):
			blocked = true
	if blocked:
		dir = -dir
	global_position += step * speed * delta
	for b in get_overlapping_bodies():
		if U.is_player(b):
			b.hurt(damage, global_position)
