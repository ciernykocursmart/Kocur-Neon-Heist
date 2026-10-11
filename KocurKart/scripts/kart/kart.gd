class_name Kart
extends CharacterBody3D
## Arcade kart controller.
##
## A CharacterBody3D driven by an explicit, deterministic arcade model rather
## than free rigid-body physics: the kart has a heading (`yaw`), and each
## physics tick its velocity is split into forward and lateral parts relative
## to that heading. Throttle/brake act on the forward part, grip bleeds the
## lateral part away, and steering rotates the heading. Drifting is a separate
## state with its own turn rate that charges mini-turbos and the Purr meter.
##
## Inputs come from a controller object (PlayerInput or AIDriver) through
## drive(kart, delta), called at the start of every physics tick so the order
## of evaluation never depends on the scene tree.

signal drift_started(direction: int)
signal drift_level_changed(level: int)
signal drift_released(level: int)
signal boost_started(kind: StringName)
signal jumped
signal landed(impact: float)
signal wall_hit(impact: float)
signal kart_bumped(other: Kart, impact: float)
signal hazard_hit
signal recovered

const GRAVITY := 26.0
const RAMP_KICK := 1.3
const BASE_TOP_SPEED := 27.0
const BASE_ACCEL := 17.5
const BRAKE_DECEL := 34.0
const REVERSE_ACCEL := 14.0
const REVERSE_MAX := 9.0
const COAST_DECEL := 3.0
const OVERSPEED_DECEL := 9.0
const BASE_GRIP := 13.0
const TURN_RATE_LOW := 2.55
const TURN_RATE_HIGH := 1.5
const TURN_FULL_AT := 5.5
const AIR_TURN := 0.4
const DRIFT_MIN_SPEED := 11.0
const DRIFT_KEEP_SPEED := 7.0
const DRIFT_RATE_WIDE := 0.95
const DRIFT_RATE_TIGHT := 2.25
const DRIFT_GRIP := 0.55
const DRIFT_LEVEL_TIMES := [0.0, 0.8, 1.8]
const MINI_BOOST_TIME := [0.0, 0.55, 1.15]
const PURR_GAIN := [0.0, 0.3, 0.6]
const PURR_MAX := 3.0
const PURR_BOOST_TIME := 1.5
const BOOST_SPEED_BONUS := 0.32
const BOOST_ACCEL := 38.0
const PAD_BOOST_TIME := 1.0
const START_BOOST_TIME := 1.2
const RADIUS := 0.75
const GHOST_TIME := 1.8

## Kart statistics (multipliers around 1.0) set from KartCatalog.
var speed_mult := 1.0
var accel_mult := 1.0
var handling_mult := 1.0
var drift_mult := 1.0
var weight := 1.0

var racer_id := ""
var display_name := "Racer"
var is_player := false
var controller: Object = null
var track: Track = null
var loc := TrackLocation.new()
var control_enabled := false

# Inputs written by the controller each tick.
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var drift_held := false
var boost_pressed := false

# State.
var yaw := 0.0
var forward_speed := 0.0
var lateral_speed := 0.0
var drifting := false
var drift_dir := 0
var drift_charge := 0.0
var drift_level := 0
var boost_time := 0.0
var boost_kind: StringName = &""
var purr := 0.0
var airborne_time := 0.0
var ground_normal := Vector3.UP
var surface: StringName = &"road"
var hazard_cooldown := 0.0
var spin_time := 0.0
var ghost_time := 0.0
var wall_cooldown := 0.0
var stall_time := 0.0
var last_safe_s := 0.0
var last_safe_valid := false
var distance_driven := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _pad_lock := false
var _climb := 0.0

var model: KartModel


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.7
	floor_constant_speed = false
	floor_block_on_wall = true
	wall_min_slide_angle = deg_to_rad(10.0)
	safe_margin = 0.04
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	if get_node_or_null("Shape") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.55
		cap.height = 2.0
		cs.shape = cap
		cs.rotation.x = PI * 0.5
		cs.position.y = 0.55
		add_child(cs)
	yaw = rotation.y


func setup_stats(stats: Dictionary) -> void:
	speed_mult = float(stats.get("speed", 1.0))
	accel_mult = float(stats.get("accel", 1.0))
	handling_mult = float(stats.get("handling", 1.0))
	drift_mult = float(stats.get("drift", 1.0))
	weight = float(stats.get("weight", 1.0))


func top_speed() -> float:
	return BASE_TOP_SPEED * speed_mult


## Maximum yaw rate (rad/s) at a given speed. Shared with the AI planner.
static func turn_rate(speed: float, top: float, handling := 1.0) -> float:
	var v := absf(speed)
	var low := clampf(v / TURN_FULL_AT, 0.0, 1.0)
	var t := clampf((v - TURN_FULL_AT) / maxf(top - TURN_FULL_AT, 1.0), 0.0, 1.0)
	return lerpf(TURN_RATE_LOW, TURN_RATE_HIGH, t) * low * handling


func forward_dir() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func place(xf: Transform3D) -> void:
	global_position = xf.origin
	yaw = xf.basis.get_euler().y
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	forward_speed = 0.0
	lateral_speed = 0.0
	_cancel_drift(false)
	boost_time = 0.0
	airborne_time = 0.0
	spin_time = 0.0
	ground_normal = Vector3.UP
	if track:
		loc.main_index = -1
		track.locate(global_position, loc)
		last_safe_s = loc.s
		last_safe_valid = true
	if model:
		model.reset_pose()
	reset_physics_interpolation()


## Respawn on the track behind the last safe position. Used for falls, the
## recover button and AI that cannot get unstuck.
func recover() -> void:
	if track == null:
		return
	var s := (last_safe_s if last_safe_valid else loc.s) - 4.0
	var xf := track.respawn_transform(s, clampf(loc.lateral, -2.0, 2.0) if not loc.off_track else 0.0)
	var keep_purr := purr
	place(xf)
	purr = keep_purr
	ghost_time = GHOST_TIME
	collision_layer = 0
	collision_mask = 1
	recovered.emit()


func give_boost(seconds: float, kind: StringName) -> void:
	boost_time = maxf(boost_time, seconds)
	boost_kind = kind
	boost_started.emit(kind)


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation tick. Public so tests can drive karts deterministically.
func step(delta: float) -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	drift_held = false
	boost_pressed = false
	if controller and control_enabled:
		controller.drive(self, delta)
	if stall_time > 0.0:
		stall_time -= delta
		throttle = 0.0
	if track:
		track.locate(global_position, loc)
		surface = loc.surface
	var sp: Dictionary = Track.SURFACES.get(surface, Track.SURFACES[&"road"])
	var on_floor := is_on_floor()
	if on_floor:
		ground_normal = ground_normal.slerp(get_floor_normal(), 1.0 - exp(-14.0 * delta)).normalized()
	else:
		ground_normal = ground_normal.slerp(Vector3.UP, 1.0 - exp(-3.0 * delta)).normalized()
	var up := ground_normal if on_floor else Vector3.UP

	_timers(delta)
	_update_drift(on_floor, delta)
	if boost_pressed and purr >= 1.0 and on_floor and boost_time < 0.3:
		purr -= 1.0
		give_boost(PURR_BOOST_TIME, &"purr")
	if track and loc.on_pad and not _pad_lock:
		_pad_lock = true
		give_boost(PAD_BOOST_TIME, &"pad")
		forward_speed = maxf(forward_speed, top_speed() * 1.05)
	elif track and not loc.on_pad:
		_pad_lock = false

	# Steering rotates the heading.
	var top := top_speed() * float(sp["speed"])
	if boost_time > 0.0:
		top = top_speed() * (1.0 + BOOST_SPEED_BONUS) * maxf(float(sp["speed"]), 0.85)
	var rate := 0.0
	if drifting:
		var tight := clampf((steer * -drift_dir + 1.0) * 0.5, 0.0, 1.0)
		rate = drift_dir * lerpf(DRIFT_RATE_WIDE, DRIFT_RATE_TIGHT, tight) * lerpf(1.0, handling_mult, 0.5)
	else:
		rate = -steer * turn_rate(forward_speed, top_speed(), handling_mult) * signf(forward_speed if absf(forward_speed) > 0.1 else 1.0)
		if absf(forward_speed) < 0.3:
			rate = 0.0
	if not on_floor:
		rate *= AIR_TURN
	yaw = wrapf(yaw + rate * delta, -PI, PI)

	var fwd := forward_dir()
	var fwd_g := (fwd - up * fwd.dot(up)).normalized()
	var right_g := fwd_g.cross(up).normalized()
	var v_up := up * velocity.dot(up)
	var v_plane := velocity - v_up
	var f := v_plane.dot(fwd_g)
	var l := v_plane.dot(right_g)

	if on_floor:
		f = _longitudinal(f, top, float(sp["accel"]), delta)
		var grip := BASE_GRIP * float(sp["grip"]) * handling_mult
		if drifting:
			grip *= DRIFT_GRIP * lerpf(1.0, drift_mult, 0.6)
		l *= exp(-grip * delta)
		# Gentle stick to the surface; jumps come from ramps leaving upward.
		var vu := velocity.dot(up)
		v_up = up * minf(vu, 0.0) - up * 1.2
		velocity = fwd_g * f + right_g * l + v_up
		# Remember how fast we were climbing; Godot reports zero vertical
		# velocity while grounded, so launches off ramps are applied by hand.
		_climb = maxf(_climb * 0.8, fwd_g.y * f)
	else:
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		hv *= exp(-0.05 * delta)
		# Air steering slowly turns the momentum to line up the landing.
		var hspeed := hv.length()
		if hspeed > 0.5:
			var hdir := hv / hspeed
			hv = hdir.slerp(Vector3(fwd.x, 0, fwd.z), clampf(1.6 * delta, 0.0, 1.0)).normalized() * hspeed
		velocity = Vector3(hv.x, velocity.y - GRAVITY * delta, hv.z)
		f = hv.dot(fwd)
		l = hv.dot(fwd.cross(Vector3.UP))
		_fall_speed = minf(_fall_speed, velocity.y)

	var pre_velocity := velocity
	move_and_slide()
	_resolve_collisions(pre_velocity)
	_wall_assist(delta)
	rotation = Vector3(0.0, yaw, 0.0)

	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		if airborne_time > 0.18:
			landed.emit(-_fall_speed)
		airborne_time = 0.0
		_fall_speed = 0.0
	elif not now_floor:
		if _was_on_floor and _climb > 1.8:
			# Leaving a ramp or crest: launch with the climb rate plus a little
			# extra lift for arcade airtime.
			velocity.y = maxf(velocity.y, _climb * RAMP_KICK)
			jumped.emit()
		_climb = 0.0
		airborne_time += delta
	_was_on_floor = now_floor

	var hv2 := velocity - ground_normal * velocity.dot(ground_normal)
	forward_speed = hv2.dot(forward_dir())
	lateral_speed = hv2.dot(forward_dir().cross(Vector3.UP))
	distance_driven += absf(forward_speed) * delta

	if track:
		_check_hazards()
		if now_floor and not loc.off_track and not loc.in_gap and loc.surface != &"offroad" and loc.path == 0 and absf(loc.height) < 2.5:
			last_safe_s = loc.s
			last_safe_valid = true
	if model:
		model.animate(self, delta)


func _longitudinal(f: float, top: float, accel_k: float, delta: float) -> float:
	var accel := BASE_ACCEL * accel_mult * accel_k
	if boost_time > 0.0:
		if f < top:
			f = minf(f + BOOST_ACCEL * delta, top)
		else:
			f = move_toward(f, top, OVERSPEED_DECEL * delta)
	elif throttle > 0.01 and brake < 0.5:
		if f < 0.0:
			f += BRAKE_DECEL * throttle * delta
		elif f < top:
			var ratio := clampf(f / top, 0.0, 1.0)
			f += accel * throttle * (1.0 - ratio * ratio * 0.85) * delta
			f = minf(f, top)
		else:
			f = move_toward(f, top, OVERSPEED_DECEL * delta)
	elif brake > 0.01:
		if f > 0.5:
			f -= BRAKE_DECEL * brake * delta
		else:
			f = maxf(f - REVERSE_ACCEL * brake * delta, -REVERSE_MAX)
	else:
		f = move_toward(f, 0.0, COAST_DECEL * delta)
		if f > top:
			f = move_toward(f, top, OVERSPEED_DECEL * delta)
	if drifting:
		f -= 1.2 * delta
	return f


func _timers(delta: float) -> void:
	boost_time = maxf(boost_time - delta, 0.0)
	if boost_time <= 0.0:
		boost_kind = &""
	hazard_cooldown = maxf(hazard_cooldown - delta, 0.0)
	spin_time = maxf(spin_time - delta, 0.0)
	wall_cooldown = maxf(wall_cooldown - delta, 0.0)
	if ghost_time > 0.0:
		ghost_time -= delta
		if ghost_time <= 0.0:
			ghost_time = 0.0
			collision_layer = 2
			collision_mask = 1 | 2


func _update_drift(on_floor: bool, delta: float) -> void:
	if not drifting:
		if drift_held and absf(steer) > 0.3 and forward_speed > DRIFT_MIN_SPEED and on_floor and spin_time <= 0.0:
			drifting = true
			drift_dir = 1 if steer < 0.0 else -1
			drift_charge = 0.0
			drift_level = 0
			drift_started.emit(drift_dir)
		return
	if not drift_held:
		_cancel_drift(true)
		return
	if forward_speed < DRIFT_KEEP_SPEED or airborne_time > 0.7 or spin_time > 0.0:
		_cancel_drift(false)
		return
	if on_floor:
		var tight := clampf((steer * -drift_dir + 1.0) * 0.5, 0.0, 1.0)
		var gain := (0.65 + 0.7 * tight) * drift_mult
		if surface == &"offroad":
			gain *= 0.4
		drift_charge += gain * delta
		var lvl := 0
		for k in range(DRIFT_LEVEL_TIMES.size() - 1, 0, -1):
			if drift_charge >= DRIFT_LEVEL_TIMES[k]:
				lvl = k
				break
		if lvl != drift_level:
			drift_level = lvl
			drift_level_changed.emit(lvl)


func _cancel_drift(reward: bool) -> void:
	if not drifting:
		return
	var lvl := drift_level
	drifting = false
	drift_dir = 0
	drift_charge = 0.0
	drift_level = 0
	if reward and lvl > 0:
		give_boost(MINI_BOOST_TIME[lvl], &"drift%d" % lvl)
		purr = minf(purr + PURR_GAIN[lvl], PURR_MAX)
	drift_released.emit(lvl if reward else 0)


func _resolve_collisions(pre: Vector3) -> void:
	var worst := 0.0
	var worst_n := Vector3.ZERO
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if n.dot(Vector3.UP) > 0.65:
			continue
		var other := col.get_collider()
		if other is Kart:
			_bump_kart(other, n, pre)
			continue
		var hn := Vector3(n.x, 0.0, n.z).normalized()
		var impact := -Vector3(pre.x, 0.0, pre.z).dot(hn)
		if impact > worst:
			worst = impact
			worst_n = hn
	if worst <= 0.5:
		return
	# Lose speed in proportion to how square-on the hit was, push off the
	# wall, and ease the nose along it (rate-limited, so it never spins).
	var keep := clampf(1.0 - worst / 45.0, 0.55, 1.0)
	velocity.x *= keep
	velocity.z *= keep
	velocity += worst_n * minf(worst * 0.3, 5.0)
	if worst > 9.0:
		_cancel_drift(false)
	if wall_cooldown <= 0.0 and worst > 2.5:
		wall_cooldown = 0.25
		wall_hit.emit(worst)


## While scraping a wall nose-first, ease the heading along the wall so the
## kart never gets pinned (rate-limited: it reads as a scrape, not a spin).
func _wall_assist(delta: float) -> void:
	if not is_on_wall() or forward_speed < 1.0:
		return
	var wn := get_wall_normal()
	var hn := Vector3(wn.x, 0.0, wn.z)
	if hn.length_squared() < 0.01:
		return
	hn = hn.normalized()
	var fwd := forward_dir()
	var into := -fwd.dot(hn)
	if into < 0.03 or into > 0.9:
		return
	var tangent := (fwd + hn * into).normalized()
	var diff := wrapf(atan2(-tangent.x, -tangent.z) - yaw, -PI, PI)
	yaw += clampf(diff, -1.8 * delta, 1.8 * delta)


func _bump_kart(other: Kart, n: Vector3, pre: Vector3) -> void:
	var hn := Vector3(n.x, 0.0, n.z).normalized()
	var rel := (pre - other.velocity).dot(hn)
	if rel >= 0.0:
		return
	var m1 := weight
	var m2 := other.weight
	var j := -(1.0 + 0.35) * rel / (1.0 / m1 + 1.0 / m2)
	j = minf(j, 14.0)
	velocity += hn * (j / m1 + 1.2)
	other.velocity -= hn * (j / m2 + 1.2)
	if absf(rel) > 3.0:
		kart_bumped.emit(other, absf(rel))
		other.kart_bumped.emit(self, absf(rel))


func _check_hazards() -> void:
	if hazard_cooldown > 0.0 or ghost_time > 0.0:
		return
	var push := track.hazard_contact(global_position, RADIUS)
	if push == Vector3.ZERO:
		return
	hazard_cooldown = 1.2
	spin_time = 0.45
	_cancel_drift(false)
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	velocity.x *= 0.35
	velocity.z *= 0.35
	velocity += push * (4.0 + speed * 0.15) + Vector3.UP * 3.5
	hazard_hit.emit()
