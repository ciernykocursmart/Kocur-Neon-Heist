extends Node2D
## Set-piece hazard for the Bell Tower: a tide of pale fire rising from the
## bottom of the level. It waits for the cat to start climbing, never rises
## faster than she can climb, and drops back a little after each checkpoint.

const U := preload("res://scripts/objects/obj_util.gd")

var level: Node
var speed := 18.0
var width := 640.0
var top_y := 0.0      ## Current surface (world y).
var start_y := 0.0
var active := false
var _t := 0.0


func _ready() -> void:
	z_index = 15
	top_y = start_y


func start() -> void:
	active = true


func reset_to(y: float) -> void:
	top_y = maxf(y, top_y) if active else start_y
	top_y = y


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Node2D = level.player if level else null
	if active and p:
		var gap := top_y - p.global_position.y
		var sp := speed
		if gap > 16 * 12:
			sp = speed * 3.0  # catch up so the pressure stays on
		top_y -= sp * delta
		if p.global_position.y > top_y + 4 and not p.is_dead():
			p.hazard_hit()
			top_y += 16 * 5
	queue_redraw()


func _draw() -> void:
	var h := 16.0 * 40
	var col := Color(0.92, 0.88, 1.0, 0.85)
	draw_rect(Rect2(0, top_y + 6, width, h), Color(0.75, 0.6, 1.0, 0.55))
	for i in int(width / 8) + 1:
		var x := i * 8.0
		var y := top_y + sin(_t * 4.0 + i * 0.7) * 3.0
		draw_rect(Rect2(x, y, 8, 8), col)
		draw_rect(Rect2(x + 2, y - 3 + sin(_t * 6.0 + i) * 2.0, 3, 3), Color(1, 1, 1, 0.8))
