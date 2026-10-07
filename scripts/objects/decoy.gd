class_name Decoy
extends Node2D
## Thrown yarn ball. Arcs to its target, then squeaks three times; every
## squeak is a noise that pulls nearby enemies to investigate.

const NOISE_RADIUS := 340.0
const PULSES := 3

var game: Game
var start := Vector2.ZERO
var target := Vector2.ZERO
var _t := 0.0
var _flight := 0.35
var _landed := false
var _pulses_left := PULSES
var _pulse_timer := 0.0
var _life := 6.0


func _ready() -> void:
	z_index = 3
	global_position = start


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := minf(_t / _flight, 1.0)
		global_position = start.lerp(target, k) + Vector2(0, -sin(k * PI) * 28.0)
		if k >= 1.0:
			_landed = true
			_pulse_timer = 0.0
	else:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0 and _pulses_left > 0:
			_pulses_left -= 1
			_pulse_timer = 1.5
			game.emit_noise(global_position, NOISE_RADIUS, false)
			FX.ring(game.fx_layer, global_position, Palette.MAGENTA, NOISE_RADIUS * 0.6, 0.6, 2.0)
			Sfx.play_at("decoy", global_position, -2.0, 1.0 + 0.1 * _pulses_left)
		_life -= delta
		if _life <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(_life, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 6.0, Palette.with_alpha(Palette.MAGENTA, 0.25 * a))
	draw_circle(Vector2.ZERO, 4.5, Palette.with_alpha(Color(0.3, 0.05, 0.2), a))
	draw_arc(Vector2.ZERO, 4.5, _t * 6.0, _t * 6.0 + 4.0, 10, Palette.with_alpha(Palette.MAGENTA, a), 1.5, true)
	draw_line(Vector2(-3, -2), Vector2(3, 2), Palette.with_alpha(Palette.MAGENTA, a), 1.0)
