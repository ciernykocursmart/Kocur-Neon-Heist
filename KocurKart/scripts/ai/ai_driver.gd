class_name AIDriver
extends RefCounted
## AI racer. Drives the same Kart physics as the player through the same
## controls (steer/throttle/brake/drift/boost): no teleporting, no hidden
## speed bonuses and no rubber-banding. Difficulty changes how close to the
## limit it corners, how cleanly it holds the line and how often it drifts,
## boosts and takes shortcuts. Personality adds small, readable tendencies.

const DIFFICULTY := {
	"easy": {"corner": 0.8, "top": 0.86, "noise": 1.6, "drift": 0.15, "boost": 0.35, "start": 0.15, "shortcut": 0.1, "lift": 0.06},
	"normal": {"corner": 0.92, "top": 0.95, "noise": 0.9, "drift": 0.55, "boost": 0.75, "start": 0.4, "shortcut": 0.4, "lift": 0.025},
	"hard": {"corner": 0.995, "top": 1.0, "noise": 0.35, "drift": 0.95, "boost": 1.0, "start": 0.8, "shortcut": 0.8, "lift": 0.006},
}

var difficulty := "normal"
var params: Dictionary
var personality: Dictionary = {}
var rng := RandomNumberGenerator.new()
var others: Array = []          ## other karts, for avoidance
var line_bias := 0.0            ## personal preferred lateral offset
var wants_start_boost := false

var _t := 0.0
var _stuck_time := 0.0
var _reverse_time := 0.0
var _reverse_count := 0
var _progress_s := 0.0
var _progress_timer := 0.0
var _lift_time := 0.0
var _shortcut := -1             ## shortcut index being taken this lap, -1 none
var _shortcut_decided_for := -1.0
var _drift_cooldown := 0.0
var _avoid := 0.0
var _phase := 0.0
var recover_requested := false


func _init(diff := "normal", pers: Dictionary = {}, seed_value := 1) -> void:
	difficulty = diff if DIFFICULTY.has(diff) else "normal"
	params = DIFFICULTY[difficulty]
	personality = pers
	rng.seed = seed_value
	_phase = rng.randf() * TAU
	line_bias = rng.randf_range(-0.6, 0.6)
	wants_start_boost = rng.randf() < float(params["start"]) * float(pers.get("consistency", 0.85)) / 0.85


func reset() -> void:
	_stuck_time = 0.0
	_reverse_time = 0.0
	_reverse_count = 0
	_progress_timer = 0.0
	_shortcut = -1
	_drift_cooldown = 0.0
	recover_requested = false


func drive(kart: Kart, delta: float) -> void:
	var track := kart.track
	if track == null:
		return
	_t += delta
	_drift_cooldown = maxf(_drift_cooldown - delta, 0.0)
	var main := track.main
	var line := track.racing_line
	var loc := kart.loc
	var mi := loc.main_index
	if mi < 0:
		return
	var speed := kart.forward_speed
	var pace := float(personality.get("pace", 1.0))

	# --- Recovery: reverse out of walls, ask for a respawn if hopeless. ---
	if _reverse_time > 0.0:
		_reverse_time -= delta
		kart.brake = 1.0
		kart.throttle = 0.0
		kart.steer = -_steer_to(kart, _target_point(kart, track, 8.0), 1.0)
		return
	if speed < 2.0 and kart.ghost_time <= 0.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.1:
		_stuck_time = 0.0
		_reverse_time = 0.9
		_reverse_count += 1
	_progress_timer += delta
	if track.s_delta(_progress_s, loc.s) > 12.0:
		_progress_s = loc.s
		_progress_timer = 0.0
		_reverse_count = 0
	if _progress_timer > 7.0 or _reverse_count >= 3:
		recover_requested = true
		_progress_timer = 0.0
		_reverse_count = 0
		_progress_s = loc.s

	# --- Shortcut decision, once per approach. ---
	_update_shortcut(kart, track)

	# --- Steering target. ---
	var look := 6.0 + absf(speed) * 0.42
	var target: Vector3
	var target_speed: float
	if _shortcut >= 0:
		var sc := track.shortcuts[_shortcut]
		var si := sc.nearest_index(kart.global_position, -1)
		var ahead := mini(si + int(look / TrackPath.SPACING), sc.size() - 1)
		target = sc.positions[ahead]
		var surf: Dictionary = Track.SURFACES.get(track.shortcut_surfaces[_shortcut], Track.SURFACES[&"road"])
		target_speed = kart.top_speed() * float(surf["speed"]) * 0.97
		var k := 0.0
		for j in range(si, mini(si + 12, sc.size())):
			k = maxf(k, absf(sc.curvature[j]))
		var v := target_speed
		while v > 8.0 and v * k > Kart.turn_rate(v, kart.top_speed()) * 0.85:
			v -= 0.5
		target_speed = v
		if si >= sc.size() - 3:
			_shortcut = -1
	else:
		var offset := _desired_offset(kart, track, mi, look)
		var ahead_i := main.wrap_index(mi + int(look / TrackPath.SPACING))
		target = main.positions[ahead_i] + main.rights[ahead_i] * offset
		# Planned speed a little ahead (the profile already includes braking).
		var brake_i := main.wrap_index(mi + 2 + int(absf(speed) * 0.12))
		target_speed = line.speed(brake_i)
		var corner_k := float(params["corner"]) * pace
		var top := kart.top_speed() * float(params["top"]) * pace
		target_speed = minf(target_speed * corner_k, top)
		if loc.surface == &"offroad":
			target_speed = minf(target_speed, kart.top_speed() * 0.6)
	var steer := _steer_to(kart, target, 2.4)

	# --- Throttle / brake. ---
	if _lift_time > 0.0:
		_lift_time -= delta
		target_speed *= 0.82
	elif rng.randf() < float(params["lift"]) * delta * (2.0 - float(personality.get("consistency", 0.85))):
		_lift_time = rng.randf_range(0.4, 0.9)
	if speed > target_speed + 0.8:
		kart.throttle = 0.0
		kart.brake = clampf((speed - target_speed) / 5.0, 0.15, 1.0)
	else:
		kart.throttle = 1.0 if speed < target_speed - 0.5 else 0.6
		kart.brake = 0.0

	# --- Drifting long, tight corners. ---
	steer = _drift_logic(kart, track, mi, steer, speed)
	kart.steer = clampf(steer, -1.0, 1.0)

	# --- Purr Boost on straights. ---
	kart.boost_pressed = false
	if kart.purr >= 1.0 and kart.boost_time <= 0.0 and speed > 12.0 and not kart.drifting:
		if _straight_ahead(track, mi, 70.0) and rng.randf() < float(params["boost"]) * 0.05:
			kart.boost_pressed = true


func _target_point(kart: Kart, track: Track, dist: float) -> Vector3:
	var main := track.main
	var i := main.wrap_index(kart.loc.main_index + int(dist / TrackPath.SPACING))
	return main.positions[i]


## Steering value (+ = right) that turns the kart towards `target`.
func _steer_to(kart: Kart, target: Vector3, gain: float) -> float:
	var to := target - kart.global_position
	var target_yaw := atan2(-to.x, -to.z)
	var err := wrapf(target_yaw - kart.yaw, -PI, PI)
	return clampf(-err * gain, -1.0, 1.0)


func _desired_offset(kart: Kart, track: Track, mi: int, look: float) -> float:
	var main := track.main
	var line := track.racing_line
	var ahead_i := main.wrap_index(mi + int(look / TrackPath.SPACING))
	var hw := main.widths[ahead_i] * 0.5
	var noise := float(params["noise"]) * (1.5 - float(personality.get("consistency", 0.85)))
	var offset := line.offset(ahead_i) + line_bias + sin(_t * 0.31 + _phase) * noise
	# Avoid karts close ahead: pick the side with more room.
	var my_s := kart.loc.s
	var want := 0.0
	for o in others:
		if o == kart or not is_instance_valid(o):
			continue
		var ok: Kart = o
		var ds := track.s_delta(my_s, ok.loc.s)
		if ds < 0.5 or ds > 11.0:
			continue
		var dl := ok.loc.lateral - kart.loc.lateral
		if absf(dl) > 2.6:
			continue
		var aggression := float(personality.get("aggression", 0.5))
		var room_left := ok.loc.lateral + hw
		var room_right := hw - ok.loc.lateral
		var side := -1.0 if room_left > room_right else 1.0
		want = ok.loc.lateral + side * (2.8 - aggression * 0.6)
	if want != 0.0:
		_avoid = lerpf(_avoid, want - offset, 0.15)
	else:
		_avoid = lerpf(_avoid, 0.0, 0.05)
	offset += _avoid
	# Steer clear of moving hazards we will reach soon.
	for h in track.hazards:
		var ds2 := track.s_delta(my_s, h.s)
		if ds2 < 0.0 or ds2 > 30.0:
			continue
		var eta := ds2 / maxf(kart.forward_speed, 5.0)
		var hl := _hazard_lateral(track, h, eta)
		if absf(hl - offset) < h.radius + 1.8:
			var left_room := hl - (-hw + 1.2)
			var right_room := (hw - 1.2) - hl
			offset = hl - (h.radius + 2.0) if left_room > right_room else hl + (h.radius + 2.0)
	return clampf(offset, -hw + 1.3, hw - 1.3)


func _hazard_lateral(track: Track, h: TrackHazard, eta: float) -> float:
	var t := track.race_time + eta
	if h.kind == "sweeper":
		return h.lateral + h.amplitude * sin(TAU * t / h.period + h.phase)
	return h.lateral


func _update_shortcut(kart: Kart, track: Track) -> void:
	if _shortcut >= 0 or track.shortcuts.is_empty():
		return
	for k in track.shortcuts.size():
		var sc := track.shortcuts[k]
		var ds := track.s_delta(kart.loc.s, sc.main_s_start)
		if ds > 10.0 and ds < 40.0:
			if absf(_shortcut_decided_for - sc.main_s_start) < 1.0 and ds > 0.0:
				return
			_shortcut_decided_for = sc.main_s_start
			var chance := float(params["shortcut"]) * float(personality.get("aggression", 0.5)) * 1.4
			if rng.randf() < chance and kart.forward_speed > 12.0:
				_shortcut = k
			return
		if ds < -20.0 or ds > 60.0:
			if absf(_shortcut_decided_for - sc.main_s_start) < 1.0:
				_shortcut_decided_for = -1.0


func _straight_ahead(track: Track, mi: int, dist: float) -> bool:
	var line := track.racing_line
	for k in int(dist / TrackPath.SPACING):
		if absf(line.curvature[track.main.wrap_index(mi + k)]) > 0.01:
			return false
	return true


## Starts, steers and releases drifts through long corners.
func _drift_logic(kart: Kart, track: Track, mi: int, steer: float, speed: float) -> float:
	var line := track.racing_line
	if kart.drifting:
		# Map the desired turn onto the drift's wide..tight range.
		var desired_rate := -steer * 1.6
		var dir := float(kart.drift_dir)
		var tight := clampf((desired_rate * dir - Kart.DRIFT_RATE_WIDE) / (Kart.DRIFT_RATE_TIGHT - Kart.DRIFT_RATE_WIDE), 0.0, 1.0)
		var turn_left := 0.0
		for k in 8:
			turn_left += line.curvature[track.main.wrap_index(mi + 2 + k)] * dir
		var corner_done := turn_left < 0.03
		var wrong_way := desired_rate * dir < 0.15
		kart.drift_held = not (corner_done or wrong_way and kart.drift_level >= 1)
		if not kart.drift_held:
			_drift_cooldown = 1.2
		return -dir * (tight * 2.0 - 1.0)
	if _drift_cooldown > 0.0 or _shortcut >= 0 or speed < Kart.DRIFT_MIN_SPEED + 3.0:
		return steer
	if kart.loc.surface == &"ice":
		return steer
	# Total heading change over the next ~45 m: drift if it is a real corner.
	var total := 0.0
	for k in 22:
		total += line.curvature[track.main.wrap_index(mi + 3 + k)] * TrackPath.SPACING
	var chance := float(params["drift"]) * float(personality.get("drift", 0.7))
	if absf(total) > 0.9 and absf(steer) > 0.35 and rng.randf() < chance * 0.25:
		kart.drift_held = true
		return signf(-total) * maxf(absf(steer), 0.5)
	return steer
