extends Node3D
## Rotates continuously (windmill sails, lighthouse beam).

@export var axis := Vector3.UP
@export var speed := 1.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	rotate_object_local(axis.normalized(), speed * delta)
