class_name GameCamera
extends Camera2D
## Smooth follow camera with mouse look-ahead, trauma-based screen shake and
## directional recoil kicks.

var target: Node2D
var trauma := 0.0
var _kick := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func shake(amount: float) -> void:
	if not bool(GameState.settings.get("screen_shake", true)):
		return
	trauma = minf(1.0, trauma + amount)


func kick(v: Vector2) -> void:
	if not bool(GameState.settings.get("screen_shake", true)):
		return
	_kick += v


func snap_to_target() -> void:
	if target:
		global_position = target.global_position
		reset_smoothing()


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var vp := get_viewport_rect().size
		var mouse := get_viewport().get_mouse_position() - vp * 0.5
		var look := (mouse / zoom).limit_length(360.0) * 0.22
		global_position = target.global_position + look
	trauma = maxf(0.0, trauma - delta * 1.8)
	_kick = _kick.lerp(Vector2.ZERO, minf(1.0, delta * 14.0))
	var s := trauma * trauma
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s * 16.0 + _kick
