class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Runs in _process against the kart's
## interpolated transform so it stays smooth at any refresh rate. Follows the
## blend of heading and travel direction, pulls back and widens FOV with
## speed, dips on landings, shakes briefly on impacts and pulls in when
## scenery would block the view.

const BASE_FOV := 70.0

var target: Kart
var distance := 5.6
var height := 2.3
var look_ahead := 5.0
var sensitivity := 1.0   ## follow-direction responsiveness (settings)
var distance_scale := 1.0  ## follow distance (settings)

var _dir := Vector3.FORWARD
var _y := 0.0
var _dip := 0.0
var _dip_v := 0.0
var _shake := 0.0
var _fov_extra := 0.0
var _rng := RandomNumberGenerator.new()
var _initialized := false


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = BASE_FOV
	near = 0.1
	far = 1500.0
	_rng.seed = 7


func follow(kart: Kart) -> void:
	if target and target.landed.is_connected(_on_landed):
		target.landed.disconnect(_on_landed)
		target.wall_hit.disconnect(_on_hit)
		target.kart_bumped.disconnect(_on_bump)
	target = kart
	target.landed.connect(_on_landed)
	target.wall_hit.connect(_on_hit)
	target.kart_bumped.connect(_on_bump)
	snap()


func snap() -> void:
	if target == null:
		return
	_dir = target.forward_dir()
	_y = target.global_position.y + height
	_initialized = true
	_update(0.0, true)


func add_shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 0.5)


func _on_landed(impact: float) -> void:
	_dip_v = -clampf(impact * 0.06, 0.3, 1.6)


func _on_hit(impact: float) -> void:
	add_shake(clampf(impact / 40.0, 0.05, 0.3))


func _on_bump(_other: Kart, impact: float) -> void:
	add_shake(clampf(impact / 50.0, 0.03, 0.2))


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		_update(delta, false)


func _update(delta: float, instant: bool) -> void:
	var xf := target.get_global_transform_interpolated() if not instant else target.global_transform
	var p := xf.origin
	var heading := -xf.basis.z
	heading.y = 0.0
	heading = heading.normalized()
	var hv := Vector3(target.velocity.x, 0.0, target.velocity.z)
	var speed := hv.length()
	var desired_dir := heading
	if speed > 4.0 and target.forward_speed > 0.0:
		desired_dir = heading.slerp(hv / speed, 0.4 if not target.drifting else 0.6).normalized()
	if instant:
		_dir = desired_dir
	else:
		_dir = _dir.slerp(desired_dir, clampf(1.0 - exp(-4.5 * sensitivity * delta), 0.0, 1.0)).normalized()
	var top := target.top_speed()
	var speed_k := clampf(speed / top, 0.0, 1.35)
	var d := (distance + speed_k * 1.3) * distance_scale
	var h := height + speed_k * 0.25
	var desired_y := p.y + h
	if instant:
		_y = desired_y
	else:
		var rate := 7.0 if target.is_on_floor() else 2.5
		_y = lerpf(_y, desired_y, clampf(1.0 - exp(-rate * delta), 0.0, 1.0))
		_y = clampf(_y, p.y + h - 2.5, p.y + h + 2.5)
	# Landing dip spring.
	_dip_v += (-_dip * 60.0 - _dip_v * 9.0) * delta
	_dip += _dip_v * delta
	var cam := p - _dir * d
	cam.y = _y + _dip * 0.5
	var look := p + _dir * look_ahead + Vector3.UP * (1.0 + _dip * 0.2)
	# Keep scenery from blocking the view.
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var from := p + Vector3.UP * 1.4
		var q := PhysicsRayQueryParameters3D.create(from, cam, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			cam = hit["position"] + (from - cam).normalized() * 0.4
	if _shake > 0.0:
		cam += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 0.35
		_shake = maxf(_shake - delta * 1.8, 0.0)
	var boost_k := 1.0 if target.boost_time > 0.0 else 0.0
	_fov_extra = lerpf(_fov_extra, speed_k * 9.0 + boost_k * 6.0, clampf(1.0 - exp(-4.0 * delta), 0.0, 1.0) if not instant else 1.0)
	fov = BASE_FOV + _fov_extra
	global_position = cam
	if cam.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
