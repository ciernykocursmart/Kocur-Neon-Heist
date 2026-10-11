extends MultiMeshInstance3D
## Cheap crowd liveliness: the whole stand bobs gently.

var _t := 0.0
var _base := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_base = position.y


func _process(delta: float) -> void:
	_t += delta
	position.y = _base + absf(sin(_t * 5.0)) * 0.06
