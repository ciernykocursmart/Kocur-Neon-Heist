class_name ExtractionPad
extends Node2D
## Exfil point. Inactive until the data is secured; then the cat must stand
## on it for a moment while the evac uplink completes.

const RADIUS := 44.0

var game: Game
var active := false
var progress := 0.0
var _t := 0.0
var _light: Sprite2D


func _ready() -> void:
	z_index = -1
	_light = FX.make_light(Palette.GREEN, 160.0, 0.0)
	add_child(_light)


func activate() -> void:
	active = true
	var tw := create_tween()
	tw.tween_property(_light, "modulate:a", 0.35, 0.6)
	FX.ring(game.fx_layer, global_position, Palette.GREEN, 220.0, 0.9, 3.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col := Palette.GREEN if active else Palette.DIM
	var a := 0.9 if active else 0.35
	draw_circle(Vector2.ZERO, RADIUS, Palette.with_alpha(col, 0.06 if active else 0.03))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 40, Palette.with_alpha(col, a), 2.5, true)
	draw_arc(Vector2.ZERO, RADIUS - 8.0, _t, _t + PI * 0.7, 16, Palette.with_alpha(col, a * 0.7), 2.0, true)
	draw_arc(Vector2.ZERO, RADIUS - 8.0, _t + PI, _t + PI * 1.7, 16, Palette.with_alpha(col, a * 0.7), 2.0, true)
	# Chevrons.
	for i in 4:
		var dir := Vector2.from_angle(PI * 0.5 * i)
		var p := dir * (RADIUS + 10.0 + (sin(_t * 4.0) * 3.0 if active else 0.0))
		draw_line(p + dir.orthogonal() * 6.0, p - dir * 6.0, Palette.with_alpha(col, a), 2.0)
		draw_line(p - dir.orthogonal() * 6.0, p - dir * 6.0, Palette.with_alpha(col, a), 2.0)
	var f := FX.font()
	draw_string(f, Vector2(-28, 5), "EVAC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.with_alpha(col, a))
	if progress > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Palette.WHITE, 4.0, true)
