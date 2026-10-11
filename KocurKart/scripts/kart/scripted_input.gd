class_name ScriptedInput
extends RefCounted
## Fixed control values, for automated tests, attract mode and grid revving.

var throttle := 0.0
var brake := 0.0
var steer := 0.0
var drift := false
var boost := false


func drive(kart: Kart, _delta: float) -> void:
	kart.throttle = throttle
	kart.brake = brake
	kart.steer = steer
	kart.drift_held = drift
	kart.boost_pressed = boost
	boost = false
