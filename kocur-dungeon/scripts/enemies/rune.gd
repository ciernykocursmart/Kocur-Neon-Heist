extends Area2D
## Rune trap left by mages: glows as a warning, then erupts briefly.

const Fx := preload("res://scripts/fx/fx.gd")

var level: Node
var warn_time := 0.9
var burst_time := 0.35
var damage := 2
var color := Color(0.75, 0.45, 1.0)
var _t := 0.0
var _hit := false


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 40)
	cs.shape = r
	cs.position = Vector2(0, -20)
	add_child(cs)
	z_index = 6
	Audio.play("magic", -10.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= warn_time and _t < warn_time + burst_time and not _hit:
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.hurt(damage, global_position + Vector2(0, 10)):
				_hit = true
	if _t >= warn_time + burst_time:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _t < warn_time:
		var k := _t / warn_time
		var a := 0.35 + 0.4 * absf(sin(_t * 14.0))
		draw_rect(Rect2(-10, -2, 20, 2), Color(color, a))
		draw_arc(Vector2(0, -1), 8.0 * (0.5 + k * 0.5), PI, TAU, 12, Color(color, a), 1.0)
	else:
		var f := 1.0 - (_t - warn_time) / burst_time
		draw_rect(Rect2(-8, -44, 16, 44), Color(color.r, color.g, color.b, 0.75 * f))
		draw_rect(Rect2(-4, -44, 8, 44), Color(1, 1, 1, 0.8 * f))
