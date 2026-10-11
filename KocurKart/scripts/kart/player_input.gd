class_name PlayerInput
extends RefCounted
## Reads the configured input actions and writes kart controls. Keyboard
## steering is ramped so taps make small corrections; analog sticks get a
## gentle response curve for precision near the centre.

const STEER_RATE := 7.5
const RETURN_RATE := 11.0

var _steer := 0.0
var _boost_was_down := false


func drive(kart: Kart, delta: float) -> void:
	var raw := Input.get_axis("steer_left", "steer_right")
	var target := signf(raw) * pow(absf(raw), 1.35)
	var rate := RETURN_RATE if absf(target) < absf(_steer) or signf(target) != signf(_steer) else STEER_RATE
	_steer = move_toward(_steer, target, rate * delta)
	kart.steer = _steer
	kart.throttle = Input.get_action_strength("accelerate")
	kart.brake = Input.get_action_strength("brake")
	kart.drift_held = Input.is_action_pressed("drift")
	var boost_down := Input.is_action_pressed("boost")
	kart.boost_pressed = boost_down and not _boost_was_down
	_boost_was_down = boost_down


func reset() -> void:
	_steer = 0.0
	_boost_was_down = false
