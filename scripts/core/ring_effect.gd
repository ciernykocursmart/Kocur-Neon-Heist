class_name RingEffect
extends Node2D
## Self-freeing expanding ring used by FX.ring().

var color := Color.WHITE
var max_radius := 100.0
var duration := 0.45
var width := 2.0
var _t := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var r := max_radius * (1.0 - pow(1.0 - k, 3.0))
	var c := Color(color.r, color.g, color.b, color.a * (1.0 - k))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, width, true)
